import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/sync_service.dart';
import 'package:stockflowkp/services/database_service.dart';

import 'package:stockflowkp/utils/image_utils.dart';
import 'package:stockflowkp/utils/qr_scanner.dart';

class EditProductPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _basePriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _skuController;

  final List<String> _units = [
    'PCS',
    'KG',
    'LTR',
    'MTR',
    'BOX',
    'PACK',
    'BAG',
    'CAN',
    'BTL',
    'ROLL',
    'SHEET',
    'TUBE',
    'PAIR',
    'SET',
    'DOZEN',
    'BUNDLE',
    'CARTON',
    'CASE',
  ];
  late String _selectedUnit;
  late bool _isActive;
  bool _isLoading = false;

  File? _selectedImage;
  String? _qrCodeData;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.product['name'] ?? '');
    _descriptionController = TextEditingController(
      text: widget.product['description'] ?? '',
    );
    _basePriceController = TextEditingController(
      text: (widget.product['base_price'] ?? 0).toString(),
    );
    _sellingPriceController = TextEditingController(
      text: (widget.product['selling_price'] ?? 0).toString(),
    );
    _skuController = TextEditingController(text: widget.product['sku'] ?? '');

    // Ensure the unit from the product exists in our list, default to 'PCS' if not
    final productUnit =
        widget.product['unit']?.toString().toUpperCase() ?? 'PCS';
    _selectedUnit = _units.contains(productUnit) ? productUnit : 'PCS';

    final rawActive = widget.product['is_active'];
    _isActive =
        rawActive == 1 ||
        rawActive == true ||
        rawActive == '1' ||
        rawActive == 'true';
    _qrCodeData = widget.product['barcode'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _basePriceController.dispose();
    _sellingPriceController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    final imageFile = await ImageUtils().pickImageFromGallery(context);
    if (imageFile != null) {
      setState(() {
        _selectedImage = imageFile;
      });
    }
  }

  Future<void> _takePhoto() async {
    final imageFile = await ImageUtils().takePhoto(context);
    if (imageFile != null) {
      setState(() {
        _selectedImage = imageFile;
      });
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _scanQRCode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => QRCodeScanner(
              onQRCodeScanned: (code) {
                setState(() {
                  _qrCodeData = code;
                });
                Navigator.pop(context);
              },
              initialMessage: 'Scan the product\'s QR code to update',
            ),
      ),
    );
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final syncService = SyncService();
      final token = await syncService.getAuthToken();

      // Resolve Server ID (can be 'id' or 'server_id' depending on source table)
      final int? serverId =
          (widget.product['server_id'] as int?) ??
          (widget.product['id'] as int?);

      // Resolve Local ID for local updates
      final dynamic localId = widget.product['local_id'];

      final Map<String, dynamic> updatedData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'unit': _selectedUnit,
        'buying_price':
            double.tryParse(_basePriceController.text.replaceAll(',', '')) ??
            0.0,
        'selling_price':
            double.tryParse(_sellingPriceController.text.replaceAll(',', '')) ??
            0.0,
        'is_active': _isActive ? 1 : 0,
      };

      if (_qrCodeData != null && _qrCodeData!.isNotEmpty) {
        updatedData['barcode'] = _qrCodeData;
      }

      // 1. UPDATE SERVER (if synced)
      if (serverId != null) {
        if (token == null) {
          throw Exception('Authentication token not found. Please sync first.');
        }
        final apiService = ApiService();
        await apiService.updateProduct(
          serverId,
          updatedData,
          _selectedImage,
          token,
        );
      }

      final dbService = DatabaseService();
      final db = await dbService.database;

      final Map<String, dynamic> localUpdateData = {
        'name': updatedData['name'],
        'description': updatedData['description'],
        'unit': updatedData['unit'],
        'base_price':
            updatedData['buying_price'], // Note: local schema uses base_price
        'selling_price': updatedData['selling_price'],
        'is_active': updatedData['is_active'],
        'barcode': updatedData['barcode'] ?? widget.product['barcode'],
        'updated_at': DateTime.now().toIso8601String(),
        // If image was selected, we might want to save path, but keeping simple for now
        if (_selectedImage != null) 'image': _selectedImage!.path,
      };

      if (localId is int) {
        // Update 'products' table
        // Also set sync_status to synced if we successfully pushed to server,
        // or pending if we didn't (e.g. serverId was null or failed)
        if (serverId != null) {
          localUpdateData['sync_status'] = 1; // Synced
        } else {
          localUpdateData['sync_status'] = 0; // Pending
        }

        await db.update(
          'products',
          localUpdateData,
          where: 'local_id = ?',
          whereArgs: [localId],
        );
      } else if (localId is String) {
        // Update 'productsinfo' table
        await db.update(
          'productsinfo',
          localUpdateData,
          where: 'local_id = ?',
          whereArgs: [localId],
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Product "${_nameController.text.trim()}" updated successfully!',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error updating product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update product: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          'Edit Product',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [Color(0xFF1E4976), Color(0xFF0C223F), Color(0xFF020B18)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'Update product details',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Product Name
                  _buildTextField(
                    controller: _nameController,
                    label: 'Product Name *',
                    hint: 'e.g. Infinix Hot 30',
                    validator:
                        (value) =>
                            value?.trim().isEmpty ?? true
                                ? 'Name is required'
                                : null,
                  ),
                  const SizedBox(height: 20),

                  // Image Upload Section
                  _buildImageUploadSection(),
                  const SizedBox(height: 20),

                  // Description
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description (Optional)',
                    hint: 'Brief description of the product',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),

                  // Unit Dropdown
                  _buildUnitDropdown(),
                  const SizedBox(height: 30),

                  // Pricing Section Header
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4BB4FF),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Pricing',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Base Price
                  _buildTextField(
                    controller: _basePriceController,
                    label: 'Base Price (TZS)',
                    hint: 'Cost price (optional)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),

                  // Selling Price
                  _buildTextField(
                    controller: _sellingPriceController,
                    label: 'Selling Price (TZS) *',
                    hint: 'Retail price',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final cleaned = value?.replaceAll(',', '');
                      if (cleaned == null || cleaned.isEmpty) {
                        return 'Selling price required';
                      }
                      if (double.tryParse(cleaned) == null ||
                          double.tryParse(cleaned)! <= 0) {
                        return 'Enter a valid price > 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),

                  // SKU (Read-only for edit)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tag, color: Colors.white70, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SKU (Read-only)',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _skuController.text,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Active Switch
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Product Status',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              _isActive ? 'Active' : 'Inactive',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: _isActive,
                            onChanged: (val) => setState(() => _isActive = val),
                            activeColor: const Color(0xFF4BB4FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Update Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4BB4FF),
                            const Color(0xFF0277BD),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4BB4FF).withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isLoading ? null : _updateProduct,
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                            child:
                                _isLoading
                                    ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white.withOpacity(0.9),
                                                ),
                                            strokeWidth: 2.0,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Updating...',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    )
                                    : Text(
                                      'Update Product',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: Colors.white30,
              fontSize: 13,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF4BB4FF),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Image (Optional)',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Image Preview with Animation
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child:
                    _selectedImage != null
                        ? Container(
                          key: const ValueKey('selectedImage'),
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                        : widget.product['image'] != null
                        ? Container(
                          key: const ValueKey('existingImage'),
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              File(widget.product['image']),
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => Container(
                                    color: Colors.white.withOpacity(0.06),
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.white54,
                                      size: 36,
                                    ),
                                  ),
                            ),
                          ),
                        )
                        : Container(
                          key: const ValueKey('noImage'),
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(
                              color: Color(0xFF4BB4FF).withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF4BB4FF).withOpacity(0.15),
                                  ),
                                  child: const Icon(
                                    Icons.image_outlined,
                                    color: Color(0xFF4BB4FF),
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No image selected',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap a button below to add',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery Button
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _pickImageFromGallery,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_library,
                                color: const Color(0xFF4BB4FF),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Gallery',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF4BB4FF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Camera Button
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _takePhoto,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                color: Colors.green.withOpacity(0.7),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Camera',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.green.withOpacity(0.7),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Remove Button
                  if (_selectedImage != null || widget.product['image'] != null)
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _removeImage,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete,
                                  color: Colors.red.withOpacity(0.7),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Remove',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.red.withOpacity(0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // QR Code Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.qr_code,
                      color: const Color(0xFF4BB4FF),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan QR Code',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF4BB4FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _qrCodeData != null
                                ? 'Scanned: $_qrCodeData'
                                : 'Tap to scan product QR code',
                            style: GoogleFonts.plusJakartaSans(
                              color:
                                  _qrCodeData != null
                                      ? Colors.white
                                      : Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.qr_code_scanner,
                        color: const Color(0xFF4BB4FF),
                      ),
                      onPressed: _scanQRCode,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnitDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unit *',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedUnit,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
                dropdownColor: const Color(0xFF0A1B32),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                items:
                    _units.map((unit) {
                      return DropdownMenuItem(value: unit, child: Text(unit));
                    }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedUnit = value);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
