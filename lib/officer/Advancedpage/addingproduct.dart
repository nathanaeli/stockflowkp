import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/sync_service.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for the API fields
  final _nameController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descController = TextEditingController();

  File? _selectedImage;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;

  // Units
  List<String> _units = [
    'PCS',
    'BOX',
    'KG',
    'PACK',
    'DOZEN',
    'PAIR',
    'METER',
    'LITRE',
    'SET',
  ];
  String? _selectedUnit = 'PCS';

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final prefs = await SharedPreferences.getInstance();
    final customUnits = prefs.getStringList('custom_units') ?? [];
    setState(() {
      _units =
          <String>{..._units, ...customUnits}.toList(); // Remove duplicates
      // Ensure selected is in list
      if (!_units.contains(_selectedUnit)) {
        _selectedUnit = _units.first;
      }
    });
  }

  Future<void> _loadCategories() async {
    final db = await DatabaseService().database;
    final cats = await db.query('categories');
    setState(() {
      _categories = cats;
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  void _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final token = await SyncService().getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated. Please login again.');
      }

      final productData = {
        'name': _nameController.text,
        'category_id': _selectedCategoryId,
        'base_price': _buyPriceController.text,
        'selling_price': _sellPriceController.text,
        'initial_stock': _stockController.text,
        'unit': _selectedUnit ?? 'PCS',
        'description': _descController.text,
      };

      await ApiService().addProduct(productData, _selectedImage, token);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product & FIFO Stock Initialized!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to trigger refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll("Exception: ", "")}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showAddUnitDialog() async {
    final TextEditingController unitController = TextEditingController();
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF0A1B32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            title: Text(
              'Add New Unit',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: unitController,
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Unit Name (e.g. SACK)',
                hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
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
                  final name = unitController.text.trim().toUpperCase();
                  if (name.isNotEmpty) {
                    final prefs = await SharedPreferences.getInstance();
                    final customUnits =
                        prefs.getStringList('custom_units') ?? [];
                    if (!customUnits.contains(name)) {
                      customUnits.add(name);
                      await prefs.setStringList('custom_units', customUnits);
                      setState(() {
                        if (!_units.contains(name)) {
                          _units.add(name);
                        }
                        _selectedUnit = name;
                      });
                    }
                    if (mounted) Navigator.pop(context);
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
        title: Text(
          'Register New Product',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: const Color(0xFF0A1B32).withOpacity(0.5)),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1B32), Color(0xFF0D2544)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImagePicker(),
                const SizedBox(height: 24),
                _buildGlassTextField(
                  'Product Name',
                  _nameController,
                  Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 16),
                _buildGlassDropdown(
                  'Category',
                  Icons.category_outlined,
                  _categories,
                  (val) => setState(() => _selectedCategoryId = val),
                  _selectedCategoryId,
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildGlassStringDropdown(
                        'Unit',
                        Icons.straighten_outlined,
                        _units,
                        (val) => setState(() => _selectedUnit = val),
                        _selectedUnit,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4BB4FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF4BB4FF).withOpacity(0.3),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Color(0xFF4BB4FF),
                        ),
                        onPressed: _showAddUnitDialog,
                        tooltip: 'Add Unit',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildGlassPriceField(
                        'Buying Price',
                        _buyPriceController,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildGlassPriceField(
                        'Selling Price',
                        _sellPriceController,
                        isSelling: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGlassTextField(
                  'Initial Stock (FIFO Batch)',
                  _stockController,
                  Icons.layers_outlined,
                  isNumeric: true,
                ),
                const SizedBox(height: 16),
                _buildGlassTextField(
                  'Description (Optional)',
                  _descController,
                  Icons.description_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 32),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassDropdown(
    String label,
    IconData icon,
    List<Map<String, dynamic>> items,
    Function(int?) onChanged,
    int? value,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DropdownButtonFormField<int>(
          value: value,
          dropdownColor: const Color(0xFF0A1B32),
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white70),
            prefixIcon: Icon(icon, size: 20, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
            ),
          ),
          items:
              items.map((item) {
                // Determine ID (prefer server_id, fallback to local_id)
                final id = item['server_id'] as int? ?? item['local_id'] as int;
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(item['name'] ?? 'Unknown'),
                );
              }).toList(),
          onChanged: onChanged,
          validator: (v) => null, // Optional
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child:
              _selectedImage != null
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                  )
                  : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 40,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add Image',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildGlassTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumeric = false,
    int maxLines = 1,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white70),
            prefixIcon: Icon(icon, size: 20, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
            ),
          ),
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
      ),
    );
  }

  Widget _buildGlassPriceField(
    String label,
    TextEditingController controller, {
    bool isSelling = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white70),
            prefixText: 'TZS ',
            prefixStyle: GoogleFonts.plusJakartaSans(color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
            ),
          ),
          validator: (v) {
            if (v!.isEmpty) return 'Required';
            if (isSelling) {
              double buy = double.tryParse(_buyPriceController.text) ?? 0;
              double sell = double.tryParse(v) ?? 0;
              if (sell < buy) return 'Loss alert!';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF4BB4FF), Color(0xFF0277BD)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4BB4FF).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitData,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child:
              _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                    'Save Product & Initialize FIFO',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _buildGlassStringDropdown(
    String label,
    IconData icon,
    List<String> items,
    Function(String?) onChanged,
    String? value,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DropdownButtonFormField<String>(
          value: value,
          dropdownColor: const Color(0xFF0A1B32),
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white70),
            prefixIcon: Icon(icon, size: 20, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
            ),
          ),
          items:
              items.map((item) {
                return DropdownMenuItem<String>(value: item, child: Text(item));
              }).toList(),
          onChanged: onChanged,
          validator: (v) => null, // Optional
        ),
      ),
    );
  }
}
