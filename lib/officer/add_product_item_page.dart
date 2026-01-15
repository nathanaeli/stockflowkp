import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/services/sync_service.dart';
import 'package:stockflowkp/utils/qr_scanner.dart';

class AddProductItemPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const AddProductItemPage({super.key, required this.product});

  @override
  State<AddProductItemPage> createState() => _AddProductItemPageState();
}

class _AddProductItemPageState extends State<AddProductItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _qrController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _productItems = [];

  @override
  void initState() {
    super.initState();
    _loadProductItems(triggerSync: true);
  }

  @override
  void dispose() {
    _qrController.dispose();
    super.dispose();
  }

  Future<void> _loadProductItems({bool triggerSync = false}) async {
    if (mounted) setState(() => _isLoading = true);

    if (triggerSync && widget.product['server_id'] != null) {
      await SyncService().syncProductItemsForProduct(
        widget.product['server_id'] as int,
        widget.product['local_id'] as int,
      );
    }

    try {
      if (!mounted) return;
      final db = await DatabaseService().database;
      final items = await db.query(
        'product_items',
        where: 'product_id = ?',
        whereArgs: [widget.product['local_id']],
        orderBy: 'local_id DESC',
      );
      if (mounted) {
        setState(() {
          _productItems = items;
        });
      }
    } catch (e) {
      debugPrint("Error loading local items: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

  }

  Future<void> _scanQR() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QRCodeScanner(
          onQRCodeScanned: (code) => Navigator.of(context).pop(code),
          initialMessage: 'Scan product item QR code',
        ),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        _qrController.text = result;
      });
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final itemId = await DatabaseService().addProductItem(
        widget.product['local_id'],
        _qrController.text.trim(),
      );

      bool isSynced = false;
      try {
        final syncService = SyncService();
        final token = await syncService.getAuthToken();
        if (token != null) {
          final result = await syncService.syncSpecificProductItem(itemId, token);
          if (result['success'] == true) isSynced = true;
        }
      } catch (e) {
        debugPrint('Auto-sync failed: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isSynced ? 'Product item added and synced' : 'Product item added locally'), backgroundColor: isSynced ? Colors.green : Colors.orange),
        );
        _loadProductItems(); // Refresh the list from local DB
        _qrController.clear(); // Clear the form
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add product item')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    if (item['server_id'] != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete synced items'), backgroundColor: Colors.orange));
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1B32),
        title: Text('Delete Item?', style: GoogleFonts.plusJakartaSans(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete this item? This cannot be undone.',
          style: GoogleFonts.plusJakartaSans(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return;

    final db = await DatabaseService().database;
    await db.delete('product_items', where: 'local_id = ?', whereArgs: [item['local_id']]);
    
    _loadProductItems();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = MediaQuery.sizeOf(context).width < 360 ? 0.9 : 1.0;

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
          'Add Product Item',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 20 * fontScale,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.8,
                colors: [Color(0xFF1E4976), Color(0xFF0C223F), Color(0xFF020B18)],
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
            onRefresh: () => _loadProductItems(triggerSync: true),
            color: const Color(0xFF4BB4FF),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Info Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4BB4FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            color: Color(0xFF4BB4FF),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.product['name'] ?? 'Unnamed Product',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 18 * fontScale,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'SKU: ${widget.product['sku'] ?? 'N/A'}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 14 * fontScale,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
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
                            Icon(
                              Icons.qr_code_2_rounded,
                              color: const Color(0xFF4BB4FF),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'QR Code Entry',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 16 * fontScale,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                                    ),
                                    child: TextFormField(
                                      controller: _qrController,
                                      style: TextStyle(color: Colors.white, fontSize: 15 * fontScale),
                                      decoration: InputDecoration(
                                        hintText: 'Enter or scan QR code',
                                        hintStyle: GoogleFonts.plusJakartaSans(
                                          color: Colors.white54,
                                          fontSize: 15 * fontScale,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'QR code is required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: _scanQR,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4BB4FF), Color(0xFF1E88E5)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4BB4FF).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.qr_code_scanner_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4BB4FF), Color(0xFF1E88E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4BB4FF).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Add Product Item',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 16 * fontScale,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (_productItems.isNotEmpty) ...[
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
                              Icon(
                                Icons.list_alt_rounded,
                                color: const Color(0xFF4BB4FF),
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Existing Items (${_productItems.length})',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 18 * fontScale,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _productItems.length,
                            itemBuilder: (context, index) {
                              final item = _productItems[index];
                              final status = item['status'] ?? 'N/A';
                              final isAvailable = status == 'available';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isAvailable
                                        ? Colors.green.withOpacity(0.3)
                                        : Colors.white.withOpacity(0.15),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isAvailable
                                            ? Colors.green.withOpacity(0.2)
                                            : Colors.grey.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.qr_code_rounded,
                                        color: isAvailable ? Colors.green : Colors.grey,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['qr_code'] ?? 'N/A',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white,
                                              fontSize: 14 * fontScale,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isAvailable
                                                      ? Colors.green.withOpacity(0.2)
                                                      : Colors.grey.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  status.toUpperCase(),
                                                  style: GoogleFonts.plusJakartaSans(
                                                    color: isAvailable ? Colors.green : Colors.grey,
                                                    fontSize: 10 * fontScale,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              if (item['server_id'] == null) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    'LOCAL',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      color: Colors.orange,
                                                      fontSize: 10 * fontScale,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (item['server_id'] == null)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                        onPressed: () => _deleteItem(item),
                                      ),
                                    if (item['server_id'] != null)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: isAvailable ? Colors.green : Colors.grey,
                                        size: 20,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
          ),
          _buildFloatingActionBar(),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF4BB4FF))),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionBar() {
    return Positioned(
      bottom: 30,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _scanQR,
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                    label: Text('Scan', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveItem,
                    icon: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_rounded, color: Colors.white),
                    label: Text(_isLoading ? 'Adding...' : 'Add Item', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4BB4FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 4,
                      shadowColor: const Color(0xFF4BB4FF).withOpacity(0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}