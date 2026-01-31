import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/officer/product_details_page.dart';

class CategoryProductsPage extends StatefulWidget {
  final Map<String, dynamic> category;

  const CategoryProductsPage({super.key, required this.category});

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final serverId = widget.category['server_id'] as int?;
    if (serverId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final products = await DatabaseService().getProductsByCategory(serverId);
    if (mounted) {
      setState(() {
        _products = products;
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category['name'] ?? 'Products',
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
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4BB4FF)),
                  )
                  : _products.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products in this category',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return Card(
                        color: Colors.white.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) =>
                                          ProductDetailsPage(product: product),
                                ),
                              ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              image:
                                  product['image_url'] != null
                                      ? DecorationImage(
                                        image: NetworkImage(
                                          product['image_url'],
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                      : null,
                            ),
                            child:
                                product['image_url'] == null
                                    ? const Icon(
                                      Icons.inventory_2_rounded,
                                      color: Colors.white54,
                                    )
                                    : null,
                          ),
                          title: Text(
                            product['name'] ?? 'Unknown',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'SKU: ${product['sku'] ?? 'N/A'}',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            'TZS ${product['selling_price']}',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF4BB4FF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ),
    );
  }
}
