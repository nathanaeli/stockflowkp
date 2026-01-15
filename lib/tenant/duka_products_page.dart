import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/shared_preferences_service.dart';
import 'product_details_page.dart';

class DukaProductsPage extends StatefulWidget {
  final List<dynamic> products;
  final List<dynamic> categories;
  final List<dynamic> productStock;

  const DukaProductsPage({
    Key? key,
    required this.products,
    required this.categories,
    required this.productStock,
  }) : super(key: key);

  @override
  State<DukaProductsPage> createState() => _DukaProductsPageState();
}

class _DukaProductsPageState extends State<DukaProductsPage> {
  late SharedPreferencesService _prefsService;
  late NumberFormat _currencyFormat;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  
  }

  Future<void> _initializeServices() async {
    print("welcome ........................");
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
    
    setState(() {
      _currencyFormat = NumberFormat('#,##0.00', locale);
    });
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
        title: Text(
          'Products (${widget.products.length})',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
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
          child: widget.products.isEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Products',
                            widget.products.length.toString(),
                            Icons.inventory_2_rounded,
                            const Color(0xFF4BB4FF),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            'Categories',
                            widget.categories.length.toString(),
                            Icons.category_rounded,
                            Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'In Stock',
                            _getTotalStock().toString(),
                            Icons.warehouse_rounded,
                            Colors.orangeAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            'Active',
                            _getActiveCount().toString(),
                            Icons.check_circle_rounded,
                            Colors.tealAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Products List
                    Text(
                      'All Products',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...widget.products.map((product) => _buildProductCard(product)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_rounded,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Products Found',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This duka has no products yet',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(dynamic product) {
    final category = widget.categories.firstWhere(
      (cat) => cat['id'] == product['category']?['id'],
      orElse: () => null,
    );

    final stock = widget.productStock.firstWhere(
      (stock) => stock['product_id'] == product['id'],
      orElse: () => null,
    );

    return Container(
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
                  color: const Color(0xFF4BB4FF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2_rounded, size: 16, color: Color(0xFF4BB4FF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] ?? 'N/A',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'SKU: ${product['sku'] ?? 'N/A'}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (product['is_active'] == true ? Colors.green : Colors.grey).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  product['is_active'] == true ? 'Active' : 'Inactive',
                  style: GoogleFonts.plusJakartaSans(
                    color: product['is_active'] == true ? Colors.green : Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Product Details
          Row(
            children: [
              Expanded(
                child: _buildProductDetail('Category', category?['name'] ?? 'N/A'),
              ),
              Expanded(
                child: _buildProductDetail('Unit', product['unit'] ?? 'N/A'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildProductDetail('Cost Price', _formatCurrency(product['base_price'])),
              ),
              Expanded(
                child: _buildProductDetail('Selling Price', _formatCurrency(product['selling_price'])),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildProductDetail('Current Stock', stock?['quantity']?.toString() ?? '0'),
              ),
              Expanded(
                child: _buildProductDetail('Barcode', product['barcode'] ?? 'N/A'),
              ),
            ],
          ),

          // Enhanced Information
          if (_hasProfitMargin(product)) ...[
            const SizedBox(height: 12),
            _buildProfitInfo(product),
          ],

          if (_hasStockStatus(stock)) ...[
            const SizedBox(height: 8),
            _buildStockStatusInfo(stock),
          ],

          if (product['description'] != null && product['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Description',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              product['description'],
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // View Details Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _navigateToProductDetails(product),
              icon: const Icon(Icons.info_outline_rounded, size: 16),
              label: const Text('View Full Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4BB4FF).withOpacity(0.2),
                foregroundColor: const Color(0xFF4BB4FF),
                side: BorderSide(color: const Color(0xFF4BB4FF).withOpacity(0.5)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  int _getTotalStock() {
    return widget.productStock.fold(0, (sum, stock) => sum + (stock['quantity'] as int? ?? 0));
  }

  int _getActiveCount() {
    return widget.products.where((product) => product['is_active'] == true).length;
  }

  String _formatCurrency(dynamic value) {
    final doubleVal = double.tryParse(value?.toString() ?? '0') ?? 0;
    final formattedValue = _currencyFormat.format(doubleVal);
    final currency = _prefsService.getCurrency();
    
    // Return formatted value with currency symbol or code
    if (currency == 'KES') {
      return '$formattedValue KES';
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

  // Helper methods for enhanced product display
  bool _hasProfitMargin(dynamic product) {
    final basePrice = double.tryParse(product['base_price']?.toString() ?? '0') ?? 0;
    final sellingPrice = double.tryParse(product['selling_price']?.toString() ?? '0') ?? 0;
    return basePrice > 0 && sellingPrice > 0;
  }

  Widget _buildProfitInfo(dynamic product) {
    final basePrice = double.tryParse(product['base_price']?.toString() ?? '0') ?? 0;
    final sellingPrice = double.tryParse(product['selling_price']?.toString() ?? '0') ?? 0;
    final profitPerUnit = sellingPrice - basePrice;
    final profitMargin = basePrice > 0 ? (profitPerUnit / basePrice) * 100 : 0;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up_rounded, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profit: ${_formatCurrency(profitPerUnit)} per unit',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Margin: ${profitMargin.toStringAsFixed(1)}%',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.green,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasStockStatus(dynamic stock) {
    return stock != null && stock['quantity'] != null;
  }

  Widget _buildStockStatusInfo(dynamic stock) {
    final quantity = stock['quantity'] as int? ?? 0;
    String status = 'In Stock';
    Color statusColor = Colors.green;
    
    if (quantity == 0) {
      status = 'Out of Stock';
      statusColor = Colors.red;
    } else if (quantity < 10) {
      status = 'Low Stock';
      statusColor = Colors.orange;
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            quantity == 0 ? Icons.error_outline_rounded : 
            quantity < 10 ? Icons.warning_rounded : Icons.check_circle_rounded,
            color: statusColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$status ($quantity units)',
              style: GoogleFonts.plusJakartaSans(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
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
}