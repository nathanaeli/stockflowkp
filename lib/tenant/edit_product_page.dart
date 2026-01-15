import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

class EditProductPage extends StatefulWidget {
  final Map<String, dynamic> productData;

  const EditProductPage({Key? key, required this.productData}) : super(key: key);

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _descriptionController;
  late TextEditingController _basePriceController;
  late TextEditingController _sellingPriceController;
  
  bool _isLoading = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final basic = widget.productData['basic_info'] ?? {};
    final pricing = widget.productData['pricing'] ?? {};

    _nameController = TextEditingController(text: basic['name']);
    _skuController = TextEditingController(text: basic['sku']);
    _descriptionController = TextEditingController(text: basic['description']);
    _basePriceController = TextEditingController(text: pricing['base_price']?.toString());
    _sellingPriceController = TextEditingController(text: pricing['selling_price']?.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _descriptionController.dispose();
    _basePriceController.dispose();
    _sellingPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final basePrice = double.tryParse(_basePriceController.text) ?? 0;
    final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0;

    if (sellingPrice < basePrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selling price cannot be lower than cost price'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dbService = DatabaseService();
      final userData = await dbService.getUserData();
      if (userData == null) throw Exception('User data not found');

      final token = userData['data']['token'];
      final apiService = ApiService();
      final productId = widget.productData['basic_info']['id'];

      final Map<String, dynamic> updateData = {
        'name': _nameController.text,
        'sku': _skuController.text,
        'description': _descriptionController.text,
        'base_price': _basePriceController.text,
        'selling_price': _sellingPriceController.text,
        // Add other fields as needed, e.g., duka_id, category_id if editable
      };

      final response = await apiService.updateTenantProduct(
        productId,
        updateData,
        token,
        imagePath: _selectedImage?.path,
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product updated successfully'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true); // Return true to indicate refresh needed
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1B32),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Product', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProduct,
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF4BB4FF), strokeWidth: 2))
              : Text('Save', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF4BB4FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [Color(0xFF1E4976), Color(0xFF0A1B32), Color(0xFF020B18)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                        image: _selectedImage != null
                            ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                            : (widget.productData['basic_info']['image_url'] != null
                                ? DecorationImage(image: NetworkImage(widget.productData['basic_info']['image_url']), fit: BoxFit.cover)
                                : null),
                      ),
                      child: _selectedImage == null && widget.productData['basic_info']['image_url'] == null
                          ? const Icon(Icons.add_a_photo_rounded, color: Colors.white54, size: 40)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: Text('Tap to change image', style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12))),
                const SizedBox(height: 24),
                
                _buildTextField('Product Name', _nameController, Icons.inventory_2_rounded),
                const SizedBox(height: 16),
                _buildTextField('SKU', _skuController, Icons.qr_code_rounded),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Cost Price', _basePriceController, Icons.attach_money_rounded, isNumber: true)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Selling Price', _sellingPriceController, Icons.sell_rounded, isNumber: true)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField('Description', _descriptionController, Icons.description_rounded, maxLines: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          maxLines: maxLines,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
          validator: (value) => value == null || value.isEmpty ? '$label is required' : null,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ).inputDecoration().copyWith(
            prefixIcon: Icon(icon, color: Colors.white54, size: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}

extension InputDecorationExtension on BoxDecoration {
  InputDecoration inputDecoration() {
    final radius = borderRadius is BorderRadius 
        ? borderRadius as BorderRadius 
        : BorderRadius.zero;
    final side = border is Border ? (border as Border).top : BorderSide.none;

    return InputDecoration(
      filled: true,
      fillColor: color ?? Colors.transparent,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: side,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: side,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Color(0xFF4BB4FF), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}