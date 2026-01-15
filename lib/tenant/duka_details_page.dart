import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/shared_preferences_service.dart';
import 'duka_products_page.dart';
import 'duka_sales_page.dart';
import 'duka_customers_page.dart';
import 'product_details_page.dart';
import '../officer/create_sale_page.dart';
import 'duka_analysis_page.dart';

class DukaDetailsPage extends StatefulWidget {
  final Map<String, dynamic> duka;

  const DukaDetailsPage({Key? key, required this.duka}) : super(key: key);

  @override
  State<DukaDetailsPage> createState() => _DukaDetailsPageState();
}

class _DukaDetailsPageState extends State<DukaDetailsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _dukaData;
  Map<String, dynamic>? _dukaOverview;
  String? _error;
  int _currentIndex = 0;
  List<Map<String, dynamic>> _loansWithPayments = [];
  late SharedPreferencesService _prefsService;
  late NumberFormat _currencyFormat;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _fetchDukaDetails();
  }

  Future<void> _initializeServices() async {
    _prefsService = await SharedPreferencesService.getInstance();
    _setupCurrencyFormatter();
  }

  void _setupCurrencyFormatter() {
    final currency = _prefsService.getCurrency();
    // Create locale based on currency (fallback to en_US)
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

  Future<void> _fetchDukaDetails() async {
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
      final response = await apiService.getDukaProducts(token, widget.duka['id']);

      if (!mounted) return;
      if (response['success'] == true) {
        setState(() {
          _dukaData = response['data'];
          _isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch duka details');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
          _getAppBarTitle(),
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: IconButton(
                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
                onPressed: () {},
                padding: EdgeInsets.zero,
              ),
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
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4BB4FF)))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent.withOpacity(0.8)),
                          const SizedBox(height: 16),
                          Text('Error: $_error', style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchDukaDetails,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4BB4FF),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _buildBody(),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
      
    );
  }

  String _getAppBarTitle() {
    if (_dukaData == null) return widget.duka['name'] ?? 'Duka Details';
    switch (_currentIndex) {
      case 1:
        return 'Products';
      case 2:
        return 'Categories';
      case 3:
        return 'Customers';
      case 4:
        return 'Stock Levels';
      case 5:
        return 'Sales';
      default:
        return widget.duka['name'] ?? 'Duka Details';
    }
  }

  Widget _buildBody() {
    if (_dukaData == null) return const SizedBox();
    return RefreshIndicator(
      onRefresh: _fetchDukaDetails,
      child: _buildCurrentView(),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboardView();
      case 1:
        return _buildProductsView();
      case 2:
        return _buildCategoriesView();
      case 3:
        return _buildCustomersView();
      case 4:
        return _buildStockView();
      case 5:
        return _buildSalesView();
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    if (_dukaData == null) return const SizedBox();

    final summary = widget.duka['summary'];
    final loans = _loansWithPayments;
    final todaySales = widget.duka['today_sales'] as List<dynamic>? ?? [];

    final categories = _dukaData!['categories'] as List<dynamic>? ?? [];
    final products = _dukaData!['products'] as List<dynamic>? ?? [];
    final customers = _dukaData!['customers'] as List<dynamic>? ?? [];
    final productItems = _dukaData!['product_items'] as List<dynamic>? ?? [];
    final productStock = _dukaData!['product_stock'] as List<dynamic>? ?? [];
    final sales = _dukaData!['sales'] as List<dynamic>? ?? [];

    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Duka Header Info
          Container(
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4BB4FF).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.store_rounded, color: Color(0xFF4BB4FF), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.duka['name'] ?? 'N/A',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.duka['location'] ?? 'N/A',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (widget.duka['status'] == 'active' ? Colors.green : Colors.grey).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: (widget.duka['status'] == 'active' ? Colors.green : Colors.grey).withOpacity(0.5)),
                      ),
                      child: Text(
                        (widget.duka['status'] ?? 'N/A').toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: widget.duka['status'] == 'active' ? Colors.green : Colors.grey,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoRow(Icons.person_rounded, 'Manager: ${widget.duka['manager_name'] ?? 'N/A'}'),
                if (widget.duka['latitude'] != null && widget.duka['longitude'] != null)
                  _buildInfoRow(Icons.location_on_rounded, 'Coordinates: ${widget.duka['latitude']}, ${widget.duka['longitude']}'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Summary Statistics
          Text(
            'Summary Statistics',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildStatCard('Total Sales', summary['total_sales']?.toString() ?? '0', Icons.shopping_cart_rounded, const Color(0xFF4BB4FF)),
              _buildStatCard('Total Revenue', _formatCurrency(summary['total_revenue']), Icons.attach_money_rounded, Colors.greenAccent),
              _buildStatCard('Total Customers', summary['total_customers']?.toString() ?? '0', Icons.people_rounded, Colors.orangeAccent),
              _buildStatCard('Total Products', summary['total_products']?.toString() ?? '0', Icons.inventory_rounded, Colors.purpleAccent),
              _buildStatCard('Total Loans', summary['total_loans']?.toString() ?? '0', Icons.account_balance_rounded, Colors.redAccent),
              _buildStatCard('Today Sales', summary['today_sales_count']?.toString() ?? '0', Icons.today_rounded, Colors.tealAccent),
              _buildStatCard('Today Revenue', _formatCurrency(summary['today_sales_revenue']), Icons.trending_up_rounded, Colors.amberAccent),
              _buildStatCard('Profit/Loss', _formatCurrency(summary['total_profit_loss']), Icons.analytics_rounded, Colors.pinkAccent),
            ],
          ),
          const SizedBox(height: 16),

          // Additional Data Sections
          _buildDataSection('Product Items', productItems, Icons.qr_code_rounded, Colors.purpleAccent),
          _buildDataSection('All Sales', sales, Icons.receipt_long_rounded, const Color(0xFF4BB4FF)),
          
          // Analytics Section
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DukaAnalysisPage(
                  dukaId: widget.duka['id'],
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amberAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amberAccent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.analytics_rounded, size: 20, color: Colors.amberAccent),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Advanced Analytics',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'View detailed insights and growth metrics',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.amberAccent,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),

          // Loans Section
          if (loans.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Recent Loans (${loans.length})',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ...loans.take(5).map((loan) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.credit_card_rounded, size: 16, color: Colors.orangeAccent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          loan['customer_name'] ?? 'N/A',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(loan['payment_status']).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          loan['payment_status'] ?? 'N/A',
                          style: GoogleFonts.plusJakartaSans(
                            color: _getStatusColor(loan['payment_status']),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLoanDetail('Amount', _formatCurrency(loan['total_amount'])),
                      ),
                      Expanded(
                        child: _buildLoanDetail('Remaining', _formatCurrency(loan['remaining_balance'])),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLoanDetail('Due Date', loan['due_date'] ?? 'N/A'),
                      ),
                      Expanded(
                        child: _buildLoanDetail('Created', _formatDate(loan['created_at'])),
                      ),
                    ],
                  ),
                  if (loan['payments'] != null && (loan['payments'] as List).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Payments:',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(loan['payments'] as List<dynamic>).map((payment) => Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatCurrency(payment['amount']),
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            _formatDate(payment['payment_date']),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            )),
          ],

          // Today's Sales Section
          if (todaySales.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Today\'s Sales (${todaySales.length})',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ...todaySales.take(5).map((sale) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4BB4FF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF4BB4FF)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sale['customer_name'] ?? 'N/A',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Amount: ${_formatCurrency(sale['total_amount'])}',
                                style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Profit: ${_formatCurrency(sale['profit_loss'])}',
                                style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${sale['is_loan'] == true ? 'Loan' : 'Sale'}',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDate(sale['created_at']),
                    style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            )),
          ],
        ],
      );
  }

  Widget _buildDataSection(String title, List<dynamic> items, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _navigateToDetailPage(title, items),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${items.length} items',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white54,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToDetailPage(String title, List<dynamic> items) {
    switch (title) {
      case 'Products':
        setState(() => _currentIndex = 1);
        break;
      case 'Categories':
        setState(() => _currentIndex = 2);
        break;
      case 'Customers':
        setState(() => _currentIndex = 3);
        break;
      case 'Stock Levels':
        setState(() => _currentIndex = 4);
        break;
      case 'All Sales':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DukaSalesPage(sales: _dukaData!['sales'])),
        );
        break;
    }
  }

  String _getItemTitle(dynamic item, String section) {
    switch (section) {
      case 'Categories':
        return item['name'] ?? 'N/A';
      case 'Products':
        return item['name'] ?? 'N/A';
      case 'Customers':
        return item['name'] ?? 'N/A';
      case 'Product Items':
        return 'Item ${item['id']}';
      case 'Stock Levels':
        return 'Stock ${item['id']}';
      case 'All Sales':
        return item['customer_name'] ?? 'N/A';
      default:
        return 'Item';
    }
  }

  String _getItemSubtitle(dynamic item, String section) {
    switch (section) {
      case 'Categories':
        return item['description'] ?? '';
      case 'Products':
        return _formatCurrency(item['selling_price']);
      case 'Customers':
        return item['phone'] ?? '';
      case 'Product Items':
        return item['status'] ?? 'N/A';
      case 'Stock Levels':
        return '${item['quantity']} units';
      case 'All Sales':
        return _formatCurrency(item['total_amount']);
      default:
        return '';
    }
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const Spacer(),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: Colors.white60,
                    fontWeight: FontWeight.w500,
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

  Widget _buildLoanDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'fully paid':
        return Colors.green;
      case 'partially paid':
        return Colors.orange;
      case 'unpaid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatCurrency(dynamic value) {
    final doubleVal = double.tryParse(value?.toString() ?? '0') ?? 0;
    final formattedValue = _currencyFormat.format(doubleVal);
    final currency = _prefsService.getCurrency();
    
    // Return formatted value with currency symbol or code
    if (currency == 'KES') {
      return '$formattedValue';
    } else if (currency == 'USD') {
      return '\$formattedValue';
    } else if (currency == 'EUR') {
      return '€$formattedValue';
    } else if (currency == 'GBP') {
      return '£$formattedValue';
    } else {
      // Default: show currency code before amount
      return '$currency $formattedValue';
    }
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1B32),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.transparent,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4BB4FF),
        unselectedItemColor: Colors.white54,
        showUnselectedLabels: true,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'Products'),
          BottomNavigationBarItem(icon: Icon(Icons.category_rounded), label: 'Category'),
          BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Customers'),
          BottomNavigationBarItem(icon: Icon(Icons.warehouse_rounded), label: 'Stock'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Sales'),
        ],
      ),
    );
  }

  Widget _buildProductsView() {
    final products = _dukaData!['products'] as List<dynamic>? ?? [];
    if (products.isEmpty) return _buildEmptyState('No Products', Icons.inventory_2_rounded);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return GestureDetector(
          onTap: () => _navigateToProductDetails(product),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4BB4FF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_2_rounded, size: 20, color: Color(0xFF4BB4FF)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] ?? 'N/A',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'SKU: ${product['sku'] ?? 'N/A'}',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(product['selling_price']),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4BB4FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'View Details',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF4BB4FF),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToProductDetails(dynamic product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsPage(
          productId: product['id'],
          basicProductData: product,
        ),
      ),
    );
  }

  Widget _buildCategoriesView() {
    final categories = _dukaData!['categories'] as List<dynamic>? ?? [];
    if (categories.isEmpty) return _buildEmptyState('No Categories', Icons.category_rounded);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.category_rounded, size: 20, color: Colors.blueAccent),
          ),
          title: Text(
            category['name'] ?? 'N/A',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
            category['description'] ?? 'No description',
            style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11),
          ),
        );
      },
    );
  }

  Widget _buildCustomersView() {
    final customers = _dukaData!['customers'] as List<dynamic>? ?? [];
    if (customers.isEmpty) return _buildEmptyState('No Customers', Icons.people_rounded);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, size: 20, color: Colors.orangeAccent),
          ),
          title: Text(
            customer['name'] ?? 'N/A',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
            customer['phone'] ?? 'No phone',
            style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11),
          ),
        );
      },
    );
  }

  Widget _buildStockView() {
    final stocks = _dukaData!['product_stock'] as List<dynamic>? ?? [];
    final products = _dukaData!['products'] as List<dynamic>? ?? [];
    if (stocks.isEmpty) return _buildEmptyState('No Stock Data', Icons.warehouse_rounded);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: stocks.length,
      itemBuilder: (context, index) {
        final stock = stocks[index];
        final product = products.firstWhere(
          (p) => p['id'] == stock['product_id'],
          orElse: () => {'name': 'Unknown Product', 'unit': ''},
        );
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.tealAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warehouse_rounded, size: 20, color: Colors.tealAccent),
          ),
          title: Text(
            product['name'],
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
            'Batch: ${stock['batch_number'] ?? 'N/A'}',
            style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stock['quantity']}',
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                product['unit'] ?? 'Units',
                style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 9),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSalesView() {
    final sales = _loansWithPayments;
    if (sales.isEmpty) return _buildEmptyState('No Loan Sales', Icons.receipt_long_rounded);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4BB4FF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded, size: 20, color: Color(0xFF4BB4FF)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale['customer_name'] ?? 'N/A',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'ID: ${sale['id']}',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(sale['total_amount']),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Rem: ${_formatCurrency(sale['remaining_balance'])}',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 10),
                  ),
                  Text(
                    _formatDate(sale['created_at']),
                    style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _showQuickActionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A1B32).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Actions',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _buildGridActionButton(
                    Icons.receipt_long_rounded,
                    'New Sale',
                    'Process transaction',
                    const Color(0xFF4BB4FF),
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateSalePage()),
                      );
                    },
                  ),
                  _buildGridActionButton(
                    Icons.add_box_rounded,
                    'Add Product',
                    'New inventory item',
                    Colors.purpleAccent,
                    () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Add Product feature coming soon')),
                      );
                    },
                  ),
                  _buildGridActionButton(
                    Icons.person_add_rounded,
                    'Add Customer',
                    'Register client',
                    Colors.orangeAccent,
                    () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Add Customer feature coming soon')),
                      );
                    },
                  ),
                  _buildGridActionButton(
                    Icons.inventory_rounded,
                    'Restock',
                    'Update quantities',
                    Colors.tealAccent,
                    () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Restock feature coming soon')),
                      );
                    },
                  ),
                  _buildGridActionButton(
                    Icons.analytics_rounded,
                    'Analytics',
                    'View detailed analytics',
                    Colors.amberAccent,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DukaAnalysisPage(
                            dukaId: widget.duka['id'],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridActionButton(IconData icon, String label, String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
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
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}