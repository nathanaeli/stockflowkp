import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/database_service.dart';

class InventoryAnalysisPage extends StatefulWidget {
  const InventoryAnalysisPage({super.key});

  @override
  State<InventoryAnalysisPage> createState() => _InventoryAnalysisPageState();
}

class _InventoryAnalysisPageState extends State<InventoryAnalysisPage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService();

  bool _isLoading = true;
  String? _error;
  String? _token;

  // Filters
  int? _selectedDukaId;
  List<dynamic> _dukas = [];

  // Data
  Map<String, dynamic>? _reportData;

  // Animation
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
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

        // Fetch Initial Report
        await _fetchReport();
      } else {
        if (mounted) {
          setState(() {
            _error = "User session not found.";
            _isLoading = false;
          });
        }
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
    if (mounted) setState(() => _isLoading = true);

    try {
      final response = await _apiService.getInventoryAndLoanAnalysis(
        _token!,
        dukaId: _selectedDukaId,
      );

      if (response['success'] == true) {
        if (mounted) {
          setState(() {
            _reportData = response;
            _isLoading = false;
          });
          _animationController.forward(from: 0.0);
        }
      } else {
        if (mounted) {
          setState(() {
            _error = "Failed to fetch report";
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

  String _formatCurrency(dynamic amount) {
    return NumberFormat.currency(
      symbol: 'Tsh ',
      decimalDigits: 0,
    ).format(double.tryParse("$amount") ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    // Responsive Layout Builder
    return LayoutBuilder(
      builder: (context, constraints) {
        // Simple breakpoint logic
        final isMobile = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1000;

        if (_isLoading && _reportData == null) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4BB4FF)),
          );
        }

        if (_error != null && _reportData == null) {
          return _buildErrorState();
        }

        final summary = _reportData!['summary'];
        final stockFlow = summary['stock_flow'];
        final loanAging = summary['loan_aging'];
        final dukaBreakdown = _reportData!['duka_breakdown'] as List;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: RefreshIndicator(
            onRefresh: _fetchReport,
            color: const Color(0xFF4BB4FF),
            backgroundColor: const Color(0xFF0A1B32),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header & Filter
                  _buildHeaderAndFilter(isMobile),
                  const SizedBox(height: 24),

                  // Stock Flow Section
                  _buildSectionTitle("Stock Movement & Trends"),
                  const SizedBox(height: 12),
                  _buildStockFlowGrid(stockFlow, isMobile, isTablet),
                  const SizedBox(height: 32),

                  // Loan Aging Section
                  _buildSectionTitle("Loan Aging Analysis"),
                  const SizedBox(height: 12),
                  _buildLoanAgingCard(loanAging),
                  const SizedBox(height: 32),

                  // Duka Breakdown Section
                  _buildSectionTitle("Shop Performance"),
                  const SizedBox(height: 12),
                  if (dukaBreakdown.isEmpty)
                    _buildEmptyState("No shop data available")
                  else
                    ...dukaBreakdown.asMap().entries.map((entry) {
                      final index = entry.key;
                      final duka = entry.value;
                      return _buildAnimatedDukaCard(duka, index);
                    }),

                  const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadInitialData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4BB4FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white60,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildHeaderAndFilter(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Analysis Report",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: isMobile ? 24 : 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Track inventory health and debts",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (!isMobile) SizedBox(width: 200, child: _buildFilterDropdown()),
          ],
        ),
        if (isMobile) ...[const SizedBox(height: 16), _buildFilterDropdown()],
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedDukaId,
          isExpanded: true,
          hint: Text(
            "All Shops",
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          dropdownColor: const Color(0xFF1E1E2E), // Dark dropdown bg
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF4BB4FF),
          ),
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
          items: [
            DropdownMenuItem<int>(
              value: null,
              child: Text(
                "All Shops",
                style: GoogleFonts.plusJakartaSans(color: Colors.white70),
              ),
            ),
            ..._dukas.map(
              (duka) => DropdownMenuItem<int>(
                value: duka['id'],
                child: Text(
                  duka['name'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildStockFlowGrid(
    Map<String, dynamic> stockFlow,
    bool isMobile,
    bool isTablet,
  ) {
    // Calculate sell-through rate for "smart" insight
    double received =
        double.tryParse("${stockFlow['total_items_received']}") ?? 0;
    double sold = double.tryParse("${stockFlow['total_items_sold']}") ?? 0;
    double sellThrough = received > 0 ? (sold / received) * 100 : 0;

    // Grid layout
    int crossAxisCount = isMobile ? 2 : (isTablet ? 3 : 4);
    double childAspectRatio = isMobile ? 1.0 : 1.3;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: childAspectRatio,
      children: [
        _buildStatCard(
          "Items Received",
          "${stockFlow['total_items_received']}",
          Icons.input_rounded,
          const Color(0xFF10B981), // Green
          delay: 0,
        ),
        _buildStatCard(
          "Items Sold",
          "${stockFlow['total_items_sold']}",
          Icons.shopping_cart_checkout_rounded,
          const Color(0xFF3B82F6), // Blue
          delay: 1,
        ),
        _buildTurnoverCard(stockFlow, delay: 2),
        // Smart Insight Card
        _buildSmartInsightCard(sellThrough, delay: 3),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    int delay = 0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (delay * 100)),
      curve: Curves.easeOutBack,
      builder: (context, val, child) {
        return Transform.scale(
          scale: val,
          child: Opacity(
            opacity: val.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTurnoverCard(Map<String, dynamic> stockFlow, {int delay = 0}) {
    double ratio =
        double.tryParse("${stockFlow['inventory_turnover_ratio']}") ?? 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (delay * 100)),
      curve: Curves.easeOutBack,
      builder: (context, val, child) {
        return Transform.scale(
          scale: val,
          child: Opacity(
            opacity: val.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withOpacity(0.15),
                    const Color(0xFF8B5CF6).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sync_rounded,
                          color: Color(0xFF8B5CF6),
                          size: 20,
                        ),
                      ),
                      Text(
                        "${ratio.toStringAsFixed(1)}x",
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8B5CF6),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Turnover Ratio",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (ratio / 5.0).clamp(
                          0.0,
                          1.0,
                        ), // Cap visual at 5x
                        backgroundColor: const Color(
                          0xFF8B5CF6,
                        ).withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF8B5CF6),
                        ),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmartInsightCard(double sellThrough, {int delay = 0}) {
    // Smart logic for color/text
    Color color;
    IconData icon;
    String label;
    if (sellThrough >= 50) {
      color = const Color(0xFF10B981); // Good
      icon = Icons.trending_up;
      label = "High Demand";
    } else if (sellThrough >= 20) {
      color = const Color(0xFFF59E0B); // Okay
      icon = Icons.trending_flat;
      label = "Moderate";
    } else {
      color = const Color(0xFFEF4444); // Bad
      icon = Icons.trending_down;
      label = "Slow Moving";
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (delay * 100)),
      curve: Curves.easeOutBack,
      builder: (context, val, child) {
        return Transform.scale(
          scale: val,
          child: Opacity(
            opacity: val.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      Text(
                        "${sellThrough.toStringAsFixed(0)}%",
                        style: GoogleFonts.plusJakartaSans(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Sell-Through",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.plusJakartaSans(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoanAgingCard(Map<String, dynamic> loanAging) {
    final groups = loanAging['aging_groups'] as Map<String, dynamic>;
    final total = double.parse("${loanAging['total_receivables']}");

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutExpo,
      builder: (context, val, child) {
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - val)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E1E2E),
                    const Color(0xFF1E1E2E).withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Total Receivables",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatCurrency(total),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.pie_chart_outline_rounded,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Aging Rows with custom improvement
                  _buildAgingRow(
                    "Current (Not Due)",
                    groups['current'],
                    const Color(0xFF10B981),
                    total,
                  ),
                  _buildAgingRow(
                    "1-30 Days Overdue",
                    groups['1_30_days'],
                    const Color(0xFFFACC15), // Yellow
                    total,
                  ),
                  _buildAgingRow(
                    "31-60 Days Overdue",
                    groups['31_60_days'],
                    const Color(0xFFFB923C), // Orange
                    total,
                  ),
                  _buildAgingRow(
                    "61-90 Days Overdue",
                    groups['61_90_days'],
                    const Color(0xFFFF5722), // Deep Orange
                    total,
                  ),
                  _buildAgingRow(
                    "90+ Days Overdue",
                    groups['over_90_days'],
                    const Color(0xFFEF4444), // Red
                    total,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAgingRow(
    String label,
    dynamic amount,
    Color color,
    double total,
  ) {
    final val = double.parse("$amount");
    if (val <= 0 && total > 0)
      return const SizedBox.shrink(); // Hide empty rows

    // Calculate percentage
    double percentage = total > 0 ? (val / total) : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatCurrency(val),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDukaCard(Map<String, dynamic> duka, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeOut,
      builder: (context, val, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - val)),
          child: Opacity(opacity: val, child: _buildDukaPerformanceCard(duka)),
        );
      },
    );
  }

  Widget _buildDukaPerformanceCard(Map<String, dynamic> duka) {
    final revenue = double.parse("${duka['total_revenue'] ?? 0}");
    final debt = double.parse("${duka['total_debt'] ?? 0}");

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4BB4FF).withOpacity(0.2),
                  const Color(0xFF4BB4FF).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Color(0xFF4BB4FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  duka['duka_name'] ?? 'Unknown Shop',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildCompactStat("Rev", revenue, Colors.greenAccent),
                    const SizedBox(width: 12),
                    _buildCompactStat("Debt", debt, Colors.redAccent),
                  ],
                ),
              ],
            ),
          ),
          // Arrow icon for interactability suggestion
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withOpacity(0.3),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: GoogleFonts.plusJakartaSans(
              color: color.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            _formatCurrency(
              amount,
            ).replaceAll('Tsh ', ''), // Compact formatting
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 48,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
