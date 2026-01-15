import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/utils/qr_scanner.dart';
import 'view_proforma_invoice_page.dart';

class CreateProformaInvoicePage extends StatefulWidget {
  const CreateProformaInvoicePage({super.key});

  @override
  State<CreateProformaInvoicePage> createState() => _CreateProformaInvoicePageState();
}

class _CreateProformaInvoicePageState extends State<CreateProformaInvoicePage> {
  final List<Map<String, dynamic>> _cart = [];
  bool _isLoading = false;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  Map<String, dynamic>? _selectedCustomer;
  
  List<Map<String, dynamic>> _popularProducts = [];

  double get _totalAmount => _cart.fold(0, (sum, item) => sum + (item['subtotal'] as double));
  int get _totalItems => _cart.fold(0, (sum, item) => sum + (item['quantity'] as int));

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final products = await DatabaseService().getPopularProducts(limit: 20);
      final enriched = await _enrichProductsWithStock(products);
      
      if (mounted) {
        setState(() {
          _popularProducts = enriched;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _enrichProductsWithStock(List<Map<String, dynamic>> products) async {
    final db = await DatabaseService().database;
    List<Map<String, dynamic>> enriched = [];

    for (var product in products) {
      final localId = product['local_id'] as int;
      final serverId = product['server_id'] as int?;

      int bulkQty = 0;
      List<Map<String, dynamic>> stockList = [];
      
      if (serverId != null) {
        stockList = await db.query('stocks', where: 'product_id = ?', whereArgs: [serverId]);
      }
      if (stockList.isEmpty) {
        stockList = await db.query('stocks', where: 'product_id = ?', whereArgs: [localId]);
      }
      if (stockList.isNotEmpty) {
        bulkQty = stockList.first['quantity'] as int? ?? 0;
      }

      final itemRes = await db.rawQuery(
        "SELECT COUNT(*) as count FROM product_items WHERE product_id = ? AND status = 'available'",
        [localId]
      );
      final int itemQty = itemRes.first['count'] as int? ?? 0;

      enriched.add({...product, 'stock_quantity': bulkQty + itemQty});
    }
    return enriched;
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRCodeScanner(
          onQRCodeScanned: (code) {
            Navigator.pop(context, code);
          },
          initialMessage: 'Scan product barcode or QR code',
        ),
      ),
    );

    if (result != null && result is String) {
      _addProductToCartByCode(result);
    }
  }

  Future<void> _addProductToCartByCode(String code) async {
    setState(() => _isLoading = true);
    try {
      final product = await DatabaseService().findProductByBarcodeOrSku(code);
      
      if (product != null) {
        _addToCart(product);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product['name']} added to cart'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product not found'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      if (product['scanned_item_id'] != null) {
        final exists = _cart.any((item) => item['scanned_item_id'] == product['scanned_item_id']);
        if (exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This specific item is already in the cart'), duration: Duration(seconds: 1)),
          );
          return;
        }
        final price = (product['selling_price'] as num).toDouble();
        _cart.add({...product, 'quantity': 1, 'unit_price': price, 'subtotal': price});
      } else {
        final existingIndex = _cart.indexWhere((item) => 
          item['local_id'] == product['local_id'] && 
          item['scanned_item_id'] == null
        );

        if (existingIndex != -1) {
          final currentItem = _cart[existingIndex];
          final newQty = (currentItem['quantity'] as int) + 1;
          final price = currentItem['unit_price'] as double;
          _cart[existingIndex] = {...currentItem, 'quantity': newQty, 'subtotal': newQty * price};
        } else {
          final price = (product['selling_price'] as num).toDouble();
          _cart.add({...product, 'quantity': 1, 'unit_price': price, 'subtotal': price});
        }
      }
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final item = _cart[index];
      final currentQty = item['quantity'] as int;
      final newQty = currentQty + delta;

      if (newQty <= 0) {
        _removeFromCart(index);
      } else {
        final price = item['unit_price'] as double;
        _cart[index] = {
          ...item,
          'quantity': newQty,
          'subtotal': newQty * price,
        };
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  Future<void> _showProductSelectionSheet() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A1B32).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: _ProductSelectionSheet(
                onSelect: (product) {
                  Navigator.pop(context, product);
                },
                initialProducts: _popularProducts,
              ),
            ),
          ),
        ),
      ),
    );

    if (selected != null) {
      _addToCart(selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selected['name']} added to cart'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _showCustomerSelection() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A1B32).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: _CustomerSearchSheet(
                onSelect: (customer) {
                  Navigator.pop(context, customer);
                },
              ),
            ),
          ),
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedCustomer = selected;
      });
    }
  }

  void _showGenerateProformaDialog() {
    double discount = 0.0;
    String note = '';
    final discountController = TextEditingController();
    final noteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final double finalTotal = (_totalAmount - discount).clamp(0.0, double.infinity);

          return AlertDialog(
          backgroundColor: const Color(0xFF0A1B32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Generate Proforma', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text('Total Amount', style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                        _currencyFormat.format(finalTotal),
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                      if (discount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Discount: -${_currencyFormat.format(discount)}',
                            style: GoogleFonts.plusJakartaSans(color: Colors.greenAccent, fontSize: 11),
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
                
                TextField(
                  controller: discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Discount Amount',
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.discount_outlined, color: Colors.white54, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (val) {
                    final d = double.tryParse(val) ?? 0.0;
                    setDialogState(() => discount = d);
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: noteController,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Note / Comment',
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.note_alt_outlined, color: Colors.white54, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (val) {
                    note = val;
                  },
                ),
            ],
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 13)),
            ),
            ElevatedButton(
              onPressed: () {
                  if (discount > _totalAmount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Discount cannot exceed total amount'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                Navigator.pop(context);
                  _generateProforma(discount, note);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4BB4FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text('Generate', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        );

        },
      ),
    );
  }

  Future<void> _generateProforma(double discount, String note) async {
    try {
      // Prepare customer data
      final customerData = {
        'name': _selectedCustomer?['name'] ?? 'Walk-in Customer',
        'phone': _selectedCustomer?['phone'],
      };

      // Prepare items data
      final itemsData = _cart.map((item) => {
        'name': item['name'],
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
        'subtotal': item['subtotal'],
        'product_local_id': item['local_id'],
      }).toList();

      // Calculate final total after discount
      final finalTotal = (_totalAmount - discount).clamp(0.0, double.infinity);

      // Save as proforma invoice
      final proformaData = {
        'customer_data': jsonEncode(customerData),
        'items_data': jsonEncode(itemsData),
        'total_amount': finalTotal,
        'note': note,
        'created_at': DateTime.now().toIso8601String(),
      };

      await DatabaseService().saveProformaInvoice(proformaData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proforma Invoice saved successfully!'), 
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _cart.clear();
          _selectedCustomer = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save proforma invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showQuickAddCustomerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1B32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Quick Add Customer', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (v) => v?.trim().isEmpty ?? true ? 'Name required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone (Optional)',
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                
                try {
                  final db = await DatabaseService().database;
                  final officerRes = await db.query('officer', limit: 1);
                  final dukaRes = await db.query('dukas', limit: 1);
                  
                  final tenantId = officerRes.isNotEmpty ? officerRes.first['tenant_id'] : 1;
                  final dukaId = dukaRes.isNotEmpty ? dukaRes.first['server_id'] : 1;

                  final customer = {
                    'name': name,
                    'phone': phone.isEmpty ? null : phone,
                    'tenant_id': tenantId, 
                    'duka_id': dukaId,
                  };

                  final id = await DatabaseService().createCustomer(customer);
                  final newCustomer = {
                    ...customer,
                    'local_id': id,
                  };
                  
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {
                      _selectedCustomer = newCustomer;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Customer added successfully'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4BB4FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
        title: Text(
          'New Proforma Invoice',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_cart.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4BB4FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF4BB4FF).withOpacity(0.3)),
                ),
                child: Text(
                  '${_totalItems} Items',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF4BB4FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [Color(0xFF1E4976), Color(0xFF0A1B32), Color(0xFF020B18)],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Customer Selection
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: _buildCustomerCard(),
                ),
                
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: _buildActionButton(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Scan',
                        color: const Color(0xFF4BB4FF),
                        onTap: _scanBarcode,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _buildActionButton(
                        icon: Icons.search_rounded,
                        label: 'Browse',
                        color: Colors.purpleAccent,
                        onTap: _showProductSelectionSheet,
                      )),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Cart List
                Expanded(
                  child: _cart.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: _cart.length,
                          itemBuilder: (context, index) {
                            final item = _cart[index];
                            return _buildCartItem(item, index);
                          },
                        ),
                ),
              ],
            ),
          ),
          
          // Bottom Checkout Bar
          if (_cart.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildCheckoutBar(),
            ),
            
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF4BB4FF))),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    return GestureDetector(
      onTap: _showCustomerSelection,
      child: Container(
        padding: const EdgeInsets.all(12),
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
                color: _selectedCustomer != null 
                    ? const Color(0xFF4BB4FF).withOpacity(0.2) 
                    : Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _selectedCustomer != null ? Icons.person_rounded : Icons.person_add_rounded,
                color: _selectedCustomer != null ? const Color(0xFF4BB4FF) : Colors.white54,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Customer',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11),
                      ),
                      if (_selectedCustomer == null)
                        GestureDetector(
                          onTap: _showQuickAddCustomerDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4BB4FF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF4BB4FF).withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_rounded, size: 10, color: Color(0xFF4BB4FF)),
                                const SizedBox(width: 2),
                                Text(
                                  'Quick Add',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF4BB4FF),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedCustomer?['name'] ?? 'Walk-in Customer',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedCustomer != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                onPressed: () => setState(() => _selectedCustomer = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w600, fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_cart_outlined, size: 40, color: Colors.white.withOpacity(0.2)),
          ),
          const SizedBox(height: 12),
          Text(
            'Cart is empty',
            style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            'Scan or browse to add items',
            style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, int index) {
    final image = item['image'] as String?;
    final imageUrl = item['image_url'] as String?;
    final name = item['name'] ?? 'Unknown';

    return Dismissible(
      key: Key('cart_item_$index'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0A1B32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Remove Item", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Text("Are you sure you want to remove '$name' from the cart?", style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text("Remove", style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (_) => _removeFromCart(index),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildProductImage(image, imageUrl, name),
              ),
            ),
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600, fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currencyFormat.format(item['unit_price']),
                    style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _qtyBtn(Icons.remove_rounded, () => _updateQuantity(index, -1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${item['quantity']}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 13,
                          ),
                        ),
                      ),
                      _qtyBtn(Icons.add_rounded, () => _updateQuantity(index, 1)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currencyFormat.format(item['subtotal']),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF4BB4FF),
                    fontWeight: FontWeight.bold, fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }

  Widget _buildProductImage(String? localPath, String? remoteUrl, String name) {
    if (localPath != null && File(localPath).existsSync()) {
      return Image.file(File(localPath), fit: BoxFit.cover);
    } else if (remoteUrl != null && remoteUrl.isNotEmpty) {
      return Image.network(
        remoteUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(name),
      );
    }
    return _buildPlaceholder(name);
  }

  Widget _buildPlaceholder(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white54,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildCheckoutBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1B32).withOpacity(0.85),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total Amount',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currencyFormat.format(_totalAmount),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _showGenerateProformaDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4BB4FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 8,
                  shadowColor: const Color(0xFF4BB4FF).withOpacity(0.4),
                ),
                child: Row(
                  children: [
                    Text(
                      'Generate Proforma',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductSelectionSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSelect;
  final List<Map<String, dynamic>> initialProducts;

  const _ProductSelectionSheet({
    required this.onSelect,
    required this.initialProducts,
  });

  @override
  State<_ProductSelectionSheet> createState() => _ProductSelectionSheetState();
}

class _ProductSelectionSheetState extends State<_ProductSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _lowStockOnly = false;

  @override
  void initState() {
    super.initState();
    _searchResults = List.from(widget.initialProducts);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = List.from(widget.initialProducts);
        _isSearching = false;
      });
    } else {
      _performSearch(query);
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      final results = await DatabaseService().searchProducts(query);
      final enriched = await _enrichProductsWithStock(results);
      if (mounted) {
        setState(() {
          _searchResults = enriched;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _enrichProductsWithStock(List<Map<String, dynamic>> products) async {
    final db = await DatabaseService().database;
    List<Map<String, dynamic>> enriched = [];
    for (var product in products) {
      final localId = product['local_id'] as int;
      final serverId = product['server_id'] as int?;
      int bulkQty = 0;
      List<Map<String, dynamic>> stockList = [];
      if (serverId != null) stockList = await db.query('stocks', where: 'product_id = ?', whereArgs: [serverId]);
      if (stockList.isEmpty) stockList = await db.query('stocks', where: 'product_id = ?', whereArgs: [localId]);
      if (stockList.isNotEmpty) bulkQty = stockList.first['quantity'] as int? ?? 0;
      final itemRes = await db.rawQuery("SELECT COUNT(*) as count FROM product_items WHERE product_id = ? AND status = 'available'", [localId]);
      final int itemQty = itemRes.first['count'] as int? ?? 0;
      enriched.add({...product, 'stock_quantity': bulkQty + itemQty});
    }
    return enriched;
  }

  @override
  Widget build(BuildContext context) {
    final filteredResults = _lowStockOnly
        ? _searchResults.where((p) => (p['stock_quantity'] as int? ?? 0) <= 10).toList()
        : _searchResults;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(
                'Select Products',
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search products...',
              hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Low Stock (≤10)'),
                selected: _lowStockOnly,
                onSelected: (bool selected) {
                  setState(() => _lowStockOnly = selected);
                },
                backgroundColor: Colors.white.withOpacity(0.1),
                selectedColor: Colors.orange.withOpacity(0.2),
                checkmarkColor: Colors.orange,
                labelStyle: GoogleFonts.plusJakartaSans(
                  color: _lowStockOnly ? Colors.orange : Colors.white70,
                  fontSize: 11,
                  fontWeight: _lowStockOnly ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: _lowStockOnly ? Colors.orange : Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),

        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4BB4FF)))
              : filteredResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          Text(
                            'No products found',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredResults.length,
                      itemBuilder: (context, index) {
                        final product = filteredResults[index];
                        return _buildProductItem(product);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildProductItem(Map<String, dynamic> product) {
    final image = product['image'] as String?;
    final imageUrl = product['image_url'] as String?;
    final name = product['name'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _buildProductImage(image, imageUrl, name),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  'SKU: ${product['sku'] ?? 'N/A'} • Stock: ${product['stock_quantity'] ?? 0}',
                  style: GoogleFonts.plusJakartaSans(
                    color: (product['stock_quantity'] as int? ?? 0) <= 10 ? Colors.orange : Colors.white54,
                    fontSize: 11,
                    fontWeight: (product['stock_quantity'] as int? ?? 0) <= 10 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${NumberFormat('#,##0.00', 'en_US').format(product['selling_price'] ?? 0.0)}',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF4BB4FF), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: () => widget.onSelect(product),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4BB4FF).withOpacity(0.2),
                  foregroundColor: const Color(0xFF4BB4FF),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  elevation: 0,
                ),
                child: const Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(String? localPath, String? remoteUrl, String name) {
    if (localPath != null && File(localPath).existsSync()) {
      return Image.file(File(localPath), fit: BoxFit.cover);
    } else if (remoteUrl != null && remoteUrl.isNotEmpty) {
      return Image.network(
        remoteUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(child: Text(name[0], style: const TextStyle(color: Colors.white54))),
      );
    }
    return Center(child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Colors.white54)));
  }
}

class _CustomerSearchSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSelect;
  const _CustomerSearchSheet({required this.onSelect});

  @override
  State<_CustomerSearchSheet> createState() => _CustomerSearchSheetState();
}

class _CustomerSearchSheetState extends State<_CustomerSearchSheet> {
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final customers = await DatabaseService().getAllCustomers();
    if (mounted) {
      setState(() {
        _allCustomers = customers;
        _filteredCustomers = customers;
        _isLoading = false;
      });
    }
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _allCustomers;
      } else {
        _filteredCustomers = _allCustomers.where((c) =>
          (c['name'] ?? '').toString().toLowerCase().contains(query.toLowerCase()) ||
          (c['phone'] ?? '').toString().toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              TextField(
                onChanged: _filter,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search customer...',
                  hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4BB4FF)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _filteredCustomers.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final customer = _filteredCustomers[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF4BB4FF).withOpacity(0.2),
                        child: Text(
                          (customer['name'] as String)[0].toUpperCase(),
                          style: const TextStyle(color: Color(0xFF4BB4FF), fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(customer['name'] ?? 'Unknown', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('Phone: ${customer['phone'] ?? 'N/A'}', style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11)),
                      onTap: () => widget.onSelect(customer),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
