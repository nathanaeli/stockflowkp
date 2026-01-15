import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/shared_preferences_service.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import 'stock_movement_page.dart';
import 'edit_product_page.dart';

class ProductDetailsPage extends StatefulWidget {
  final int productId;
  final Map<String, dynamic>? basicProductData;

  const ProductDetailsPage({
    Key? key,
    required this.productId,
    this.basicProductData,
  }) : super(key: key);

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late final SharedPreferencesService _prefsService;
  late final NumberFormat _currencyFormat;
  late final ApiService _apiService;
  late final DatabaseService _dbService;

  Map<String, dynamic>? _productData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showAllSales = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _analyticsKey = GlobalKey();
  final GlobalKey _stockKey = GlobalKey();
  final GlobalKey _historyKey = GlobalKey();
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndLoad() async {
    await _initializeServices();
    if (widget.basicProductData != null) {
      _constructPartialData();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
    await _loadProductDetails();
  }

  Future<void> _initializeServices() async {
    _prefsService = await SharedPreferencesService.getInstance();
    _apiService = ApiService();
    _dbService = DatabaseService();

    final String currencyCode = _prefsService.getCurrency() ?? 'TSH';
    final String locale = switch (currencyCode) {
      'KES' => 'en_KE',
      'USD' => 'en_US',
      'EUR' => 'de_DE',
      'GBP' => 'en_GB',
      'TSH' => 'en_TZ',
      _ => 'en_US',
    };

    _currencyFormat = NumberFormat('#,##0.00', locale);
  }

  void _constructPartialData() {
    if (widget.basicProductData == null) return;
    final basic = widget.basicProductData!;
    
    double base = double.tryParse(basic['base_price']?.toString() ?? '0') ?? 0;
    double selling = double.tryParse(basic['selling_price']?.toString() ?? '0') ?? 0;
    double profit = selling - base;
    double margin = base > 0 ? (profit / base) * 100 : 0;

    _productData = {
      'basic_info': {
        'id': basic['id'],
        'name': basic['name'],
        'sku': basic['sku'],
        'description': basic['description'],
        'unit': basic['unit'],
        'barcode': basic['barcode'],
        'is_active': basic['is_active'],
        'image_url': basic['image_url'] ?? basic['image'],
        'created_at': basic['created_at'],
        'updated_at': basic['updated_at'],
      },
      'category': basic['category'] is Map ? basic['category'] : {},
      'pricing': {
        'base_price': base,
        'selling_price': selling,
        'profit_per_unit': profit,
        'profit_margin': margin,
      },
      'stock_summary': {},
      'profit_analysis': {},
    };
  }

  List<dynamic> _safeList(dynamic data) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is Map && data.containsKey('items')) {
      return List<dynamic>.from(data['items'] ?? []);
    }
    return [];
  }

  Future<void> _loadProductDetails() async {
    try {
      setState(() {
        if (_productData == null) _isLoading = true;
        _errorMessage = null;
      });

      final userData = await _dbService.getUserData();
      if (userData?['data']?['token'] == null) {
        throw Exception('Authentication required');
      }

      final token = userData?['data']['token'];
      final response = await _apiService.getProductDetails(widget.productId, token);

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _productData = response['data'] as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to load product');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Product Details',
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadProductDetails,
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
        child: SafeArea(child: _buildBody()),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (_productData == null) {
      return _buildEmptyView();
    }

    final data = _productData!;
    final basic = data['basic_info'] ?? {};
    final imageUrl = basic['image_url']?.toString();

    return RefreshIndicator(
      onRefresh: _loadProductDetails,
      color: Colors.white,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image
            if (imageUrl != null && imageUrl.isNotEmpty)
              _buildHeroImage(imageUrl),
            const SizedBox(height: 20),

            // Core Sections
            _buildBasicInfoSection(data),
            const SizedBox(height: 16),
            if (data['duka'] != null) ...[_buildDukaSection(data['duka']), const SizedBox(height: 16)],
            _buildPricingSection(data),
            const SizedBox(height: 16),
            Container(key: _stockKey, child: _buildStockSummarySection(data)),
            const SizedBox(height: 16),
            Container(key: _analyticsKey, child: _buildProfitAnalysisSection(data)),
            const SizedBox(height: 16),
            _buildInsightsSection(data),
            const SizedBox(height: 16),
            _buildPredictiveStockSection(data),
            const SizedBox(height: 16),

            SizedBox(key: _historyKey),
            // Dynamic Sections
            if (_safeList(data['current_stock_details']).isNotEmpty) ...[
              _buildCurrentStockDetailsSection(data),
              const SizedBox(height: 16),
            ],
            if (_safeList(data['product_items']).isNotEmpty) ...[
              _buildProductItemsSection(data),
              const SizedBox(height: 16),
            ],
            if (_safeList(data['sales_history']).isNotEmpty) ...[
              _buildSalesHistorySection(data),
              const SizedBox(height: 16),
            ],
            if (_safeList(data['stock_movements']).isNotEmpty) ...[
              _buildStockMovementsSection(data),
              const SizedBox(height: 16),
            ],
            if (_safeList(data['stock_transfers']).isNotEmpty) ...[
              _buildStockTransfersSection(data),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1B32),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: _handleBottomNavTap,
        backgroundColor: Colors.transparent,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4BB4FF),
        unselectedItemColor: Colors.white54,
        showUnselectedLabels: true,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'Stock'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz_rounded), label: 'Actions'),
        ],
      ),
    );
  }

  void _handleBottomNavTap(int index) {
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 0:
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
        break;
      case 1:
        if (_stockKey.currentContext != null) {
          Scrollable.ensureVisible(_stockKey.currentContext!, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
        }
        break;
      case 2:
        if (_analyticsKey.currentContext != null) {
          Scrollable.ensureVisible(_analyticsKey.currentContext!, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
        }
        break;
      case 3:
        _showActionsModal();
        break;
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1B32),
        title: Text('Delete Product', style: GoogleFonts.plusJakartaSans(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete this product? This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);
      final userData = await _dbService.getUserData();
      final token = userData?['data']['token'];
      
      if (token != null) {
        final response = await _apiService.deleteTenantProduct(widget.productId, token);
        if (response['success'] == true) {
          if (mounted) {
            Navigator.pop(context); // Close details page
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product deleted successfully'), backgroundColor: Colors.green),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showActionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A1B32),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
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
            Text(
              'Quick Actions',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildActionButton(Icons.edit_rounded, 'Edit Product', Colors.blueAccent, () async {
              Navigator.pop(context);
              if (_productData != null) {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditProductPage(productData: _productData!)),
                );
                if (result == true) _loadProductDetails();
              }
            }),

            const SizedBox(height: 12),
            _buildActionButton(Icons.history_rounded, 'View History', Colors.orangeAccent, () {
              Navigator.pop(context);
              if (_historyKey.currentContext != null) {
                Scrollable.ensureVisible(_historyKey.currentContext!, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
              }
            }),
            const SizedBox(height: 12),
            _buildActionButton(Icons.swap_vert_rounded, 'Stock Movement', Colors.cyanAccent, () {
              Navigator.pop(context);
              if (_productData != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StockMovementPage(
                      movements: _safeList(_productData!['stock_movements']),
                      productName: _productData!['basic_info']?['name'] ?? 'Product',
                    ),
                  ),
                );
              }
            }),
          
            const SizedBox(height: 12),
            _buildActionButton(Icons.delete_outline_rounded, 'Delete Product', Colors.redAccent, () {
              Navigator.pop(context);
              _deleteProduct();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: CachedNetworkImage(
        imageUrl: url,
        height: 240,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
            ),
          ),
          child: const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        errorWidget: (_, __, ___) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.08),
          ),
          child: const Icon(Icons.image_not_supported_rounded, size: 80, color: Colors.white60),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 80, color: Colors.red.shade300),
            const SizedBox(height: 20),
            Text('Oops! Something went wrong',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadProductDetails,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4BB4FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Text('No product data available',
          style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 16)));
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
    required IconData icon,
    required Color accentColor,
    int? itemCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  itemCount != null ? '$title ($itemCount)' : title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text('$label:',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(dynamic value) {
    final double amount = _safeDouble(value);
    final String formatted = _currencyFormat.format(amount);
    final String currency = _prefsService.getCurrency() ?? 'TSH';
    return switch (currency) {
      'KES' => '$formatted KES',
      'USD' => '\$$formatted',
      'EUR' => '€$formatted',
      'GBP' => '£$formatted',
      'TSH' => '$formatted TSH',
      _ => '$currency $formatted',
    };
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
    }
    return 0.0;
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      return DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  Color _statusColor(String? status, {Color defaultColor = Colors.blue}) {
    final s = status?.toLowerCase() ?? '';
    return switch (s) {
      'good' => Colors.green,
      'medium' => Colors.orange,
      'expired' || 'damaged' => Colors.red,
      'available' => Colors.green,
      'sold' => Colors.blueAccent,
      'add' || 'restock' => Colors.green,
      'remove' || 'sale' => Colors.red,
      'completed' => Colors.green,
      'pending' => Colors.orange,
      'cancelled' => Colors.red,
      _ => defaultColor,
    };
  }

  // Sections
  Widget _buildBasicInfoSection(Map<String, dynamic> data) {
    final b = data['basic_info'] ?? {};
    final c = data['category'] ?? {};

    return _buildSection(
      title: 'Basic Information',
      icon: Icons.info_outline_rounded,
      accentColor: const Color(0xFF4BB4FF),
      children: [
        _buildRow('Name', b['name']?.toString() ?? 'Unknown'),
        _buildRow('SKU', b['sku']?.toString() ?? 'N/A'),
        if (b['description']?.toString().isNotEmpty == true)
          _buildRow('Description', b['description']),
        _buildRow('Category', c['name']?.toString() ?? 'N/A'),
        _buildRow('Unit', b['unit']?.toString() ?? 'PCS'),
        _buildRow('Barcode', b['barcode']?.toString() ?? 'N/A'),
        _buildRow('Status', ((b['is_active'] is bool ? b['is_active'] : (b['is_active'] == 1)) ? 'Active' : 'Inactive')),
        _buildRow('Created', _formatDateTime(b['created_at'])),
        _buildRow('Updated', _formatDateTime(b['updated_at'])),
      ],
    );
  }

  Widget _buildDukaSection(Map<String, dynamic> duka) {
    return _buildSection(
      title: 'Store',
      icon: Icons.store_rounded,
      accentColor: Colors.orangeAccent,
      children: [
        _buildRow('Store Name', duka['name']?.toString() ?? 'N/A'),
        _buildRow('Location', duka['location']?.toString() ?? 'N/A'),
      ],
    );
  }

  Widget _buildPricingSection(Map<String, dynamic> data) {
    final p = data['pricing'] ?? {};

    return _buildSection(
      title: 'Pricing',
      icon: Icons.attach_money_rounded,
      accentColor: Colors.greenAccent,
      children: [
        _buildRow('Base Price', _formatCurrency(p['base_price'])),
        _buildRow('Selling Price', _formatCurrency(p['selling_price'])),
        _buildRow('Profit/Unit', _formatCurrency(p['profit_per_unit'])),
        _buildRow('Margin', '${_safeDouble(p['profit_margin']).toStringAsFixed(1)}%'),
      ],
    );
  }

  Widget _buildStockSummarySection(Map<String, dynamic> data) {
    final s = data['stock_summary'] ?? {};

    return _buildSection(
      title: 'Stock Summary',
      icon: Icons.inventory_2_rounded,
      accentColor: Colors.orangeAccent,
      children: [
        _buildRow('Current Stock', s['current_stock']?.toString() ?? '0'),
        _buildRow('Cost Value', _formatCurrency(s['stock_cost_value'])),
        _buildRow('Selling Value', _formatCurrency(s['stock_selling_value'])),
        _buildRow('Profit Potential', _formatCurrency(s['total_profit_potential'])),
        _buildRow('Status', s['stock_status']?.toString() ?? 'Unknown'),
      ],
    );
  }

  Widget _buildProfitAnalysisSection(Map<String, dynamic> data) {
    final a = data['profit_analysis'] ?? {};

    return _buildSection(
      title: 'Profit Analysis',
      icon: Icons.trending_up_rounded,
      accentColor: Colors.tealAccent,
      children: [
        _buildRow('Total Sold', a['total_sold']?.toString() ?? '0'),
        _buildRow('Revenue', _formatCurrency(a['total_revenue'])),
        _buildRow('Cost', _formatCurrency(a['total_cost'])),
        _buildRow('Total Profit', _formatCurrency(a['total_profit'])),
        _buildRow('Margin', '${_safeDouble(a['profit_margin']).toStringAsFixed(1)}%'),
        _buildRow('Avg Price', _formatCurrency(a['average_selling_price'])),
      ],
    );
  }

  Widget _buildInsightsSection(Map<String, dynamic> data) {
    final pricing = data['pricing'] ?? {};
    final analysis = data['profit_analysis'] ?? {};
    final stock = data['stock_summary'] ?? {};
    
    final double margin = _safeDouble(pricing['profit_margin']);
    final double totalSold = _safeDouble(analysis['total_sold']);
    final double currentStock = _safeDouble(stock['current_stock']);
    final double profitPerUnit = _safeDouble(pricing['profit_per_unit']);
    
    String verdict = 'Neutral Performance';
    Color verdictColor = Colors.amber;
    IconData verdictIcon = Icons.remove_circle_outline_rounded;
    List<String> improvements = [];
    
    // Verdict Logic
    if (margin >= 20 && totalSold > 10) {
      verdict = 'Top Performer';
      verdictColor = Colors.greenAccent;
      verdictIcon = Icons.stars_rounded;
    } else if (margin >= 15) {
      verdict = 'Good Product';
      verdictColor = Colors.lightGreenAccent;
      verdictIcon = Icons.thumb_up_rounded;
    } else if (totalSold > 50) {
      verdict = 'High Volume / Low Margin';
      verdictColor = Colors.blueAccent;
      verdictIcon = Icons.trending_up_rounded;
    } else if (margin < 5 && totalSold < 5) {
      verdict = 'Underperforming';
      verdictColor = Colors.redAccent;
      verdictIcon = Icons.warning_rounded;
    }

    // Improvements Logic
    if (margin < 15) {
      improvements.add('Profit margin is low (${margin.toStringAsFixed(1)}%). Consider negotiating better supplier rates or slightly increasing the selling price.');
    }
    if (totalSold < 5 && currentStock > 20) {
      improvements.add('Stock is not moving fast enough. Consider running a discount or bundling with popular items.');
    }
    if (currentStock < 5) {
      improvements.add('Stock levels are critically low. Restock immediately to avoid missing sales opportunities.');
    }
    if (profitPerUnit < 100 && totalSold > 20) {
      improvements.add('High sales volume but low profit per unit. Small price increases could significantly boost total revenue.');
    }
    if (improvements.isEmpty) {
      improvements.add('Current performance is stable. Maintain stock levels and monitor customer feedback.');
    }

    return _buildSection(
      title: 'Performance Insights',
      icon: Icons.insights_rounded,
      accentColor: const Color(0xFFB388FF),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: verdictColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: verdictColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(verdictIcon, size: 32, color: verdictColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verdict,
                      style: GoogleFonts.plusJakartaSans(
                        color: verdictColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on margin, sales volume, and stock.',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Summary',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'This product has generated ${_formatCurrency(analysis['total_revenue'])} in revenue with a ${margin.toStringAsFixed(1)}% margin. Total units sold: ${totalSold.toInt()}.',
          style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 16),
        Text(
          'How to Improve Sales',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...improvements.map((suggestion) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(Icons.arrow_right_rounded, color: verdictColor, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  suggestion,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildPredictiveStockSection(Map<String, dynamic> data) {
    final stock = data['stock_summary'] ?? {};
    final sales = _safeList(data['sales_history']);
    final double currentStock = _safeDouble(stock['current_stock']);

    if (currentStock <= 0) return const SizedBox.shrink();

    // Calculate Daily Sales Rate (Last 30 Days)
    double totalSoldLast30Days = 0;
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    
    bool hasData = false;

    for (var sale in sales) {
      final dateStr = sale['sale_date']?.toString();
      if (dateStr != null) {
        try {
          final date = DateTime.parse(dateStr);
          if (date.isAfter(thirtyDaysAgo)) {
            totalSoldLast30Days += _safeDouble(sale['quantity']);
            hasData = true;
          }
        } catch (_) {}
      }
    }

    if (!hasData || totalSoldLast30Days == 0) {
       return const SizedBox.shrink();
    }

    final double dailyRate = totalSoldLast30Days / 30.0;
    final double daysUntilStockout = currentStock / dailyRate;
    final DateTime estimatedDate = now.add(Duration(days: daysUntilStockout.floor()));
    
    String timeRemaining;
    if (daysUntilStockout < 1) {
      timeRemaining = 'Less than a day';
    } else if (daysUntilStockout < 30) {
      timeRemaining = '${daysUntilStockout.toStringAsFixed(1)} days';
    } else {
      timeRemaining = '${(daysUntilStockout / 30).toStringAsFixed(1)} months';
    }

    Color statusColor = Colors.greenAccent;
    if (daysUntilStockout < 7) statusColor = Colors.redAccent;
    else if (daysUntilStockout < 30) statusColor = Colors.orangeAccent;

    return _buildSection(
      title: 'Predictive Stock',
      icon: Icons.timelapse_rounded,
      accentColor: Colors.indigoAccent,
      children: [
        Row(
          children: [
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: statusColor.withOpacity(0.1),
                 shape: BoxShape.circle,
               ),
               child: Icon(Icons.event_busy_rounded, color: statusColor),
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     'Estimated Stockout',
                     style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
                   ),
                   Text(
                     DateFormat('MMM dd, yyyy').format(estimatedDate),
                     style: GoogleFonts.plusJakartaSans(
                       color: Colors.white, 
                       fontWeight: FontWeight.bold,
                       fontSize: 16
                     ),
                   ),
                 ],
               ),
             ),
             Column(
               crossAxisAlignment: CrossAxisAlignment.end,
               children: [
                 Text(
                   timeRemaining,
                   style: GoogleFonts.plusJakartaSans(
                     color: statusColor,
                     fontWeight: FontWeight.bold,
                     fontSize: 16,
                   ),
                 ),
                 Text(
                   'remaining',
                   style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11),
                 ),
               ],
             )
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPredictionStat('Current Stock', currentStock.toInt().toString()),
              _buildPredictionStat('Avg. Daily Sales', dailyRate.toStringAsFixed(1)),
              _buildPredictionStat('30-Day Sales', totalSoldLast30Days.toInt().toString()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Based on sales trends from the last 30 days.',
          style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildPredictionStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildCurrentStockDetailsSection(Map<String, dynamic> data) {
    final List stocks = _safeList(data['current_stock_details']);

    return _buildSection(
      title: 'Current Stock Details',
      itemCount: stocks.length,
      icon: Icons.warehouse_rounded,
      accentColor: Colors.blueAccent,
      children: stocks.map((stock) {
        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Batch: ${stock['batch_number'] ?? 'Default'}',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor(stock['status']).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(stock['status']?.toString().toUpperCase() ?? 'UNKNOWN',
                        style: GoogleFonts.plusJakartaSans(
                            color: _statusColor(stock['status']), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildRow('Quantity', stock['quantity']?.toString() ?? '0'),
              _buildRow('Value', stock['value']?.toString() ?? 'N/A'),
              if (stock['notes']?.toString().isNotEmpty == true) _buildRow('Notes', stock['notes']),
              _buildRow('Updated By', stock['last_updated_by']?.toString() ?? 'N/A'),
              _buildRow('Updated', _formatDateTime(stock['updated_at'])),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProductItemsSection(Map<String, dynamic> data) {
    final List items = _safeList(data['product_items']);

    return _buildSection(
      title: 'Product Items',
      itemCount: items.length,
      icon: Icons.qr_code_rounded,
      accentColor: Colors.purpleAccent,
      children: items.map((item) {
        final isSold = item['sold_at'] != null;
        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('QR: ${item['qr_code'] ?? 'N/A'}',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor(item['status'], defaultColor: Colors.grey).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(item['status']?.toString().toUpperCase() ?? 'UNKNOWN',
                        style: GoogleFonts.plusJakartaSans(
                            color: _statusColor(item['status'], defaultColor: Colors.grey),
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (isSold) _buildRow('Sold At', _formatDateTime(item['sold_at'])),
              _buildRow('Created', _formatDateTime(item['created_at'])),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSalesHistorySection(Map<String, dynamic> data) {
  final List sales = _safeList(data['sales_history']);
  final int limit = 5;
  final bool showExpandButton = sales.length > limit;
  final List visibleSales = _showAllSales ? sales : (showExpandButton ? sales.take(limit).toList() : sales);

  final List<Widget> children = visibleSales.map<Widget>((sale) {
      // ✅ SAFE handling for int/bool/null
      final dynamic loanValue = sale['is_loan'];
      final bool isLoan = loanValue == true || loanValue == 1;

      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sale #${sale['sale_id']}',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isLoan)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'LOAN',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _buildRow('Customer', sale['customer_name']?.toString() ?? 'Walk-in'),
            _buildRow('Date', _formatDateTime(sale['sale_date']?.toString())),
            _buildRow('Quantity', sale['quantity']?.toString() ?? '0'),
            _buildRow('Unit Price', _formatCurrency(sale['unit_price'])),
            _buildRow('Total', _formatCurrency(sale['total_amount'])),
            _buildRow('Profit', _formatCurrency(sale['total_profit'])),
            if (isLoan)
              _buildRow(
                'Status',
                sale['payment_status']?.toString() ?? 'Pending',
              ),
          ],
        ),
      );
    }).toList();

    if (showExpandButton) {
      children.add(
        InkWell(
          onTap: () {
            setState(() {
              _showAllSales = !_showAllSales;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showAllSales ? 'Show Less' : 'View All Sales (${sales.length})',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _showAllSales ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _buildSection(
      title: 'Sales History',
      itemCount: sales.length,
      icon: Icons.receipt_long_rounded,
      accentColor: Colors.green,
      children: children,
  );
}


  Widget _buildStockMovementsSection(Map<String, dynamic> data) {
    final List movements = _safeList(data['stock_movements']);

    return _buildSection(
      title: 'Stock Movements',
      itemCount: movements.length,
      icon: Icons.swap_vert_rounded,
      accentColor: Colors.cyan,
      children: movements.map((m) {
        final type = m['type']?.toString().toLowerCase() ?? '';
        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${m['quantity_change'] ?? ''} (${m['type']?.toString().toUpperCase()})',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor(m['type'], defaultColor: Colors.grey).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(m['type']?.toString().toUpperCase() ?? 'UNKNOWN',
                        style: GoogleFonts.plusJakartaSans(
                            color: _statusColor(m['type'], defaultColor: Colors.grey),
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildRow('Reason', m['reason']?.toString() ?? 'N/A'),
              _buildRow('From → To', '${m['previous_quantity']} → ${m['new_quantity']}'),
              _buildRow('User', m['user_name']?.toString() ?? 'System'),
              _buildRow('Date', _formatDateTime(m['created_at'])),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStockTransfersSection(Map<String, dynamic> data) {
    final List transfers = _safeList(data['stock_transfers']);

    return _buildSection(
      title: 'Stock Transfers',
      itemCount: transfers.length,
      icon: Icons.swap_horiz_rounded,
      accentColor: Colors.amber,
      children: transfers.map((t) {
        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Transfer #${t['id']}',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor(t['status']).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(t['status']?.toString().toUpperCase() ?? 'UNKNOWN',
                        style: GoogleFonts.plusJakartaSans(
                            color: _statusColor(t['status']), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildRow('From → To', '${t['from_duka_id']} → ${t['to_duka_id']}'),
              _buildRow('Quantity', t['quantity']?.toString() ?? '0'),
              _buildRow('Created', _formatDateTime(t['created_at'])),
            ],
          ),
        );
      }).toList(),
    );
  }
}