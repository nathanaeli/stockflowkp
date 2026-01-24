import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/services/sync_service.dart';
import 'package:stockflowkp/utils/qr_scanner.dart';

enum ProductSelectionMode { scan, browse, search }

class CreateSalePage extends StatefulWidget {
  final Map<String, dynamic>? proformaInvoice;
  final Map<String, dynamic>? editSale; // New parameter
  final VoidCallback? onSaleCreated;

  const CreateSalePage({
    super.key,
    this.proformaInvoice,
    this.editSale,
    this.onSaleCreated,
  });

  @override
  State<CreateSalePage> createState() => _CreateSalePageState();
}

class _CreateSalePageState extends State<CreateSalePage> {
  final List<Map<String, dynamic>> _cart = [];
  bool _isLoading = false;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  bool _isLoan = false;
  Map<String, dynamic>? _selectedCustomer;
  String _initialNote = '';

  // Search and browsing state
  List<Map<String, dynamic>> _popularProducts = [];

  double get _totalAmount =>
      _cart.fold(0, (sum, item) => sum + (item['subtotal'] as double));
  int get _totalItems =>
      _cart.fold(0, (sum, item) => sum + (item['quantity'] as int));

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    if (widget.proformaInvoice != null) {
      _loadProformaData();
    } else if (widget.editSale != null) {
      _loadEditData();
    }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadProformaData() {
    try {
      final invoice = widget.proformaInvoice!;

      // Load Customer
      if (invoice['customer_data'] != null) {
        setState(() {
          _selectedCustomer = jsonDecode(invoice['customer_data']);
        });
      }

      // Load Items
      if (invoice['items_data'] != null) {
        final rawItems =
            (jsonDecode(invoice['items_data']) as List)
                .cast<Map<String, dynamic>>();
        // Map product_local_id back to local_id for compatibility with sale logic
        final items =
            rawItems.map((item) {
              if (!item.containsKey('local_id') &&
                  item.containsKey('product_local_id')) {
                return {...item, 'local_id': item['product_local_id']};
              }
              return item;
            }).toList();

        setState(() {
          _cart.addAll(items);
        });
      }

      // Load Note
      if (invoice['note'] != null) {
        _initialNote = invoice['note'];
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Proforma invoice loaded'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('Error loading proforma: $e');
    }
  }

  void _loadEditData() {
    try {
      final sale = widget.editSale!;

      // Load Customer
      if (sale['customer_id'] != null || sale['customer_name'] != null) {
        // Construct basic customer map if full details aren't directly available in sale object,
        // or rely on what's passed. Ideally, we fetch full customer if needed.
        setState(() {
          _selectedCustomer = {
            'server_id': sale['customer_id'], // Might differ based on key
            'name': sale['customer_name'] ?? 'Unknown Customer',
            // Add other fields if available or fetch
          };
        });
      }

      // Load Items
      if (sale['items'] != null) {
        final itemsList = sale['items'] as List;
        final mappedItems =
            itemsList.map((item) {
              // Map structure to match _cart item structure
              return {
                'local_id':
                    item['product_local_id'] ??
                    item['product_id'], // Adjust based on DB structure
                'server_id': item['product_id'],
                'name': item['product_name'] ?? 'Item',
                'quantity': item['quantity'],
                'unit_price': (item['unit_price'] as num).toDouble(),
                'subtotal':
                    (item['quantity'] as num) *
                    (item['unit_price'] as num).toDouble(),
                // Add scanned_item_id if pertinent for tracked items
              };
            }).toList();

        setState(() {
          _cart.addAll(mappedItems.cast<Map<String, dynamic>>());
        });
      }

      // Load other fields
      if (sale['discount_amount'] != null) {
        // Handle prepopulating discount in checkout dialog logically if needed
      }
      if (sale['is_loan'] == 1 || sale['is_loan'] == true) {
        _isLoan = true;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Editing mode: Sale data loaded'),
              backgroundColor: Colors.blueAccent,
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('Error loading edit data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _enrichProductsWithStock(
    List<Map<String, dynamic>> products,
  ) async {
    final db = await DatabaseService().database;
    List<Map<String, dynamic>> enriched = [];

    for (var product in products) {
      final localId = product['local_id'] as int;
      final serverId = product['server_id'] as int?;

      int bulkQty = 0;
      List<Map<String, dynamic>> stockList = [];

      if (serverId != null) {
        stockList = await db.query(
          'stocks',
          where: 'product_id = ?',
          whereArgs: [serverId],
        );
      }
      if (stockList.isEmpty) {
        stockList = await db.query(
          'stocks',
          where: 'product_id = ?',
          whereArgs: [localId],
        );
      }
      if (stockList.isNotEmpty) {
        bulkQty = stockList.first['quantity'] as int? ?? 0;
      }

      final itemRes = await db.rawQuery(
        "SELECT COUNT(*) as count FROM product_items WHERE product_id = ? AND status = 'available'",
        [localId],
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
        builder:
            (context) => QRCodeScanner(
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
        // If a specific item was scanned, check its status before adding to cart
        if (product['scanned_item_id'] != null &&
            product['scanned_item_status'] != 'available') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Item not available. Status: ${product['scanned_item_status']}.',
                ),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return; // Do not add to cart
        }

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
      // 1. Check if this is a specific item (serialized/scanned QR)
      if (product['scanned_item_id'] != null) {
        // First check if this exact item is already in cart
        final exists = _cart.any(
          (item) => item['scanned_item_id'] == product['scanned_item_id'],
        );
        if (exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This specific item is already in the cart'),
              duration: Duration(seconds: 1),
            ),
          );
          return;
        }

        // NEW LOGIC: Check if this scanned item belongs to a product type already in cart
        // If so, increment the quantity instead of adding a separate entry
        final existingProductIndex = _cart.indexWhere(
          (item) => item['local_id'] == product['local_id'],
        );

        if (existingProductIndex != -1) {
          // Product already exists in cart - increment quantity
          final currentItem = _cart[existingProductIndex];
          final newQty = (currentItem['quantity'] as int) + 1;
          final price = currentItem['unit_price'] as double;
          _cart[existingProductIndex] = {
            ...currentItem,
            'quantity': newQty,
            'subtotal': newQty * price,
          };

          // Show feedback message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product['name']} quantity updated to $newQty'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          // New product type - add as new entry
          final price = (product['selling_price'] as num).toDouble();
          _cart.add({
            ...product,
            'quantity': 1,
            'unit_price': price,
            'subtotal': price,
          });
        }
      } else {
        // 2. Bulk item (no specific scanned item) - Group it
        final existingIndex = _cart.indexWhere(
          (item) =>
              item['local_id'] == product['local_id'] &&
              item['scanned_item_id'] == null,
        );

        if (existingIndex != -1) {
          final currentItem = _cart[existingIndex];
          final newQty = (currentItem['quantity'] as int) + 1;
          final price = currentItem['unit_price'] as double;
          _cart[existingIndex] = {
            ...currentItem,
            'quantity': newQty,
            'subtotal': newQty * price,
          };
        } else {
          final price = (product['selling_price'] as num).toDouble();
          _cart.add({
            ...product,
            'quantity': 1,
            'unit_price': price,
            'subtotal': price,
          });
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

  Future<void> _saveCartAsDraft() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save empty cart as draft'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? note;
    final noteController = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF0A1B32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Save Draft',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter a note to identify this draft (optional):',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g., Pending payment',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4BB4FF),
                ),
                child: Text(
                  'Save',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );

    if (shouldSave == true) {
      note = noteController.text.trim();
      final draft = {
        'customer_data':
            _selectedCustomer != null ? jsonEncode(_selectedCustomer) : null,
        'items_data': jsonEncode(_cart),
        'total_amount': _totalAmount,
        'note': note.isNotEmpty ? note : null,
        'created_at': DateTime.now().toIso8601String(),
      };

      await DatabaseService().saveCartDraft(draft);

      setState(() {
        _cart.clear();
        _selectedCustomer = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showDraftsDialog() async {
    final drafts = await DatabaseService().getCartDrafts();

    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF0A1B32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Saved Drafts',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content:
                drafts.isEmpty
                    ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No saved drafts found.',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                        ),
                      ),
                    )
                    : SizedBox(
                      width: double.maxFinite,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: drafts.length,
                        separatorBuilder:
                            (_, __) => const Divider(color: Colors.white10),
                        itemBuilder: (context, index) {
                          final draft = drafts[index];
                          final date = DateTime.parse(draft['created_at']);
                          final formattedDate = DateFormat(
                            'MMM d, h:mm a',
                          ).format(date);
                          final items =
                              (jsonDecode(draft['items_data']) as List).length;
                          final total = draft['total_amount'] as double;
                          final note = draft['note'] as String?;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              note ?? 'Draft #${draft['id']}',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '$items items • ${_currencyFormat.format(total)}\n$formattedDate',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () async {
                                await DatabaseService().deleteCartDraft(
                                  draft['id'],
                                );
                                Navigator.pop(context);
                                _showDraftsDialog(); // Refresh
                              },
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _loadDraft(draft);
                            },
                          );
                        },
                      ),
                    ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _loadDraft(Map<String, dynamic> draft) async {
    if (_cart.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: const Color(0xFF0A1B32),
              title: Text(
                'Overwrite Cart?',
                style: GoogleFonts.plusJakartaSans(color: Colors.white),
              ),
              content: Text(
                'Loading this draft will replace your current cart items.',
                style: GoogleFonts.plusJakartaSans(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Overwrite',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
      );
      if (confirm != true) return;
    }

    setState(() {
      _cart.clear();
      final items =
          (jsonDecode(draft['items_data']) as List)
              .cast<Map<String, dynamic>>();
      _cart.addAll(items);

      if (draft['customer_data'] != null) {
        _selectedCustomer = jsonDecode(draft['customer_data']);
      } else {
        _selectedCustomer = null;
      }
    });

    await DatabaseService().deleteCartDraft(draft['id']);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft loaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showProductSelectionSheet() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (_, controller) => Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1B32).withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
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
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (_, controller) => Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1B32).withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
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

  DateTime? _selectedDate;

  void _showCheckoutDialog() {
    _isLoan = false;
    _selectedDate = null;
    double discount = 0.0;
    String note = _initialNote;
    final discountController = TextEditingController();
    final noteController = TextEditingController(text: _initialNote);

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              final double finalTotal = (_totalAmount - discount).clamp(
                0.0,
                double.infinity,
              );

              return AlertDialog(
                backgroundColor: const Color(0xFF0A1B32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  'Confirm Checkout',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
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
                            Text(
                              'Total Amount',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currencyFormat.format(finalTotal),
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (discount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Discount: -${_currencyFormat.format(discount)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.greenAccent,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Date Picker
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.transparent),
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.calendar_today,
                            color: Colors.white54,
                            size: 20,
                          ),
                          title: Text(
                            _selectedDate == null
                                ? 'Select Date (Default: Now)'
                                : DateFormat(
                                  'MMM d, yyyy - h:mm a',
                                ).format(_selectedDate!),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              // ignore: use_build_context_synchronously
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(
                                  _selectedDate ?? DateTime.now(),
                                ),
                              );
                              if (time != null) {
                                setDialogState(() {
                                  _selectedDate = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              }
                            }
                          },
                        ),
                      ),

                      // Discount Field
                      TextField(
                        controller: discountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Discount Amount',
                          labelStyle: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.discount_outlined,
                            color: Colors.white54,
                            size: 18,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (val) {
                          final d = double.tryParse(val) ?? 0.0;
                          setDialogState(() => discount = d);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Note Field
                      TextField(
                        controller: noteController,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Sale Note / Comment',
                          labelStyle: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.note_alt_outlined,
                            color: Colors.white54,
                            size: 18,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (val) {
                          note = val;
                        },
                      ),
                      const SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color:
                              _isLoan
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                _isLoan
                                    ? Colors.orange.withOpacity(0.5)
                                    : Colors.transparent,
                          ),
                        ),
                        child: CheckboxListTile(
                          title: Text(
                            'Mark as Loan',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          subtitle:
                              _isLoan
                                  ? Text(
                                    'Payment pending',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.orange,
                                      fontSize: 11,
                                    ),
                                  )
                                  : null,
                          value: _isLoan,
                          onChanged: (val) {
                            setDialogState(() => _isLoan = val ?? false);
                          },
                          activeColor: Colors.orange,
                          checkColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (discount > _totalAmount) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Discount cannot exceed total amount',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context);
                      _processCheckout(
                        discount,
                        note,
                        customDate: _selectedDate,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4BB4FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      'Confirm Sale',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _processCheckout(
    double discount,
    String note, {
    DateTime? customDate,
  }) async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseService().database;

      final officerRes = await db.query('officer', limit: 1);
      final dukaRes = await db.query('dukas', limit: 1);

      final tenantId =
          officerRes.isNotEmpty ? officerRes.first['tenant_id'] : null;
      final dukaId = dukaRes.isNotEmpty ? dukaRes.first['server_id'] : null;
      final customerId =
          _selectedCustomer?['server_id'] ?? _selectedCustomer?['local_id'];

      final finalTotal = (_totalAmount - discount).clamp(0.0, double.infinity);

      final saleData = {
        'created_at': (customDate ?? DateTime.now()).toIso8601String(),
        'tenant_id': tenantId,
        'duka_id': dukaId,
        'customer_id': customerId,
        'total_amount': finalTotal,
        'discount_amount': discount,
        'discount_reason': note.isEmpty ? null : note,
        'profit_loss': 0.0,
        'is_loan': _isLoan ? 1 : 0,
        'due_date':
            _isLoan
                ? DateTime.now().add(const Duration(days: 30)).toIso8601String()
                : null,
        'payment_status': _isLoan ? 'pending' : 'paid',
        'total_payments': _isLoan ? 0.0 : finalTotal,
        'remaining_balance': _isLoan ? finalTotal : 0.0,
        'items':
            _cart
                .map(
                  (item) => {
                    'product_local_id': item['local_id'],
                    'product_item_local_id': item['scanned_item_id'],
                    'quantity': item['quantity'],
                    'unit_price': item['unit_price'],
                  },
                )
                .toList(),
      };

      final saleId = await DatabaseService().createSale(saleData);

      // If this was a proforma conversion, delete the proforma invoice
      if (widget.proformaInvoice != null &&
          widget.proformaInvoice!['id'] != null) {
        await DatabaseService().deleteProformaInvoice(
          widget.proformaInvoice!['id'],
        );
      }

      // Attempt immediate sync
      bool isSynced = false;
      try {
        final syncService = SyncService();
        final token = await syncService.getAuthToken();
        if (token != null) {
          final result = await syncService.syncSpecificSale(saleId, token);
          if (result['success'] == true) {
            isSynced = true;
          }
        }
      } catch (e) {
        debugPrint('Auto-sync failed: $e');
      }

      if (mounted) {
        if (widget.editSale == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sale completed!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        setState(() {
          _cart.clear();
          _isLoan = false;
          _selectedCustomer = null;
        });

        // Pass back true to indicate success/refresh needed
        if (widget.editSale != null) {
          Navigator.pop(context, true);
        } else {
          widget.onSaleCreated?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showQuickAddCustomerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF0A1B32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Quick Add Customer',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                      labelStyle: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator:
                        (v) =>
                            v?.trim().isEmpty ?? true ? 'Name required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone (Optional)',
                      labelStyle: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                ),
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

                      final tenantId =
                          officerRes.isNotEmpty
                              ? officerRes.first['tenant_id']
                              : 1;
                      final dukaId =
                          dukaRes.isNotEmpty ? dukaRes.first['server_id'] : 1;

                      final customer = {
                        'name': name,
                        'phone': phone.isEmpty ? null : phone,
                        'tenant_id': tenantId,
                        'duka_id': dukaId,
                      };

                      final id = await DatabaseService().createCustomer(
                        customer,
                      );
                      final newCustomer = {...customer, 'local_id': id};

                      if (mounted) {
                        Navigator.pop(context);
                        setState(() {
                          _selectedCustomer = newCustomer;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Customer added successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4BB4FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Sale',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4BB4FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF4BB4FF).withOpacity(0.3),
                  ),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: const Color(0xFF0A1B32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'save') _saveCartAsDraft();
              if (value == 'load') _showDraftsDialog();
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'save',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.save_as_outlined,
                          color: Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Save Draft',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'load',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.restore_page_outlined,
                          color: Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Load Drafts',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                colors: [
                  Color(0xFF1E4976),
                  Color(0xFF0A1B32),
                  Color(0xFF020B18),
                ],
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
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'Scan',
                          color: const Color(0xFF4BB4FF),
                          onTap: _scanBarcode,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.search_rounded,
                          label: 'Browse',
                          color: Colors.purpleAccent,
                          onTap: _showProductSelectionSheet,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Cart List
                Expanded(
                  child:
                      _cart.isEmpty
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
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF4BB4FF)),
              ),
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
                color:
                    _selectedCustomer != null
                        ? const Color(0xFF4BB4FF).withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _selectedCustomer != null
                    ? Icons.person_rounded
                    : Icons.person_add_rounded,
                color:
                    _selectedCustomer != null
                        ? const Color(0xFF4BB4FF)
                        : Colors.white54,
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
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      if (_selectedCustomer == null)
                        GestureDetector(
                          onTap: _showQuickAddCustomerDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4BB4FF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF4BB4FF).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.add_rounded,
                                  size: 10,
                                  color: Color(0xFF4BB4FF),
                                ),
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
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white54,
                  size: 18,
                ),
                onPressed: () => setState(() => _selectedCustomer = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white24,
                  size: 14,
                ),
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
                fontWeight: FontWeight.w600,
                fontSize: 13,
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
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 40,
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Cart is empty',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Scan or browse to add items',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 12,
            ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                "Remove Item",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                "Are you sure you want to remove '$name' from the cart?",
                style: GoogleFonts.plusJakartaSans(color: Colors.white70),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    "Remove",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
            // Product Image
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

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currencyFormat.format(item['unit_price']),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Quantity Controls
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _qtyBtn(
                        Icons.remove_rounded,
                        () => _updateQuantity(index, -1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${item['quantity']}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      _qtyBtn(
                        Icons.add_rounded,
                        () => _updateQuantity(index, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currencyFormat.format(item['subtotal']),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF4BB4FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
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
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
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
                onPressed: _showCheckoutDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4BB4FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0xFF4BB4FF).withOpacity(0.4),
                ),
                child: Row(
                  children: [
                    Text(
                      'Checkout',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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

  Future<List<Map<String, dynamic>>> _enrichProductsWithStock(
    List<Map<String, dynamic>> products,
  ) async {
    final db = await DatabaseService().database;
    List<Map<String, dynamic>> enriched = [];
    for (var product in products) {
      final localId = product['local_id'] as int;
      final serverId = product['server_id'] as int?;
      int bulkQty = 0;
      List<Map<String, dynamic>> stockList = [];
      if (serverId != null)
        stockList = await db.query(
          'stocks',
          where: 'product_id = ?',
          whereArgs: [serverId],
        );
      if (stockList.isEmpty)
        stockList = await db.query(
          'stocks',
          where: 'product_id = ?',
          whereArgs: [localId],
        );
      if (stockList.isNotEmpty)
        bulkQty = stockList.first['quantity'] as int? ?? 0;
      final itemRes = await db.rawQuery(
        "SELECT COUNT(*) as count FROM product_items WHERE product_id = ? AND status = 'available'",
        [localId],
      );
      final int itemQty = itemRes.first['count'] as int? ?? 0;
      enriched.add({...product, 'stock_quantity': bulkQty + itemQty});
    }
    return enriched;
  }

  @override
  Widget build(BuildContext context) {
    final filteredResults =
        _lowStockOnly
            ? _searchResults
                .where((p) => (p['stock_quantity'] as int? ?? 0) <= 10)
                .toList()
            : _searchResults;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Products',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Filter Chips
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
                  fontWeight:
                      _lowStockOnly ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color:
                        _lowStockOnly
                            ? Colors.orange
                            : Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child:
              _isSearching
                  ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4BB4FF)),
                  )
                  : filteredResults.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 48,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products found',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                          ),
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
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'SKU: ${product['sku'] ?? 'N/A'} • Stock: ${product['stock_quantity'] ?? 0}',
                  style: GoogleFonts.plusJakartaSans(
                    color:
                        (product['stock_quantity'] as int? ?? 0) <= 10
                            ? Colors.orange
                            : Colors.white54,
                    fontSize: 11,
                    fontWeight:
                        (product['stock_quantity'] as int? ?? 0) <= 10
                            ? FontWeight.bold
                            : FontWeight.normal,
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
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF4BB4FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: () => widget.onSelect(product),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4BB4FF).withOpacity(0.2),
                  foregroundColor: const Color(0xFF4BB4FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: Size.zero,
                  elevation: 0,
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
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
        errorBuilder:
            (_, __, ___) => Center(
              child: Text(
                name[0],
                style: const TextStyle(color: Colors.white54),
              ),
            ),
      );
    }
    return Center(
      child: Text(
        name.isNotEmpty ? name[0] : '?',
        style: const TextStyle(color: Colors.white54),
      ),
    );
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
        _filteredCustomers =
            _allCustomers
                .where(
                  (c) =>
                      (c['name'] ?? '').toString().toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      (c['phone'] ?? '').toString().toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                )
                .toList();
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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: _filter,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search customer...',
                  hintStyle: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4BB4FF)),
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _filteredCustomers.length,
                    separatorBuilder:
                        (_, __) =>
                            const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final customer = _filteredCustomers[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: const Color(
                            0xFF4BB4FF,
                          ).withOpacity(0.2),
                          child: Text(
                            (customer['name'] as String)[0].toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF4BB4FF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          customer['name'] ?? 'Unknown',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Phone: ${customer['phone'] ?? 'N/A'}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                        onTap: () => widget.onSelect(customer),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
