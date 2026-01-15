import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/shared_preferences_service.dart';

class DukaAnalysisPage extends StatefulWidget {
  final int dukaId;

  const DukaAnalysisPage({Key? key, required this.dukaId}) : super(key: key);

  @override
  State<DukaAnalysisPage> createState() => _DukaAnalysisPageState();
}

class _DukaAnalysisPageState extends State<DukaAnalysisPage> with TickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _analyticsData;
  String? _error;
  late SharedPreferencesService _prefsService;
  late NumberFormat _currencyFormat;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _initializeServices();
    _fetchAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    _prefsService = await SharedPreferencesService.getInstance();
    _setupCurrencyFormatter();
  }

  void _setupCurrencyFormatter() {
    final currency = _prefsService.getCurrency();
    String locale = 'en_US';
    if (currency == 'KES') {
      locale = 'en_KE';
    } else if (currency == 'USD') {
      locale = 'en_US';
    } else if (currency == 'EUR') {
      locale = 'de_DE';
    } else if (currency == 'GBP') {
      locale = 'en_GB';
    }
    
    _currencyFormat = NumberFormat('#,##0.00', locale);
  }

  Future<void> _fetchAnalyticsData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final dbService = DatabaseService();
      final userData = await dbService.getUserData();
      if (userData == null) {
        throw Exception('User data not found');
      }

      final token = userData['data']['token'];
      if (token == null) {
        throw Exception('Token not found');
      }

      final apiService = ApiService();
      final response = await apiService.getDukaOverview(
        token, 
        widget.dukaId,
        startDate: _formatDateForAPI(_startDate),
        endDate: _formatDateForAPI(_endDate)
      );

      if (!mounted) return;
      if (response['success'] == true) {
        setState(() {
          _analyticsData = response['data'];
          _isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch analytics data');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDateForAPI(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  double getResponsiveFontSize(double base, {double mobileFactor = 0.8, double tabletFactor = 0.9}) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth < 1200;

    if (isMobile) return base * mobileFactor;
    if (isTablet) return base * tabletFactor;
    return base;
  }

  EdgeInsets getResponsivePadding(double base) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth < 1200;

    final factor = isMobile ? 0.6 : isTablet ? 0.8 : 1.0;
    return EdgeInsets.all(base * factor);
  }

  bool get isMobile {
    final size = MediaQuery.of(context).size;
    return size.width < 600;
  }

  bool get isTablet {
    final size = MediaQuery.of(context).size;
    return size.width < 1200 && size.width >= 600;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        title: Text(
          'Advanced Analytics',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: getResponsiveFontSize(18),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.date_range_rounded, color: Colors.white, size: 20),
                    onPressed: _showDateRangePicker,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                    onPressed: _fetchAnalyticsData,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: const Color(0xFF0A1B32).withOpacity(0.5),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFF4BB4FF),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded), text: 'Overview'),
            Tab(icon: Icon(Icons.trending_up_rounded), text: 'Growth'),
            Tab(icon: Icon(Icons.inventory_2_rounded), text: 'Products'),
            Tab(icon: Icon(Icons.people_rounded), text: 'Customers'),
            Tab(icon: Icon(Icons.account_balance_rounded), text: 'Loans'),
            Tab(icon: Icon(Icons.analytics_rounded), text: 'Trends'),
          ],
        ),
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
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF4BB4FF)),
                      SizedBox(height: 16),
                      Text('Loading Analytics...', style: TextStyle(color: Colors.white70, fontSize: getResponsiveFontSize(14))),
                    ],
                  ),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent.withOpacity(0.8)),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text('Error: $_error',
                              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: getResponsiveFontSize(14)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _fetchAnalyticsData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4BB4FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildGrowthTab(),
                        _buildProductsTab(),
                        _buildCustomersTab(),
                        _buildLoansTab(),
                        _buildTrendsTab(),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _fetchAnalyticsData,
      child: ListView(
        padding: getResponsivePadding(16),
        children: [
          _buildHeroSection(),
          SizedBox(height: isMobile ? 12 : 16),
        
          SizedBox(height: isMobile ? 12 : 16),
          _buildQuickStatsGrid(),
          SizedBox(height: isMobile ? 12 : 16),
          _buildKeyInsights(),
        ],
      ),
    );
  }

  Widget _buildGrowthTab() {
    return ListView(
      padding: getResponsivePadding(16),
      children: [
      
        SizedBox(height: isMobile ? 12 : 16),
        _buildGrowthScoreCard(),
        SizedBox(height: isMobile ? 12 : 16),
        _buildGrowthTrends(),
      ],
    );
  }

  Widget _buildProductsTab() {
    return ListView(
      padding: getResponsivePadding(16),
      children: [
        _buildProductAnalytics(),
        SizedBox(height: isMobile ? 12 : 16),
        _buildInventoryValueAnalysis(),
        SizedBox(height: isMobile ? 12 : 16),
        _buildTopSellingProducts(),
        SizedBox(height: isMobile ? 12 : 16),
        _buildStockHealth(),
      ],
    );
  }

  Widget _buildCustomersTab() {
    return ListView(
      padding: getResponsivePadding(16),
      children: [
        _buildCustomerAnalytics(),
        SizedBox(height: isMobile ? 12 : 16),
        _buildCustomerRetention(),
        SizedBox(height: isMobile ? 12 : 16),
        _buildCustomerAcquisition(),
      ],
    );
  }

  Widget _buildLoansTab() {
    return ListView(
      padding: getResponsivePadding(16),
      children: [
        _buildLoanAnalytics(),
        SizedBox(height: isMobile ? 12 : 16),
        _buildLoanCollection(),
        SizedBox(height: isMobile ? 12 : 16),
        _buildOutstandingLoans(),
      ],
    );
  }

  Widget _buildTrendsTab() {
    return ListView(
      padding: getResponsivePadding(16),
      children: [
       
        _buildDailySalesChart(),
        SizedBox(height: isMobile ? 12 : 16),
       
      ],
    );
  }

  // Hero Section with Duka Info
  Widget _buildHeroSection() {
    final dukaInfo = _analyticsData!['duka_info'];

    return Container(
      padding: getResponsivePadding(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: getResponsivePadding(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4BB4FF).withOpacity(0.2),
                      const Color(0xFF4BB4FF).withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF4BB4FF).withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4BB4FF).withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.store_rounded, color: const Color(0xFF4BB4FF), size: getResponsiveFontSize(32)),
              ),
              SizedBox(width: isMobile ? 12 : 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dukaInfo['name'] ?? 'N/A',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: getResponsiveFontSize(24),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: getResponsiveFontSize(16), color: Colors.white54),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dukaInfo['location'] ?? 'N/A',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: getResponsiveFontSize(14)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: getResponsivePadding(16).left, vertical: getResponsivePadding(8).top),
                decoration: BoxDecoration(
                  color: (dukaInfo['status'] == 'active' ? Colors.green : Colors.grey).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: (dukaInfo['status'] == 'active' ? Colors.green : Colors.grey).withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: (dukaInfo['status'] == 'active' ? Colors.green : Colors.grey).withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dukaInfo['status'] == 'active' ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (dukaInfo['status'] == 'active' ? Colors.green : Colors.grey).withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (dukaInfo['status'] ?? 'N/A').toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: dukaInfo['status'] == 'active' ? Colors.green : Colors.grey,
                        fontSize: getResponsiveFontSize(11),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 20 : 24),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: isMobile
              ? Column(
                  children: [
                    _buildInfoCard(
                      Icons.person_rounded,
                      'Manager',
                      dukaInfo['manager_name'] ?? 'N/A',
                      Colors.blueAccent,
                    ),
                    const SizedBox(height: 4),
                    _buildInfoCard(
                      Icons.calendar_today_rounded,
                      'Period',
                      '${dukaInfo['period']['days']} days',
                      Colors.orangeAccent,
                    ),
                    const SizedBox(height: 4),
                    _buildInfoCard(
                      Icons.date_range_rounded,
                      'Range',
                      '${dukaInfo['period']['start_date']} - ${dukaInfo['period']['end_date']}',
                      Colors.purpleAccent,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        Icons.person_rounded,
                        'Manager',
                        dukaInfo['manager_name'] ?? 'N/A',
                        Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildInfoCard(
                        Icons.calendar_today_rounded,
                        'Period',
                        '${dukaInfo['period']['days']} days',
                        Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildInfoCard(
                        Icons.date_range_rounded,
                        'Range',
                        '${dukaInfo['period']['start_date']} - ${dukaInfo['period']['end_date']}',
                        Colors.purpleAccent,
                      ),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: getResponsivePadding(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        // border: Border.all(color: color.withOpacity(0.2)), // Removed border for cleaner look
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: getResponsiveFontSize(18), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: getResponsiveFontSize(10),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: getResponsiveFontSize(13),
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  

  Widget _buildGrowthScoreDisplay(Map<String, dynamic> indicators) {
    final score = indicators['growth_score']?.toDouble() ?? 0.0;
    final color = _getScoreColor(score);

    return Container(
      padding: getResponsivePadding(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: getResponsiveFontSize(80),
                height: getResponsiveFontSize(80),
                child: CircularProgressIndicator(
                  value: score / 100,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeWidth: 8,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score.toStringAsFixed(1),
                    style: GoogleFonts.plusJakartaSans(
                      color: color,
                      fontSize: getResponsiveFontSize(20),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Growth Score',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: getResponsiveFontSize(10),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Overall Business Performance',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: getResponsiveFontSize(14),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

 Widget _buildStatusCard(Map<String, dynamic> indicators) {
 final color = _getStatusColor(indicators['status_color']);

 // ✅ SAFE numeric conversion
 final double growthScore = indicators['growth_score'] is num
     ? (indicators['growth_score'] as num).toDouble()
     : double.tryParse(indicators['growth_score']?.toString() ?? '0') ?? 0.0;

 return Container(
   padding: getResponsivePadding(16),
   decoration: BoxDecoration(
     color: color.withOpacity(0.1),
     borderRadius: BorderRadius.circular(16),
     border: Border.all(color: color.withOpacity(0.3)),
   ),
   child: Column(
     children: [
       Icon(
         _getStatusIcon(indicators['status_color']),
         color: color,
         size: getResponsiveFontSize(32),
       ),
       const SizedBox(height: 12),
       Text(
         indicators['growth_status']?.toString() ?? 'N/A',
         style: GoogleFonts.plusJakartaSans(
           color: color,
           fontSize: getResponsiveFontSize(14),
           fontWeight: FontWeight.bold,
         ),
         textAlign: TextAlign.center,
       ),
       const SizedBox(height: 8),
       Container(
         width: getResponsiveFontSize(40),
         height: 4,
         decoration: BoxDecoration(
           color: color.withOpacity(0.3),
           borderRadius: BorderRadius.circular(2),
         ),
         child: Stack(
           children: [
             Container(
               width: getResponsiveFontSize(40) * growthScore / 100,
               decoration: BoxDecoration(
                 color: color,
                 borderRadius: BorderRadius.circular(2),
               ),
             ),
           ],
         ),
       ),
     ],
   ),
 );
}

  Widget _buildQuickStatsGrid() {
    final financial = _analyticsData!['financial_summary'];
    final currentPeriod = financial['current_period'];

    return GridView.count(
      crossAxisCount: isMobile ? 1 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isMobile ? 2.4 : 1.8,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildStatCard(
          'Total Revenue',
          _formatCurrency(currentPeriod['revenue']),
          Icons.attach_money_rounded,
          Colors.greenAccent,
          '+${financial['growth_metrics']['revenue_growth'].toStringAsFixed(1)}%',
        ),
        _buildStatCard(
          'Net Profit',
          _formatCurrency(currentPeriod['profit']),
          Icons.trending_up_rounded,
          Colors.blueAccent,
          '+${financial['growth_metrics']['profit_growth'].toStringAsFixed(1)}%',
        ),
        _buildStatCard(
          'Transactions',
          currentPeriod['transactions'].toString(),
          Icons.receipt_long_rounded,
          Colors.purpleAccent,
          '+${financial['growth_metrics']['transaction_growth'].toStringAsFixed(1)}%',
        ),
        _buildStatCard(
          'Avg Order Value',
          _formatCurrency(currentPeriod['average_order_value']),
          Icons.shopping_cart_rounded,
          Colors.orangeAccent,
          '+${financial['growth_metrics']['aov_growth'].toStringAsFixed(1)}%',
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String growth) {
    return Container(
      padding: getResponsivePadding(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: getResponsivePadding(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: getResponsiveFontSize(18), color: color),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: getResponsivePadding(8).left, vertical: getResponsivePadding(4).top),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  growth,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.greenAccent,
                    fontSize: getResponsiveFontSize(10),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: getResponsiveFontSize(18),
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: getResponsiveFontSize(11),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyInsights() {
    final insights = _analyticsData!['performance_indicators']['key_insights'] as List<dynamic>;

    return Container(
      padding: getResponsivePadding(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: Colors.amberAccent, size: getResponsiveFontSize(24)),
              const SizedBox(width: 12),
              Text(
                'Key Business Insights',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: getResponsiveFontSize(18),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          ...insights.map((insight) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: getResponsivePadding(16),
            decoration: BoxDecoration(
              color: Colors.amberAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.tips_and_updates_rounded, size: getResponsiveFontSize(20), color: Colors.amberAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insight.toString(),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: getResponsiveFontSize(14),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // Growth Tab Methods
  Widget _buildGrowthMetrics() {
    final growth = _analyticsData!['financial_summary']['growth_metrics'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comprehensive Growth Analysis',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Detailed breakdown of business performance across multiple metrics',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildGrowthCardDetailed(
                'Revenue Growth',
                '${growth['revenue_growth'].toStringAsFixed(1)}%',
                Icons.trending_up_rounded,
                Colors.green,
                'Sales performance improvement',
              ),
              _buildGrowthCardDetailed(
                'Profit Growth',
                '${growth['profit_growth'].toStringAsFixed(1)}%',
                Icons.account_balance_rounded,
                Colors.blue,
                'Profitability enhancement',
              ),
              _buildGrowthCardDetailed(
                'Sales Income Growth',
                '${growth['sales_income_growth'].toStringAsFixed(1)}%',
                Icons.shopping_cart_rounded,
                Colors.purple,
                'Actual sales revenue growth',
              ),
              _buildGrowthCardDetailed(
                'Gross Profit Growth',
                '${growth['gross_profit_growth'].toStringAsFixed(1)}%',
                Icons.account_balance_wallet_rounded,
                Colors.orange,
                'Margin improvement',
              ),
              _buildGrowthCardDetailed(
                'Transaction Growth',
                '${growth['transaction_growth'].toStringAsFixed(1)}%',
                Icons.receipt_long_rounded,
                Colors.teal,
                'Sales volume increase',
              ),
              _buildGrowthCardDetailed(
                'Cash Flow Growth',
                '${growth['cash_flow_growth'].toStringAsFixed(1)}%',
                Icons.account_balance,
                Colors.cyan,
                'Financial liquidity improvement',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthCardDetailed(String title, String value, IconData icon, Color color, String description) {
    final isPositive = !value.startsWith('-');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 10,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthScoreCard() {
    final indicators = _analyticsData!['performance_indicators'];
    final score = indicators['growth_score']?.toDouble() ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getScoreColor(score).withOpacity(0.2),
            _getScoreColor(score).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getScoreColor(score).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assessment_rounded, color: _getScoreColor(score), size: 24),
              const SizedBox(width: 12),
              Text(
                'Growth Score Breakdown',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Score Visualization
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(score)),
                    strokeWidth: 12,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      score.toStringAsFixed(1),
                      style: GoogleFonts.plusJakartaSans(
                        color: _getScoreColor(score),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Growth Score',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Score Components
          _buildScoreComponent('Revenue Growth', 25, Colors.greenAccent),
          _buildScoreComponent('Profit Growth', 20, Colors.blueAccent),
          _buildScoreComponent('Sales Income Growth', 20, Colors.purpleAccent),
          _buildScoreComponent('Gross Profit Growth', 15, Colors.orangeAccent),
          _buildScoreComponent('Transaction Growth', 10, Colors.tealAccent),
          _buildScoreComponent('Cash Flow Growth', 5, Colors.cyanAccent),
          _buildScoreComponent('Weekly Growth', 5, Colors.pinkAccent),
        ],
      ),
    );
  }

  Widget _buildScoreComponent(String label, int weight, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            '$weight%',
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthTrends() {
    final weeklyGrowth = _analyticsData!['financial_summary']['growth_metrics']['weekly_growth'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Growth Trend Analysis',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          // Weekly vs Period Comparison
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (weeklyGrowth >= 0 ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (weeklyGrowth >= 0 ? Colors.green : Colors.red).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      weeklyGrowth >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: weeklyGrowth >= 0 ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Weekly Performance Trend',
                      style: GoogleFonts.plusJakartaSans(
                        color: weeklyGrowth >= 0 ? Colors.green : Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${weeklyGrowth >= 0 ? '+' : ''}${weeklyGrowth.toStringAsFixed(1)}% week-over-week growth',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  weeklyGrowth >= 0 
                    ? 'Strong weekly momentum with consistent growth'
                    : 'Weekly performance needs attention and improvement',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Products Tab Methods
  Widget _buildProductAnalytics() {
    final products = _analyticsData!['product_analytics'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Portfolio Analysis',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          // Product Summary Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildProductMetricCard(
                'Total Products',
                products['summary']['total_products'].toString(),
                Icons.inventory_2_rounded,
                Colors.blueAccent,
              ),
              _buildProductMetricCard(
                'Active Products',
                products['summary']['active_products'].toString(),
                Icons.check_circle_rounded,
                Colors.greenAccent,
              ),
              _buildProductMetricCard(
                'Low Stock Alerts',
                products['summary']['low_stock_products'].toString(),
                Icons.warning_rounded,
                Colors.orangeAccent,
              ),
              _buildProductMetricCard(
                'Out of Stock',
                products['summary']['out_of_stock_products'].toString(),
                Icons.error_rounded,
                Colors.redAccent,
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
        _buildStockHealthScore(
  (products['summary']['stock_health_score'] as num).toDouble(),
)

        ],
      ),
    );
  }

  Widget _buildProductMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockHealthScore(double score) {
    final color = score >= 80 ? Colors.green : score >= 60 ? Colors.orange : Colors.red;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_rounded, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                'Stock Health Score',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${score.toStringAsFixed(1)}%',
                      style: GoogleFonts.plusJakartaSans(
                        color: color,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStockHealthStatus(score),
                      style: GoogleFonts.plusJakartaSans(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: score / 100,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeWidth: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStockHealthStatus(double score) {
    if (score >= 80) return 'Excellent Stock Health';
    if (score >= 60) return 'Good Stock Health';
    if (score >= 40) return 'Fair Stock Health';
    return 'Poor Stock Health';
  }

  Widget _buildInventoryValueAnalysis() {
    final products = _analyticsData!['product_analytics'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inventory Value Analysis',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildValueCard(
                  'Cost Value',
                  _formatCurrency(products['inventory_value']['total_cost_value']),
                  Icons.price_change_rounded,
                  Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildValueCard(
                  'Selling Value',
                  _formatCurrency(products['inventory_value']['total_selling_value']),
                  Icons.attach_money_rounded,
                  Colors.greenAccent,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_up_rounded, color: Colors.purple, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Potential Profit',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatCurrency(products['inventory_value']['potential_profit']),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.purple,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${products['inventory_value']['profit_margin_potential'].toStringAsFixed(1)}%',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.purple,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Margin',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingProducts() {
    final products = _analyticsData!['product_analytics']['top_selling_products'] as List<dynamic>;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.amberAccent, size: 24),
              const SizedBox(width: 12),
              Text(
                'Top Performing Products',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (products.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.inventory_2_rounded, size: 48, color: Colors.white24),
                  const SizedBox(height: 8),
                  Text(
                    'No sales data available',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                  ),
                ],
              ),
            )
          else
            ...products.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF4BB4FF).withOpacity(0.1),
                      const Color(0xFF1E4976).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4BB4FF).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4BB4FF).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF4BB4FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['product_name'] ?? 'Unknown Product',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.shopping_bag_rounded, size: 12, color: Colors.white54),
                              const SizedBox(width: 4),
                              Text(
                                '${product['total_quantity_sold']} units sold',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(product['total_revenue']),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@ ${_formatCurrency(product['average_selling_price'])}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildStockHealth() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stock Management Insights',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2_rounded, color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock Management Recommendation',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Monitor low stock items and plan restocking to maintain optimal inventory levels',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Customer Tab Methods
  Widget _buildCustomerAnalytics() {
    final customers = _analyticsData!['customer_analytics'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Base Analysis',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildCustomerMetricCard(
                'Total Customers',
                customers['total_customers'].toString(),
                Icons.people_rounded,
                Colors.blueAccent,
              ),
              _buildCustomerMetricCard(
                'Active Customers',
                customers['active_customers'].toString(),
                Icons.person_rounded,
                Colors.greenAccent,
              ),
              _buildCustomerMetricCard(
                'New Customers',
                customers['new_customers'].toString(),
                Icons.person_add_rounded,
                Colors.orangeAccent,
              ),
              _buildCustomerMetricCard(
                'Returning Customers',
                customers['returning_customers'].toString(),
                Icons.repeat_rounded,
                Colors.purpleAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerRetention() {
    final customers = _analyticsData!['customer_analytics'];
    final retentionRate = customers['customer_retention_rate'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Retention Analysis',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (retentionRate >= 70 ? Colors.green : Colors.orange).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (retentionRate >= 70 ? Colors.green : Colors.orange).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.favorite_rounded,
                  color: retentionRate >= 70 ? Colors.green : Colors.orange,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  '${retentionRate.toStringAsFixed(1)}%',
                  style: GoogleFonts.plusJakartaSans(
                    color: retentionRate >= 70 ? Colors.green : Colors.orange,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Customer Retention Rate',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  retentionRate >= 70 
                    ? 'Excellent customer loyalty and retention'
                    : 'Room for improvement in customer retention',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerAcquisition() {
    final customers = _analyticsData!['customer_analytics'];
    final acquisitionRate = customers['customer_acquisition_rate'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Acquisition Analysis',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (acquisitionRate >= 5 ? Colors.green : Colors.orange).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (acquisitionRate >= 5 ? Colors.green : Colors.orange).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  color: acquisitionRate >= 5 ? Colors.green : Colors.orange,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  '${acquisitionRate.toStringAsFixed(1)}%',
                  style: GoogleFonts.plusJakartaSans(
                    color: acquisitionRate >= 5 ? Colors.green : Colors.orange,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Customer Acquisition Rate',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  acquisitionRate >= 5 
                    ? 'Strong customer acquisition momentum'
                    : 'Focus on customer acquisition strategies',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Loans Tab Methods
  Widget _buildLoanAnalytics() {
    final loans = _analyticsData!['loan_analytics'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loan Portfolio Overview',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildLoanMetricCard(
                'Total Loans',
                loans['total_loans'].toString(),
                Icons.account_balance_rounded,
                Colors.blueAccent,
              ),
              _buildLoanMetricCard(
                'Total Amount',
                _formatCurrency(loans['total_loan_amount']),
                Icons.attach_money_rounded,
                Colors.greenAccent,
              ),
              _buildLoanMetricCard(
                'Outstanding',
                loans['outstanding_loans'].toString(),
                Icons.warning_rounded,
                Colors.orangeAccent,
              ),
              _buildLoanMetricCard(
                'Outstanding Amount',
                _formatCurrency(loans['outstanding_amount']),
                Icons.pending_rounded,
                Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoanMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCollection() {
    final loans = _analyticsData!['loan_analytics'];
    final collectionRate = loans['loan_collection_rate'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loan Collection Performance',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (collectionRate >= 80 ? Colors.green : Colors.orange).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (collectionRate >= 80 ? Colors.green : Colors.orange).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: collectionRate >= 80 ? Colors.green : Colors.orange,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  '${collectionRate.toStringAsFixed(1)}%',
                  style: GoogleFonts.plusJakartaSans(
                    color: collectionRate >= 80 ? Colors.green : Colors.orange,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Collection Rate',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  collectionRate >= 80 
                    ? 'Excellent loan collection performance'
                    : 'Improve loan collection strategies',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutstandingLoans() {
    final loans = _analyticsData!['loan_analytics'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Outstanding',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.calculate_rounded, color: Colors.purple, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Average Loan Size',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatCurrency(loans['average_loan_size']),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.purple,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Based on ${loans['total_loans']} total loans',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Trends Tab Methods
  Widget _buildTrendAnalysis() {
    final trends = _analyticsData!['trend_analysis'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Trend Analysis',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            'Comprehensive analysis of business performance trends and patterns',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          
          // Daily Sales Summary
          _buildDailySalesSummary(trends['daily_sales']),
        ],
      ),
    );
  }

 Widget _buildDailySalesSummary(List<dynamic> dailySales) {
  if (dailySales.isEmpty) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.analytics_rounded, size: 48, color: Colors.white24),
            const SizedBox(height: 8),
            Text(
              'No daily sales data available',
              style: GoogleFonts.plusJakartaSans(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ SAFE revenue calculation
  final double totalRevenue = dailySales.fold<double>(0.0, (sum, day) {
    final value = day['revenue'];
    final double revenue = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0.0;
    return sum + revenue;
  });

  // ✅ SAFE transaction calculation
  final int totalTransactions = dailySales.fold<int>(0, (sum, day) {
    final value = day['transactions'];
    final int transactions = value is int
        ? value
        : int.tryParse(value?.toString() ?? '0') ?? 0;
    return sum + transactions;
  });

  final double avgDailyRevenue = totalRevenue / dailySales.length;
  final double avgDailyTransactions = totalTransactions / dailySales.length;

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF4BB4FF).withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF4BB4FF).withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_view_day_rounded, color: const Color(0xFF4BB4FF), size: 24),
            const SizedBox(width: 12),
            Text(
              'Daily Sales Summary',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF4BB4FF),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _buildSummaryMetric(
              'Total Revenue',
              _formatCurrency(totalRevenue),
              Icons.attach_money_rounded,
              Colors.green,
            ),
            _buildSummaryMetric(
              'Total Transactions',
              totalTransactions.toString(),
              Icons.receipt_long_rounded,
              Colors.blue,
            ),
            _buildSummaryMetric(
              'Avg Daily Revenue',
              _formatCurrency(avgDailyRevenue),
              Icons.trending_up_rounded,
              Colors.orange,
            ),
            _buildSummaryMetric(
              'Avg Daily Transactions',
              avgDailyTransactions.toStringAsFixed(1),
              Icons.analytics_rounded,
              Colors.purple,
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildSummaryMetric(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDailySalesChart() {
  final trends = _analyticsData!['trend_analysis'];
  final List<dynamic> dailySales = trends['daily_sales'] as List<dynamic>;

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Sales Trend',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        if (dailySales.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(Icons.show_chart_rounded, size: 48, color: Colors.white24),
                const SizedBox(height: 8),
                Text(
                  'No daily sales data available',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: dailySales.length,
              itemBuilder: (context, index) {
                final day = dailySales[index];

                // ✅ SAFE revenue conversion
                final double revenue = day['revenue'] is num
                    ? (day['revenue'] as num).toDouble()
                    : double.tryParse(day['revenue']?.toString() ?? '0') ?? 0.0;

                // Scale bar height (clamp to avoid UI overflow)
                final double barHeight = (revenue / 1000) * 10;
                final double safeHeight = barHeight.clamp(0.0, 160.0);

                return Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: safeHeight,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4BB4FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatShortDate(day['date']),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        _formatCurrency(revenue),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    ),
  );
}


  

  // Helper Methods
  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFF4BB4FF),
              onPrimary: Colors.white,
              surface: const Color(0xFF0A1B32),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchAnalyticsData();
    }
  }

  String _formatShortDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MM/dd').format(date);
    } catch (e) {
      return dateString;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'success':
        return Icons.check_circle_rounded;
      case 'warning':
        return Icons.warning_rounded;
      case 'error':
        return Icons.error_rounded;
      case 'info':
        return Icons.info_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  Color _getScoreColor(dynamic score) {
    if (score == null) return Colors.grey;
    final doubleScore = score.toDouble();
    if (doubleScore >= 75) return Colors.green;
    if (doubleScore >= 50) return Colors.orange;
    if (doubleScore >= 25) return Colors.amber;
    return Colors.red;
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'success':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatCurrency(dynamic value) {
    final doubleVal = double.tryParse(value?.toString() ?? '0') ?? 0;
    final formattedValue = _currencyFormat.format(doubleVal);
    final currency = _prefsService.getCurrency();
    
    if (currency == 'KES') {
      return '$formattedValue';
    } else if (currency == 'USD') {
      return '\$$formattedValue';
    } else if (currency == 'EUR') {
      return '€$formattedValue';
    } else if (currency == 'GBP') {
      return '£$formattedValue';
    } else {
      return '$currency $formattedValue';
    }
  }
}