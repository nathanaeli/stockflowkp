import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/l10n/app_localizations.dart';

class SaleLoansPage extends StatefulWidget {
  const SaleLoansPage({super.key});

  @override
  State<SaleLoansPage> createState() => _SaleLoansPageState();
}

class _SaleLoansPageState extends State<SaleLoansPage> {
  List<Map<String, dynamic>> _loanSales = [];
  List<Map<String, dynamic>> _filteredLoans = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, pending, paid, overdue
  int _selectedIndex = 1;
  bool _isRecordingPayment = false;

  @override
  void initState() {
    super.initState();
    _loadLoanSales();
  }

  Future<void> _loadLoanSales() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseService().database;
      final loans = await db.rawQuery('''
        SELECT 
          s.*,
          c.name as customer_name,
          c.phone as customer_phone,
          c.email as customer_email,
          (SELECT SUM(amount) FROM loan_payments WHERE sale_server_id = s.server_id) as history_payments,
          CASE 
            WHEN s.payment_status = 'paid' THEN 'Paid'
            WHEN s.due_date < datetime('now') AND (s.total_amount - COALESCE((SELECT SUM(amount) FROM loan_payments WHERE sale_server_id = s.server_id), s.total_payments, 0)) > 0 THEN 'Overdue'
            WHEN (s.total_amount - COALESCE((SELECT SUM(amount) FROM loan_payments WHERE sale_server_id = s.server_id), s.total_payments, 0)) > 0 THEN 'Pending'
            ELSE 'Completed'
          END as status_display
        FROM sales s
        LEFT JOIN customers c ON s.customer_id = c.server_id OR s.customer_id = c.local_id
        WHERE s.is_loan = 1
        ORDER BY s.created_at DESC
      ''');

      setState(() {
        _loanSales =
            loans.map((loan) {
              final Map<String, dynamic> mutableLoan =
                  Map<String, dynamic>.from(loan);
              // Use history_payments if available, otherwise fallback to total_payments
              final double paid =
                  (mutableLoan['history_payments'] as num?)?.toDouble() ??
                  (mutableLoan['total_payments'] as num?)?.toDouble() ??
                  0.0;
              final double total =
                  (mutableLoan['total_amount'] as num?)?.toDouble() ?? 0.0;
              mutableLoan['total_payments'] = paid;
              mutableLoan['remaining_balance'] =
                  (total - paid) > 0 ? (total - paid) : 0.0;
              return mutableLoan;
            }).toList();
        _filteredLoans = List.from(_loanSales);
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading loans: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_loanSales);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((loan) {
            final customerName = (loan['customer_name'] ?? '').toLowerCase();
            final invoiceNumber = (loan['invoice_number'] ?? '').toLowerCase();
            final query = _searchQuery.toLowerCase();
            return customerName.contains(query) ||
                invoiceNumber.contains(query);
          }).toList();
    }

    // Apply status filter
    if (_filterStatus != 'all') {
      filtered =
          filtered.where((loan) {
            final status = loan['status_display'] as String;
            return status.toLowerCase() == _filterStatus.toLowerCase();
          }).toList();
    }

    setState(() => _filteredLoans = filtered);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Icons.check_circle;
      case 'overdue':
        return Icons.warning;
      case 'pending':
        return Icons.schedule;
      default:
        return Icons.info;
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'TZS ',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  double _calculatePaymentPercentage(Map<String, dynamic> loan) {
    final total = (loan['total_amount'] as num?)?.toDouble() ?? 0.0;
    final paid = (loan['total_payments'] as num?)?.toDouble() ?? 0.0;
    
    if (total <= 0) return 0.0;
    return (paid / total) * 100;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _showLoanDetails(Map<String, dynamic> loan) async {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'TZS ',
      decimalDigits: 2,
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder:
                (context, scrollController) => Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1B32).withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            height: 4,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.all(20),
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          loan['status_display'] as String,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _getStatusIcon(
                                          loan['status_display'] as String,
                                        ),
                                        color: _getStatusColor(
                                          loan['status_display'] as String,
                                        ),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            loan['customer_name'] ??
                                                'Unknown Customer',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            loan['invoice_number'] ??
                                                'No Invoice',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          loan['status_display'] as String,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        loan['status_display'] as String,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: _getStatusColor(
                                            loan['status_display'] as String,
                                          ),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Financial Summary
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Total Amount',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            currencyFormat.format(
                                              loan['total_amount'] ?? 0.0,
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Paid Amount',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            currencyFormat.format(
                                              loan['total_payments'] ?? 0.0,
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.green,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(
                                        color: Colors.white24,
                                        height: 24,
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Remaining Balance',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            currencyFormat.format(
                                              loan['remaining_balance'] ?? 0.0,
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              color:
                                                  (loan['remaining_balance'] ??
                                                              0.0) >
                                                          0
                                                      ? Colors.orange
                                                      : Colors.green,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Details
                                _buildDetailRow(
                                  'Sale Date',
                                  _formatDate(loan['created_at']),
                                ),
                                _buildDetailRow(
                                  'Due Date',
                                  _formatDate(loan['due_date']),
                                ),
                                _buildDetailRow(
                                  'Customer Phone',
                                  loan['customer_phone'] ?? 'N/A',
                                ),
                                _buildDetailRow(
                                  'Customer Email',
                                  loan['customer_email'] ?? 'N/A',
                                ),
                                _buildDetailRow(
                                  'Payment Status',
                                  loan['payment_status'] ?? 'N/A',
                                ),
                                
                                // Loan History Button
                                const SizedBox(height: 16),
                                InkWell(
                                  onTap: () => _showLoanHistory(loan),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4BB4FF).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF4BB4FF).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.history_rounded,
                                          color: const Color(0xFF4BB4FF),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'View Payment History',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: const Color(0xFF4BB4FF),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: const Color(0xFF4BB4FF),
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                if (loan['discount_amount'] != null &&
                                    loan['discount_amount'] > 0) ...[
                                  const SizedBox(height: 16),
                                  _buildDetailRow(
                                    'Discount',
                                    currencyFormat.format(
                                      loan['discount_amount'],
                                    ),
                                  ),
                                ],

                                if (loan['discount_reason'] != null &&
                                    loan['discount_reason']
                                        .toString()
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  _buildDetailRow(
                                    'Discount Reason',
                                    loan['discount_reason'] as String,
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Action Buttons
                          if ((loan['remaining_balance'] ?? 0.0) > 0) ...[
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _recordPayment(loan);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF4BB4FF,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Record Payment',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLoanHistory(Map<String, dynamic> loan) async {
    final db = await DatabaseService().database;
    final loanServerId = loan['server_id'] as int?;
    
    if (loanServerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This loan has not been synced to the server yet.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      // Get payment history from local database
      final payments = await db.query(
        'loan_payments',
        where: 'sale_server_id = ?',
        whereArgs: [loanServerId],
        orderBy: 'payment_date DESC',
      );
      
      if (!mounted) return;
      
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A1B32).withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          color: const Color(0xFF4BB4FF),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Payment History',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4BB4FF).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${payments.length} payment${payments.length != 1 ? 's' : ''}',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF4BB4FF),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                loan['customer_name'] ?? 'Unknown Customer',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  // Summary Section
                  Container(
                    margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4BB4FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4BB4FF).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Paid',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(loan['total_payments'] ?? 0.0),
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.green,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Remaining',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(loan['remaining_balance'] ?? 0.0),
                                style: GoogleFonts.plusJakartaSans(
                                  color: (loan['remaining_balance'] ?? 0.0) > 0
                                      ? Colors.orange
                                      : Colors.green,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: payments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: Colors.white24,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No payment history found',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This loan has no recorded payments yet.',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            itemCount: payments.length,
                            itemBuilder: (context, index) {
                              final payment = payments[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatCurrency(payment['amount'] as double? ?? 0.0),
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.green,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4BB4FF).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _formatDate(payment['payment_date'] as String?),
                                            style: GoogleFonts.plusJakartaSans(
                                              color: const Color(0xFF4BB4FF),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (payment['notes'] != null &&
                                        (payment['notes'] as String).isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          payment['notes'] as String,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white70,
                                              fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 12,
                                          color: Colors.white38,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Recorded: ${_formatDateTime(payment['created_at'] as String?)}',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white38,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  
                  // Payment Summary Section
                  if (payments.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.analytics_rounded,
                                color: const Color(0xFF4BB4FF),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Payment Summary',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryItem(
                                  'Total Payments',
                                  '${payments.length}',
                                  Icons.payment_rounded,
                                  const Color(0xFF4BB4FF),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryItem(
                                  'Total Paid',
                                  _formatCurrency(loan['total_payments'] ?? 0.0),
                                  Icons.attach_money_rounded,
                                  Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _calculatePaymentPercentage(loan) >= 100
                                  ? Colors.green.withOpacity(0.1)
                                  : const Color(0xFF4BB4FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _calculatePaymentPercentage(loan) >= 100
                                    ? Colors.green.withOpacity(0.2)
                                    : const Color(0xFF4BB4FF).withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _calculatePaymentPercentage(loan) >= 100
                                      ? Icons.check_circle_rounded
                                      : Icons.trending_up_rounded,
                                  color: _calculatePaymentPercentage(loan) >= 100
                                      ? Colors.green
                                      : const Color(0xFF4BB4FF),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _calculatePaymentPercentage(loan) >= 100
                                        ? 'Loan Fully Paid'
                                        : 'Payment Progress: ${_calculatePaymentPercentage(loan).toStringAsFixed(1)}%',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: _calculatePaymentPercentage(loan) >= 100
                                          ? Colors.green
                                          : const Color(0xFF4BB4FF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryItem(
                                  'Average Payment',
                                  _formatCurrency(_calculateAveragePayment(payments)),
                                  Icons.trending_up_rounded,
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryItem(
                                  'Last Payment',
                                  payments.isNotEmpty
                                      ? _formatDate(payments.first['payment_date'] as String?)
                                      : 'N/A',
                                  Icons.access_time_rounded,
                                  Colors.purple,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading payment history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  double _calculateAveragePayment(List<Map<String, dynamic>> payments) {
    if (payments.isEmpty) return 0.0;
    
    double total = 0.0;
    for (var payment in payments) {
      total += (payment['amount'] as num?)?.toDouble() ?? 0.0;
    }
    
    return total / payments.length;
  }

  Future<void> _recordPayment(Map<String, dynamic> loan) async {
    // Check if widget is still mounted
    if (!mounted || _isRecordingPayment) return;

    setState(() => _isRecordingPayment = true);

    final amountController = TextEditingController();
    final noteController = TextEditingController();

    // Calculate percentages
    final totalAmount = (loan['total_amount'] as num?)?.toDouble() ?? 0.0;
    final remainingBalance = (loan['remaining_balance'] as num?)?.toDouble() ?? 0.0;

    // Quick payment percentages
    final quickPayments = [
      {'label': '25%', 'amount': (totalAmount * 0.25).round(), 'percentage': 0.25},
      {'label': '50%', 'amount': (totalAmount * 0.50).round(), 'percentage': 0.50},
      {'label': '75%', 'amount': (totalAmount * 0.75).round(), 'percentage': 0.75},
      {'label': '100%', 'amount': totalAmount.round(), 'percentage': 1.0},
    ];

    try {
      final result = await showDialog<Map<String, String>>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0A1B32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Record Payment',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Customer: ${loan['customer_name']}',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    // Quick Payment Buttons
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Payment',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: quickPayments.map((payment) {
                            final amount = payment['amount'] as int;
                            if (amount > remainingBalance) {
                              return const SizedBox.shrink();
                            }

                            return GestureDetector(
                              onTap: () {
                                if (dialogContext.mounted) {
                                  amountController.text = amount.toString();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4BB4FF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF4BB4FF).withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  '${payment['label']} (${_formatCurrency(amount.toDouble())})',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF4BB4FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Payment Amount',
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        prefixText: 'TZS ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: noteController,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Note (Optional)',
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final amountText = amountController.text.trim();
                  final noteText = noteController.text.trim();

                  final amount = double.tryParse(amountText);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid amount'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (amount > remainingBalance) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Amount cannot exceed remaining balance'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop({
                      'amount': amount.toString(),
                      'note': noteText,
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4BB4FF),
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Record Payment',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          );
        },
      );

      // If user cancelled or returned null, exit early
      if (result == null || !mounted) {
        amountController.dispose();
        noteController.dispose();
        setState(() => _isRecordingPayment = false);
        return;
      }

      final amountText = result['amount']!;
      final noteText = result['note']!;
      final amount = double.parse(amountText);

      // Check if widget is still mounted before showing loading
      if (!mounted) {
        amountController.dispose();
        noteController.dispose();
        setState(() => _isRecordingPayment = false);
        return;
      }

      // Show loading indicator
      BuildContext? loadingContext;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          loadingContext = context;
          return Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1B32),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF4BB4FF)),
                  const SizedBox(height: 16),
                  Text(
                    'Recording payment...',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      try {
        // 1. Get User Token
        final userData = await DatabaseService().getUserData();
        final token = userData?['data']?['token'];

        if (token == null) throw Exception('User not authenticated');
        if (loan['server_id'] == null) {
          throw Exception('This sale has not been synced to the server yet.');
        }

        // 2. Make API Call
        final response = await http.post(
          Uri.parse('${ApiService.baseUrl}/api/recordpaymentforsales'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'sale_id': loan['server_id'],
            'amount': amount,
            'payment_date': DateTime.now().toIso8601String().split('T')[0],
            'notes': noteText,
          }),
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          final responseData = jsonDecode(response.body);

          // 3. Update Local Database
          final db = await DatabaseService().database;

          // Insert into loan_payments table with proper null handling
          if (responseData['loanPayment'] != null) {
            final loanPayment = responseData['loanPayment'] as Map<String, dynamic>;

            // Prepare the record with proper null handling
            final paymentRecord = <String, dynamic>{
              'server_id': loanPayment['id'] as int?,
              'sale_server_id': loan['server_id'] as int?,
              'amount': amount,
              'payment_date': loanPayment['payment_date'] as String? ??
                  DateTime.now().toIso8601String().split('T')[0],
              'notes': noteText.isNotEmpty ? noteText : null,
              'user_id': loanPayment['user_id'] as int?,
              'created_at': loanPayment['created_at'] as String? ??
                  DateTime.now().toIso8601String(),
              'updated_at': loanPayment['updated_at'] as String? ??
                  DateTime.now().toIso8601String(),
              'sync_status': 1, // Synced
            };

            // Remove null values to prevent sqflite errors
            paymentRecord.removeWhere((key, value) => value == null);

            await db.insert('loan_payments', paymentRecord);
          }

          final currentPaid = (loan['total_payments'] as num? ?? 0.0).toDouble() + amount;
          final currentTotal = (loan['total_amount'] as num? ?? 0.0).toDouble();
          double remaining = currentTotal - currentPaid;
          if (remaining < 0) remaining = 0;

          final newStatus = remaining <= 0 ? 'paid' : 'pending';

          await db.update(
            'sales',
            {
              'total_payments': currentPaid,
              'remaining_balance': remaining,
              'payment_status': newStatus,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'local_id = ?',
            whereArgs: [loan['local_id']],
          );

          // Close loading dialog
          if (mounted && loadingContext != null && Navigator.of(loadingContext!).canPop()) {
            Navigator.of(loadingContext!).pop();
          }

          // Show success message and refresh
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment recorded successfully'),
                backgroundColor: Colors.green,
              ),
            );
            await _loadLoanSales(); // Refresh list
          }
        } else {
          throw Exception('Failed to record payment: ${response.body}');
        }
      } catch (e) {
        // Close loading dialog
        if (mounted && loadingContext != null && Navigator.of(loadingContext!).canPop()) {
          Navigator.of(loadingContext!).pop();
        }

        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Handle any unexpected errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Always dispose controllers and reset state
      amountController.dispose();
      noteController.dispose();
      setState(() => _isRecordingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Sale Loans',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            tooltip: 'New Loan',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'To create a new loan, please use "New Sale" on the dashboard.',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadLoanSales,
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [
                  Color(0xFF1E4976),
                  Color(0xFF0A1B32),
                  Color(0xFF020B18),
                ],
              ),
            ),
          ),
          SafeArea(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4BB4FF),
                      ),
                    )
                    : Column(
                      children: [
                        // Search and Filter Bar
                        Container(
                          margin: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Search Bar
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF132338),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: TextField(
                                  onChanged: (value) {
                                    _searchQuery = value;
                                    _applyFilters();
                                  },
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search by customer or invoice...',
                                    hintStyle: GoogleFonts.plusJakartaSans(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: Colors.white54,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Loan List
                        Expanded(
                          child:
                              _filteredLoans.isEmpty
                                  ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.monetization_on_outlined,
                                          size: 64,
                                          color: Colors.white24,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchQuery.isNotEmpty ||
                                                  _filterStatus != 'all'
                                              ? 'No loans match your filters'
                                              : 'No loan sales found',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white54,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      16,
                                      16,
                                      120,
                                    ),
                                    itemCount: _filteredLoans.length,
                                    itemBuilder: (context, index) {
                                      final loan = _filteredLoans[index];
                                      return _buildLoanCard(loan);
                                    },
                                  ),
                        ),
                      ],
                    ),
          ),
          _buildFloatingBottomNav(),
        ],
      ),
    );
  }

  Widget _buildFloatingBottomNav() {
    return Positioned(
      bottom: 35,
      left: 24,
      right: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 75,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(
                  Icons.dashboard_rounded,
                  'Dashboard',
                  0,
                  onTap: () => Navigator.of(context).pop(),
                ),
                _navItem(Icons.account_balance_wallet_rounded, 'Loans', 1),
                _navItem(Icons.settings_rounded, 'Settings', 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    int index, {
    VoidCallback? onTap,
  }) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap();
        } else {
          setState(() => _selectedIndex = index);
        }
      },
      behavior: HitTestBehavior.translucent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF4BB4FF).withOpacity(0.2)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF4BB4FF) : Colors.white54,
              size: 15,
            ),
            if (isSelected) const SizedBox(width: 8),
            if (isSelected)
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF4BB4FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: color ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildLoanCard(Map<String, dynamic> loan) {
    final statusColor = _getStatusColor(loan['status_display'] as String);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF132338),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showLoanDetails(loan),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
              padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loan['customer_name'] ?? 'Unknown Customer',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            loan['invoice_number'] ?? 'No Invoice',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.2)),
                      ),
                      child: Text(
                        loan['status_display'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Payment Progress Bar
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Payment Progress',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${_calculatePaymentPercentage(loan).toStringAsFixed(1)}%',
                            style: GoogleFonts.plusJakartaSans(
                              color: _calculatePaymentPercentage(loan) >= 100 
                                  ? Colors.green 
                                  : const Color(0xFF4BB4FF),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: _calculatePaymentPercentage(loan) / 100,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _calculatePaymentPercentage(loan) >= 100 
                                  ? Colors.green 
                                  : const Color(0xFF4BB4FF),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildMiniInfo(
                          'Total',
                          _formatCurrency(loan['total_amount'] ?? 0.0),
                        ),
                      ),
                      Expanded(
                        child: _buildMiniInfo(
                          'Paid',
                          _formatCurrency(loan['total_payments'] ?? 0.0),
                          color: Colors.greenAccent,
                        ),
                      ),
                      Expanded(
                        child: _buildMiniInfo(
                          'Balance',
                          _formatCurrency(loan['remaining_balance'] ?? 0.0),
                          color: Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Due: ${_formatDate(loan['due_date'])}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                    if ((loan['remaining_balance'] ?? 0.0) > 0)
                      InkWell(
                        onTap: () => _recordPayment(loan),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4BB4FF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF4BB4FF).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            'Record Payment',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF4BB4FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: Colors.white38,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
