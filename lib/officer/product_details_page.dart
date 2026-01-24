import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stockflowkp/officer/edit_product_page.dart'; // Ensure this import exists
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/sync_service.dart';

class ProductDetailsPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsPage({super.key, required this.product});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late Map<String, dynamic> _product;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0A1B32),
            title: Text(
              'Delete Product',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            content: Text(
              'Are you sure you want to delete "${_product['name']}"? This action cannot be undone.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final token = await SyncService().getAuthToken();
      if (token == null) throw Exception('Not authenticated');

      await ApiService().deleteProduct(_product['id'], token);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Go back to list and refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showStockDialog() async {
    String operation = 'add';
    final quantityController = TextEditingController();
    final reasonController = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setStateCtx) {
              return AlertDialog(
                backgroundColor: const Color(0xFF0A1B32),
                title: Text(
                  'Manage Stock',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: operation,
                      dropdownColor: const Color(0xFF1E4976),
                      style: GoogleFonts.plusJakartaSans(color: Colors.white),
                      items: const [
                        DropdownMenuItem(
                          value: 'add',
                          child: Text('Add Stock'),
                        ),
                        DropdownMenuItem(
                          value: 'reduce',
                          child: Text('Reduce Stock'),
                        ),
                        DropdownMenuItem(
                          value: 'set',
                          child: Text('Set Quantity'),
                        ),
                      ],
                      onChanged: (v) => setStateCtx(() => operation = v!),
                      decoration: const InputDecoration(
                        labelText: 'Operation',
                        filled: true,
                        fillColor: Colors.white10,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        filled: true,
                        fillColor: Colors.white10,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Reason (Optional)',
                        filled: true,
                        fillColor: Colors.white10,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final qty = int.tryParse(quantityController.text);
                      if (qty == null || qty <= 0) return;

                      try {
                        final token = await SyncService().getAuthToken();
                        if (token == null) return;

                        await ApiService().updateStock({
                          'product_id': _product['id'],
                          'quantity_change': qty,
                          'operation': operation,
                          'reason': reasonController.text,
                        }, token);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Stock updated successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.pop(ctx);
                          // Ideally refresh product details here
                          // For now, assume success and maybe updating local state manually or popping back?
                          // Navigator.pop(context); // Optional: go back to refresh list
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text('Update'),
                  ),
                ],
              );
            },
          ),
    );
  }

  EdgeInsets getPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width > 900) return const EdgeInsets.symmetric(horizontal: 60);
    if (width > 600) return const EdgeInsets.symmetric(horizontal: 40);
    return const EdgeInsets.symmetric(horizontal: 20);
  }

  double getFontScale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width > 800) return 1.1;
    if (width < 360) return 0.9;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final padding = getPadding(context);
    final fontScale = getFontScale(context);
    final isLargeScreen = MediaQuery.sizeOf(context).width > 600;

    final NumberFormat currencyFormat = NumberFormat('#,##0', 'en_US');
    final NumberFormat quantityFormat = NumberFormat('#,##0', 'en_US');

    String _formatPrice(dynamic price) {
      if (price == null) return '0';
      final num value = price is String ? num.tryParse(price) ?? 0 : price;
      return currencyFormat.format(value);
    }

    String _formatQuantity(dynamic qty) {
      final val =
          qty is int ? qty : (int.tryParse(qty?.toString() ?? '0') ?? 0);
      return '${quantityFormat.format(val)} ${_product['unit'] ?? ''}';
    }

    final String? imageUrl = _product['image_url'];
    // For API-first, we use 'current_stock' or 'initial_stock' or fetch stock details separately.
    // Assuming 'current_stock' might be in the map if coming from list API, or we need to look at 'stocks' list if complex.
    // The previous code had complex local DB stock logic. Since we are API-first, we rely on the product object or need to fetch details.
    // Let's assume _product has a 'stock_summary' or similar if it was a details fetch, or just 'initial_stock' from list.
    // However, the USER request says "Add a new product with optional initial stock".
    // The GET details response has `stock_summary`.
    // We should probably rely on `_product['stock_summary']['total_quantity']` if available, else 0.
    final stockSummary = _product['stock_summary'] as Map<String, dynamic>?;
    final int totalStock =
        stockSummary != null
            ? (stockSummary['total_quantity'] as int)
            : (_product['current_stock'] as int? ?? 0);

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
          'Product Details',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 20 * fontScale,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProductPage(product: _product),
                ),
              );
              if (result == true) {
                if (mounted) {
                  Navigator.pop(context, true);
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: _deleteProduct,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showStockDialog,
        backgroundColor: const Color(0xFF4BB4FF),
        icon: const Icon(Icons.inventory, color: Colors.white),
        label: Text(
          'Manage Stock',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topLeft,
                    radius: 1.8,
                    colors: [
                      Color(0xFF1E4976),
                      Color(0xFF0C223F),
                      Color(0xFF020B18),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: padding.copyWith(top: 16, bottom: 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hero Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: AspectRatio(
                              aspectRatio: isLargeScreen ? 16 / 9 : 4 / 3,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                ),
                                child:
                                    imageUrl != null && imageUrl.isNotEmpty
                                        ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (_, __, ___) =>
                                                  _imageErrorPlaceholder(),
                                        )
                                        : _imageErrorPlaceholder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Product Name
                          Text(
                            _product['name'] ?? 'Unnamed Product',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 26 * fontScale,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'SKU: ${_product['sku'] ?? 'N/A'}',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white60,
                              fontSize: 15 * fontScale,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Description
                          _buildSectionTitle('Description', fontScale),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                              ),
                            ),
                            child: Text(
                              _product['description'] ??
                                  'No description provided.',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 15 * fontScale,
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Pricing & Details
                          _buildSectionTitle('Pricing & Details', fontScale),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _infoCard(
                                  'Buying Price',
                                  'TZS ${_formatPrice(_product['buying_price'] ?? _product['base_price'])}',
                                  fontScale,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _infoCard(
                                  'Selling Price',
                                  'TZS ${_formatPrice(_product['selling_price'])}',
                                  fontScale,
                                  highlight: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _infoCard(
                                  'Unit',
                                  _product['unit']?.toString().toUpperCase() ??
                                      'N/A',
                                  fontScale,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final raw = _product['is_active'];
                                    final bool isActive =
                                        raw == 1 ||
                                        raw == true ||
                                        raw == '1' ||
                                        raw == 'true';
                                    return _infoCard(
                                      'Status',
                                      isActive ? 'Active' : 'Inactive',
                                      fontScale,
                                      color:
                                          isActive
                                              ? Colors.green
                                              : Colors.redAccent,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Stock Information
                          _buildSectionTitle('Stock Information', fontScale),
                          const SizedBox(height: 14),

                          Column(
                            children: [
                              _infoCard(
                                'Total Available Stock',
                                _formatQuantity(totalStock),
                                fontScale,
                                highlight: true,
                                badge: totalStock <= 10 ? 'LOW STOCK' : null,
                                badgeColor: Colors.red,
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildSectionTitle(String title, double fontScale) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 19 * fontScale,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _imageErrorPlaceholder() {
    return Container(
      color: Colors.white.withOpacity(0.08),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          color: Colors.white38,
          size: 80,
        ),
      ),
    );
  }

  Widget _infoCard(
    String label,
    String value,
    double fontScale, {
    bool highlight = false,
    Color? color,
    String? badge,
    Color? badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(highlight ? 0.11 : 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              highlight
                  ? const Color(0xFF4BB4FF).withOpacity(0.5)
                  : Colors.white.withOpacity(0.18),
          width: highlight ? 2 : 1.5,
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white60,
                  fontSize: 12 * fontScale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: color ?? Colors.white,
                  fontSize: 17 * fontScale,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (badge != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: badgeColor ?? Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
