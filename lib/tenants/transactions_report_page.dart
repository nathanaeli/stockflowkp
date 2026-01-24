import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/database_service.dart';

class TransactionsReportPage extends StatefulWidget {
  const TransactionsReportPage({super.key});

  @override
  State<TransactionsReportPage> createState() => _TransactionsReportPageState();
}

class _TransactionsReportPageState extends State<TransactionsReportPage> {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService();

  bool _isLoading = true;
  String? _error;
  String? _token;

  // Filters
  int? _selectedDukaId;
  DateTimeRange? _dateRange;
  List<dynamic> _dukas = [];

  // Data
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final userData = await _dbService.getUserData();
      if (userData != null && userData['data'] != null) {
        _token = userData['data']['token'];

        // Fetch Dukas for filter
        final dukasResponse = await _apiService.getTenantDukas(_token!);
        if (dukasResponse['success'] == true) {
          _dukas = dukasResponse['data'] ?? [];
        }

        // Fetch Initial Report (Current Month)
        await _fetchReport();
      } else {
        setState(() {
          _error = "User session not found.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load data: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchReport() async {
    if (_token == null) return;
    setState(() => _isLoading = true);

    try {
      final response = await _apiService.getTransactionReport(
        _token!,
        dukaId: _selectedDukaId,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
      );

      if (response['success'] == true) {
        if (mounted) {
          setState(() {
            _reportData = response;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = response['message'] ?? "Failed to fetch report";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Connection error: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          _dateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4BB4FF),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E2E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0A1B32),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
      _fetchReport();
    }
  }

  String _formatCurrency(dynamic amount) {
    return NumberFormat.currency(
      symbol: 'Tsh ',
      decimalDigits: 0,
    ).format(amount ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _reportData == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4BB4FF)),
      );
    }

    if (_error != null && _reportData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.orangeAccent,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4BB4FF).withOpacity(0.2),
                foregroundColor: const Color(0xFF4BB4FF),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final summary = _reportData!['summary'];
    final transactions = _reportData!['transactions']['data'] as List;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _fetchReport,
        color: const Color(0xFF4BB4FF),
        backgroundColor: const Color(0xFF0A1B32),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filters Section
              _buildFilters(),
              const SizedBox(height: 16),

              // Summary Cards
              _buildSummaryGrid(summary),
              const SizedBox(height: 20),

              // Breakdown Charts
              _buildCategoryBreakdown(),
              const SizedBox(height: 20),

              // Transactions List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Transactions",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${transactions.length} items',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Transactions List
              if (transactions.isEmpty)
                _buildEmptyState()
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  itemBuilder:
                      (context, index) =>
                          _buildTransactionCard(transactions[index]),
                ),

              const SizedBox(height: 80), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: Colors.white.withOpacity(0.2),
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "No transactions found",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                color: Color(0xFF4BB4FF),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                "Filter Report",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Duka Filter
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedDukaId,
                      isExpanded: true,
                      hint: Text(
                        "All Shops",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      dropdownColor: const Color(0xFF2A2A35),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white54,
                        size: 18,
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      items: [
                        DropdownMenuItem<int>(
                          value: null,
                          child: Text(
                            "All Shops",
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        ..._dukas.map(
                          (duka) => DropdownMenuItem<int>(
                            value: duka['id'],
                            child: Text(
                              duka['name'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedDukaId = val);
                        _fetchReport();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Date Range Filter
              Expanded(
                child: GestureDetector(
                  onTap: _selectDateRange,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            _dateRange == null
                                ? "This Month"
                                : "${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.white54,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(Map<String, dynamic> summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Adjust column count based on width, though grid usually fine with 2
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: (width / 2) / 75, // Responsive aspect ratio
          children: [
            _buildStatCard(
              "Total Income",
              _formatCurrency(summary['total_income']),
              Icons.trending_up,
              const Color(0xFF10B981), // Emerald Green
            ),
            _buildStatCard(
              "Total Expenses",
              _formatCurrency(summary['total_expense']),
              Icons.trending_down,
              const Color(0xFFEF4444), // Rose Red
            ),
            _buildStatCard(
              "Net Cash Flow",
              _formatCurrency(summary['net_cash_flow']),
              Icons.account_balance_wallet_outlined,
              summary['net_cash_flow'] >= 0
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFF59E0B),
            ),
            _buildStatCard(
              "Transactions",
              "${summary['transaction_count']}",
              Icons.receipt_long_outlined,
              const Color(0xFF8B5CF6), // Purple
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final breakdown = _reportData!['breakdown'];
    final incomeCats = (breakdown['income_by_category'] as List);
    final expenseCats = (breakdown['expense_by_category'] as List);

    if (incomeCats.isEmpty && expenseCats.isEmpty)
      return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (expenseCats.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.pie_chart_outline, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  "Expense Breakdown",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...expenseCats.map(
              (cat) => _buildCategoryBar(cat, const Color(0xFFEF4444)),
            ),
            if (incomeCats.isNotEmpty) const SizedBox(height: 20),
          ],
          if (incomeCats.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.pie_chart_outline, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  "Income Breakdown",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...incomeCats.map(
              (cat) => _buildCategoryBar(cat, const Color(0xFF10B981)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryBar(Map<String, dynamic> category, Color color) {
    // This is a simple visual representation
    // Assuming backend returns 'total' as number
    final total = double.parse(category['total'].toString());

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category['category'] ?? 'Other',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              Text(
                _formatCurrency(total),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor:
                  1.0, // In a real app, calculate relative percentage against total
              child: Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final isIncome = tx['type'] == 'income';
    final amount = double.parse(tx['amount'].toString());
    final date = DateTime.parse(tx['transaction_date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isIncome
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444))
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color:
                  isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx['description'] ?? tx['category'] ?? 'Transaction',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 10,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tx['duka']?['name'] ?? 'Unknown Shop',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 10,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d').format(date),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            "${isIncome ? '+' : '-'}${_formatCurrency(amount)}",
            style: GoogleFonts.plusJakartaSans(
              color: isIncome ? const Color(0xFF10B981) : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
