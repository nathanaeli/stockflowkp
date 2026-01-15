import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stockflowkp/services/database_service.dart';

class ProductSearchPage extends StatefulWidget {
  const ProductSearchPage({super.key});

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final db = await DatabaseService().database;
    final products = await db.query('products');
    if (mounted) {
      setState(() {
        _allProducts = List<Map<String, dynamic>>.from(products);
        _filteredProducts = List.from(_allProducts);
        _isLoading = false;
      });
    }
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = List.from(_allProducts);
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredProducts = _allProducts.where((p) {
          final name = p['name']?.toString().toLowerCase() ?? '';
          final sku = p['sku']?.toString().toLowerCase() ?? '';
          return name.contains(lowerQuery) || sku.contains(lowerQuery);
        }).toList();
      }
    });
  }

  void _selectProduct(Map<String, dynamic> product) {
    final qtyController = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1B32),
        title: Text('Enter Quantity', style: GoogleFonts.plusJakartaSans(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              product['name'],
              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Quantity',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(qtyController.text) ?? 1;
              if (qty > 0) {
                Navigator.pop(context);
                Navigator.pop(context, {'product': product, 'quantity': qty});
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
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
        title: Text('Search Products', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterProducts,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by name or SKU...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return ListTile(
                            title: Text(product['name'], style: GoogleFonts.plusJakartaSans(color: Colors.white)),
                            subtitle: Text(
                              'SKU: ${product['sku']} • Stock: ${product['initial_stock']}',
                              style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                            ),
                            trailing: Text(
                              'TZS ${_currencyFormat.format(product['selling_price'])}',
                              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF4BB4FF), fontWeight: FontWeight.bold),
                            ),
                            onTap: () => _selectProduct(product),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}