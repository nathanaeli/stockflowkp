import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for clipboard
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/services/sync_service.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/utils/image_utils.dart';
import 'package:stockflowkp/utils/qr_scanner.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _basePriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _skuController = TextEditingController(
    text: 'SKU will be generated automatically...',
  );

  // Stock fields
  final _quantityController = TextEditingController();
  final _batchNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();

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
  String _selectedUnit = 'PCS';
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;

  bool _isActive = true;
  bool _isLoading = false;
  bool _canGenerateSku = false;
  bool _addStock = true;

  // Image & QR
  File? _selectedImage;
  String? _qrCodeData;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_checkSkuGeneration);
    _sellingPriceController.addListener(_checkSkuGeneration);
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.removeListener(_checkSkuGeneration);
    _sellingPriceController.removeListener(_checkSkuGeneration);
    _nameController.dispose();
    _descriptionController.dispose();
    _basePriceController.dispose();
    _sellingPriceController.dispose();
    _skuController.dispose();
    _quantityController.dispose();
    _batchNumberController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final dbService = DatabaseService();
      final userData = await dbService.getUserData();
      if (userData != null) {
        final officerId = userData['data']['user']['id'];
        final categories = await dbService.getCategoriesByOfficer(officerId);
        if (mounted) {
          setState(() => _categories = categories);
        }
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  // Image Methods
  Future<void> _pickImageFromGallery() async {
    final imageFile = await ImageUtils().pickImageFromGallery(context);
    if (imageFile != null) {
      setState(() => _selectedImage = imageFile);
    }
  }

  Future<void> _takePhoto() async {
    final imageFile = await ImageUtils().takePhoto(context);
    if (imageFile != null) {
      setState(() => _selectedImage = imageFile);
    }
  }

  Future<void> _removeImage() async {
    setState(() => _selectedImage = null);
  }

  // QR Scanner
  Future<void> _scanQRCode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              body: QRCodeScanner(
                onQRCodeScanned: (code) {
                  Navigator.pop(context, code);
                },
                initialMessage: 'Scan the product\'s QR/barcode to auto-fill',
              ),
            ),
      ),
    );

    if (result != null && result is String) {
      setState(() => _qrCodeData = result);
    }
  }

  // SKU Generation
  void _checkSkuGeneration() {
    final name = _nameController.text.trim();
    final priceText = _sellingPriceController.text.trim();

    final hasName = name.isNotEmpty;
    final hasValidPrice =
        double.tryParse(priceText.replaceAll(',', '')) != null &&
        double.tryParse(priceText.replaceAll(',', ''))! > 0;

    if (hasName && hasValidPrice) {
      if (!_canGenerateSku) {
        setState(() => _canGenerateSku = true);
      }
      _generateSku();
    } else {
      setState(() => _canGenerateSku = false);
      if (_skuController.text != 'SKU will be generated automatically...') {
        _skuController.text = 'SKU will be generated automatically...';
      }
    }
  }

  void _generateSku() {
    final name = _nameController.text.trim();
    final priceText = _sellingPriceController.text.trim();

    String prefix = 'PROD';
    if (name.isNotEmpty) {
      prefix =
          name
              .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
              .substring(0, name.length >= 4 ? 4 : name.length)
              .toUpperCase();
    }

    String pricePart = '000000';
    final price = double.tryParse(priceText.replaceAll(',', ''));
    if (price != null && price > 0) {
      pricePart = price.toInt().toString().padLeft(6, '0');
    }

    final generatedSku = 'SKU-$prefix-$pricePart';
    if (_skuController.text != generatedSku) {
      _skuController.text = generatedSku;
    }
  }

  // Date Picker
  Future<void> _selectExpiryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4BB4FF),
              onPrimary: Colors.white,
              surface: Color(0xFF0A1B32),
              onSurface: Colors.white,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF0A1B32),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _expiryDateController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  // Save Product
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final syncService = SyncService();
      final token = await syncService.getAuthToken();

      if (token == null) {
        throw Exception('Authentication token not found. Please log in again.');
      }

      final productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'unit': _selectedUnit,
        'buying_price':
            double.tryParse(_basePriceController.text.replaceAll(',', '')) ??
            0.0,
        'selling_price':
            double.tryParse(_sellingPriceController.text.replaceAll(',', '')) ??
            0.0,
        'category_name':
            'General', // Or fetch/select category name correctly. Using 'General' as fallback or from ID if map available.

        'initial_stock':
            _addStock
                ? (int.tryParse(_quantityController.text.trim()) ?? 0)
                : 0,
        'barcode': _qrCodeData,
        'track_items': false, // or add toggle
        'is_active': _isActive ? 1 : 0,
      };

      // Find category name
      if (_selectedCategoryId != null) {
        final cat = _categories.firstWhere(
          (c) => c['server_id'] == _selectedCategoryId,
          orElse: () => {},
        );
        if (cat.isNotEmpty) {
          productData['category_name'] = cat['name'];
        }
      }

      final apiService = ApiService();
      // Call API
      await apiService.addProduct(productData, _selectedImage, token);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Product "${_nameController.text.trim()}" added successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error adding product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add product: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Copy SKU to clipboard
  void _copySkuToClipboard() {
    Clipboard.setData(ClipboardData(text: _skuController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SKU copied to clipboard!'),
        backgroundColor: Colors.blue,
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
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add New Product',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
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
                    'Fill in product details',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 30),

                  _buildTextField(
                    controller: _nameController,
                    label: 'Product Name *',
                    hint: 'e.g. Infinix Hot 30',
                    validator:
                        (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildImageUploadSection(),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description (Optional)',
                    hint: 'Brief description',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),

                  _buildCategoryDropdown(),
                  const SizedBox(height: 20),

                  _buildUnitDropdown(),
                  const SizedBox(height: 30),

                  Text(
                    'Pricing',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _basePriceController,
                    label: 'Base Price (TZS)',
                    hint: 'Cost price (optional)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _sellingPriceController,
                    label: 'Selling Price (TZS) *',
                    hint: 'Retail price',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final cleaned = v?.replaceAll(',', '');
                      if (cleaned == null || cleaned.isEmpty) return 'Required';
                      final price = double.tryParse(cleaned);
                      if (price == null || price <= 0) {
                        return 'Enter valid price > 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),

                  Text(
                    'Initial Stock (Optional)',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildSwitchTile(
                    title: 'Add Initial Stock',
                    subtitle: _addStock ? 'Yes' : 'No',
                    value: _addStock,
                    onChanged: (v) => setState(() => _addStock = v),
                  ),
                  const SizedBox(height: 16),

                  if (_addStock) ...[
                    _buildTextField(
                      controller: _quantityController,
                      label: 'Quantity *',
                      hint: 'e.g. 50',
                      keyboardType: TextInputType.number,
                      validator:
                          (_) =>
                              _addStock &&
                                      (int.tryParse(_quantityController.text) ??
                                              0) <=
                                          0
                                  ? 'Valid quantity required'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _batchNumberController,
                      label: 'Batch Number (Optional)',
                      hint: 'e.g. BATCH-001',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _expiryDateController,
                      label: 'Expiry Date (Optional)',
                      hint: 'Select Date',
                      readOnly: true,
                      onTap: () => _selectExpiryDate(context),
                      suffixIcon: const Icon(
                        Icons.calendar_today,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  _buildSwitchTile(
                    title: 'Product Status',
                    subtitle: _isActive ? 'Active' : 'Inactive',
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  const SizedBox(height: 30),

                  // SKU Display
                  _canGenerateSku
                      ? Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4BB4FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF4BB4FF).withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Color(0xFF4BB4FF),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Generated SKU',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF4BB4FF),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _skuController.text,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.copy,
                                color: Color(0xFF4BB4FF),
                              ),
                              onPressed: _copySkuToClipboard,
                            ),
                          ],
                        ),
                      )
                      : Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.white54,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _skuController.text,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4BB4FF),
                        elevation: 12,
                        shadowColor: const Color(0xFF4BB4FF).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : Text(
                                'Save Product',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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

  // Helper Widgets
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38),
            filled: true,
            suffixIcon: suffixIcon,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4BB4FF), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF4BB4FF),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedCategoryId,
              isExpanded: true,
              hint: Text(
                'Select Category',
                style: GoogleFonts.plusJakartaSans(color: Colors.white38),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white70,
              ),
              dropdownColor: const Color(0xFF0A1B32),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 16,
              ),
              items:
                  _categories
                      .where((c) => c['server_id'] != null)
                      .map(
                        (cat) => DropdownMenuItem<int>(
                          value: cat['server_id'] as int,
                          child: Text(
                            cat['name'] ?? 'Unknown',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (v) => setState(() => _selectedCategoryId = v),
            ),
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
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedUnit,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white70,
              ),
              dropdownColor: const Color(0xFF0A1B32),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 16,
              ),
              items:
                  _units
                      .map(
                        (unit) =>
                            DropdownMenuItem(value: unit, child: Text(unit)),
                      )
                      .toList(),
              onChanged: (v) => setState(() => _selectedUnit = v!),
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
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              // Preview
              _selectedImage != null
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                  : Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.1),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.image_outlined,
                            color: Colors.white54,
                            size: 32,
                          ),
                          Text(
                            'No image selected',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 16),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImageFromGallery,
                      icon: const Icon(Icons.photo_library, size: 20),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt, size: 20),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_selectedImage != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _removeImage,
                        icon: const Icon(Icons.delete, size: 20),
                        label: const Text('Remove'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // QR Scanner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code, color: Color(0xFF4BB4FF)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan QR/Barcode',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF4BB4FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _qrCodeData ?? 'Tap to scan',
                            style: GoogleFonts.plusJakartaSans(
                              color:
                                  _qrCodeData != null
                                      ? Colors.white
                                      : Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        color: Color(0xFF4BB4FF),
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
}
