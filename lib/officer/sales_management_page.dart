import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/services/sync_service.dart';
import 'create_sale_page.dart';
import 'sales_report_page.dart';
import 'sale_details_page.dart';

class SalesManagementPage extends StatefulWidget {
  const SalesManagementPage({super.key});

  @override
  State<SalesManagementPage> createState() => _SalesManagementPageState();
}

class _SalesManagementPageState extends State<SalesManagementPage> {
  List<Map<String, dynamic>> _allSales = [];
  List<Map<String, dynamic>> _filteredSales = [];
  String _filterStatus = 'All';
  bool _isLoading = true;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadSales();
    _syncSales();
  }

  Future<void> _loadSales() async {
    final sales = await DatabaseService().getAllSales();
    if (mounted) {
      setState(() {
        _allSales = sales;
        _applyFilter();
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    setState(() {
      if (_filterStatus == 'All') {
        _filteredSales = List.from(_allSales);
      } else {
        final bool showLoans = _filterStatus == 'Loan';
        _filteredSales =
            _allSales.where((sale) {
              final isLoan = sale['is_loan'] == 1 || sale['is_loan'] == true;
              return isLoan == showLoans;
            }).toList();
      }
    });
  }

  Future<void> _syncSales() async {
    try {
      final token = await SyncService().getAuthToken();
      if (token != null) {
        final response = await ApiService().getSales(token);
        if (response['success'] == true && response['data'] != null) {
          final sales = response['data']['sales'] as List;
          await DatabaseService().saveSales(sales);
          _loadSales();
        }
      }
    } catch (e) {
      print('Sales sync failed: $e');
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Sales History',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SalesReportPage()),
                ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
            color: const Color(0xFF0A1B32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              _filterStatus = value;
              _applyFilter();
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'All',
                    child: Text(
                      'All Sales',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'Paid',
                    child: Text(
                      'Paid Only',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'Loan',
                    child: Text(
                      'Loans Only',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [Color(0xFF1E4976), Color(0xFF0A1B32), Color(0xFF020B18)],
          ),
        ),
        child: SafeArea(
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4BB4FF)),
                  )
                  : _filteredSales.isEmpty
                  ? Center(
                    child: Text(
                      'No sales found',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredSales.length,
                    itemBuilder: (context, index) {
                      final sale = _filteredSales[index];
                      final isSynced =
                          sale['sync_status'] == DatabaseService.statusSynced;
                      final date =
                          DateTime.tryParse(sale['created_at'] ?? '') ??
                          DateTime.now();
                      final formattedDate = DateFormat(
                        'dd MMM yyyy, HH:mm',
                      ).format(date);
                      final isLoan =
                          sale['is_loan'] == 1 || sale['is_loan'] == true;

                      return Card(
                        color: Colors.white.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: (isLoan
                                    ? Colors.orange
                                    : Colors.green)
                                .withOpacity(0.2),
                            child: Icon(
                              isLoan
                                  ? Icons.access_time_rounded
                                  : Icons.check_circle_outline_rounded,
                              color: isLoan ? Colors.orange : Colors.green,
                            ),
                          ),
                          title: Text(
                            'Sale #${sale['server_id'] ?? "LOC-${sale['local_id']}"}',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sale['is_loan'].toString()),

                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),

                              if (sale['customer_name'] != null)
                                Text(
                                  'To: ${sale['customer_name']}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              else if (sale['customer_id'] != null)
                                Text(
                                  'Customer ID: ${sale['customer_id']}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),

                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'TZS ${_currencyFormat.format(sale['total_amount'] ?? 0)}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (!isSynced)
                                const Icon(
                                  Icons.cloud_off,
                                  color: Colors.orange,
                                  size: 14,
                                ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => SaleDetailsPage(sale: sale),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateSalePage(onSaleCreated: _loadSales),
            ),
          );
          if (result == true) _loadSales();
        },
        backgroundColor: const Color(0xFF4BB4FF),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: Text(
          'New Sale',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
