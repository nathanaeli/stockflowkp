import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stockflowkp/services/database_service.dart';

class ProductDetailsPage extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductDetailsPage({super.key, required this.product});

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

  String _formatExpiryDate(dynamic rawDate) {
    if (rawDate == null) return 'Not set';

    try {
      DateTime date;
      if (rawDate is String) {
        date = DateTime.parse(rawDate);
      } else if (rawDate is int) {
        date = DateTime.fromMillisecondsSinceEpoch(rawDate);
      } else {
        return rawDate.toString();
      }
      return DateFormat('dd MMM yyyy').format(date); // More readable: 24 Dec 2025
    } catch (e) {
      return rawDate.toString();
    }
  }

  /// NEW: Consistent total stock calculation (same as ProductPage)
  Future<Map<String, int>> _getTotalStock(int productLocalId) async {
    try {
      final db = await DatabaseService().database;
      final int? serverId = product['server_id'] as int?;

      // 1. Bulk stock from 'stocks' table - use same logic as ProductPage
      List<Map<String, dynamic>> stockList = [];
      
      if (serverId != null) {
        // For online products, first try to find stocks by server_id (product_id in stocks table)
        stockList = await db.query(
          'stocks',
          where: 'product_id = ?',
          whereArgs: [serverId],
        );
      }
      
      // If no stocks found by server_id or for offline products, try by local_id
      if (stockList.isEmpty) {
        stockList = await db.query(
          'stocks',
          where: 'product_id = ?',
          whereArgs: [productLocalId],
        );
      }
      
      final int bulkStock = stockList.isNotEmpty ? (stockList.first['quantity'] as int? ?? 0) : 0;

      // 2. Available individual items from 'product_items' - use local_id
      final itemResult = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM product_items
        WHERE product_id = ? AND status = 'available'
      ''', [productLocalId]);
      final int itemStock = itemResult.first['count'] as int;

      return {
        'bulk': bulkStock,
        'items': itemStock,
        'total': bulkStock + itemStock,
      };
    } catch (e) {
      print('Error loading total stock: $e');
      return {'bulk': 0, 'items': 0, 'total': 0};
    }
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

    String _formatQuantity(int qty) {
      return '${quantityFormat.format(qty)} ${qty == 1 ? 'unit' : 'units'}';
    }

    final bool isSynced = product['server_id'] != null;
    final String? imageUrl = product['image_url'];
    final int productLocalId = product['local_id'] as int;

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
          'Product Details',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 20 * fontScale,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.8,
            colors: [Color(0xFF1E4976), Color(0xFF0C223F), Color(0xFF020B18)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: padding.copyWith(top: 16, bottom: 40),
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
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                        ),
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (_, child, progress) =>
                                    progress == null ? child : _imageLoadingPlaceholder(),
                                errorBuilder: (_, __, ___) => _imageErrorPlaceholder(),
                              )
                            : _imageErrorPlaceholder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Product Name + Sync Status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? 'Unnamed Product',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 26 * fontScale,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'SKU: ${product['sku'] ?? 'N/A'}',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white60,
                                fontSize: 15 * fontScale,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isSynced)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 10)
                            ],
                          ),
                          child: Text(
                            'LOCAL',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
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
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Text(
                      product['description'] ?? 'No description provided.',
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
                        child: _infoCard('Base Price', 'TZS ${_formatPrice(product['base_price'])}', fontScale),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _infoCard(
                          'Selling Price',
                          'TZS ${_formatPrice(product['selling_price'])}',
                          fontScale,
                          highlight: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _infoCard('Unit', product['unit']?.toString().toUpperCase() ?? 'N/A', fontScale)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _infoCard(
                          'Status',
                          product['is_active'] == 1 ? 'Active' : 'Inactive',
                          fontScale,
                          color: product['is_active'] == 1 ? Colors.green : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Stock Information - NOW ACCURATE & CONSISTENT
                  _buildSectionTitle('Stock Information', fontScale),
                  const SizedBox(height: 14),

                  FutureBuilder<Map<String, int>>(
                    future: _getTotalStock(productLocalId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: CircularProgressIndicator(color: Color(0xFF4BB4FF)),
                          ),
                        );
                      }

                      final stock = snapshot.data ?? {'bulk': 0, 'items': 0, 'total': 0};
                      final int total = stock['total']!;
                      final bool lowStock = total > 0 && total <= 10;
                      final bool hasStock = total > 0;

                      if (!hasStock) {
                        return _infoCard('Stock Status', 'Out of stock', fontScale, color: Colors.red[300]);
                      }

                      return Column(
                        children: [
                          _infoCard(
                            'Total Available Stock',
                            _formatQuantity(total),
                            fontScale,
                            highlight: true,
                            badge: lowStock ? 'LOW STOCK' : null,
                            badgeColor: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _infoCard('Bulk Stock', _formatQuantity(stock['bulk']!), fontScale),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _infoCard('Tracked Items', _formatQuantity(stock['items']!), fontScale),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
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

  Widget _imageLoadingPlaceholder() {
    return Container(
      color: Colors.white.withOpacity(0.08),
      child: const Center(child: CircularProgressIndicator(color: Color(0xFF4BB4FF))),
    );
  }

  Widget _imageErrorPlaceholder() {
    return Container(
      color: Colors.white.withOpacity(0.08),
      child: const Center(
        child: Icon(Icons.image_not_supported_rounded, color: Colors.white38, size: 80),
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
          color: highlight ? const Color(0xFF4BB4FF).withOpacity(0.5) : Colors.white.withOpacity(0.18),
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
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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