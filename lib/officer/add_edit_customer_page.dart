import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/services/sync_service.dart';

class AddEditCustomerPage extends StatefulWidget {
  final Map<String, dynamic>? customer;

  const AddEditCustomerPage({super.key, this.customer});

  @override
  State<AddEditCustomerPage> createState() => _AddEditCustomerPageState();
}

class _AddEditCustomerPageState extends State<AddEditCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  String _status = 'active';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?['name'] ?? '');
    _emailController = TextEditingController(text: widget.customer?['email'] ?? '');
    _phoneController = TextEditingController(text: widget.customer?['phone'] ?? '');
    _addressController = TextEditingController(text: widget.customer?['address'] ?? '');
    _status = widget.customer?['status'] ?? 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final dbService = DatabaseService();
      final apiService = ApiService();
      final syncService = SyncService();
      final token = await syncService.getAuthToken();

      // Get officer's duka_id if creating new
      int? dukaId;
      if (widget.customer == null) {
        final userData = await dbService.getUserData();
        // Assuming first duka assignment for now, or null if not found
        // In a real app, you might want a dropdown if officer has multiple dukas
        // For now we'll let the backend handle it or send null if not strictly required by local DB
        // But API says "Must be officer's assigned duka".
        // We can try to find it from local 'officer' table
        final officerData = await dbService.database.then((db) => db.query('officer'));
        if (officerData.isNotEmpty) {
           // The officer table has tenant_id, but duka_id might be in assignments or inferred
           // For this implementation, we'll send duka_id if we have it in the customer object (editing)
           // or try to get it from a default source.
           // If we can't find it, we'll omit it and hope backend infers or we'll update logic later.
           // Based on previous code, we used _getDefaultDukaId in SyncService.
           // For simplicity here, we'll proceed without explicit duka_id for new customers 
           // unless we want to query it.
        }
      } else {
        dukaId = widget.customer?['duka_id'];
      }

      final customerData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'status': _status,
        if (dukaId != null) 'duka_id': dukaId,
      };

      bool apiSuccess = false;
      int? newServerId;

      // 1. Try API if online
      if (token != null) {
        try {
          if (widget.customer != null && widget.customer!['server_id'] != null) {
            await apiService.updateCustomer(widget.customer!['server_id'], customerData, token);
            apiSuccess = true;
          } else if (widget.customer == null) {
            // For creation, we might need duka_id. 
            // If API fails due to missing duka_id, user will get feedback.
            // Ideally we fetch a default duka_id here.
            // Let's try to fetch a default duka ID from DB just in case
            final db = await dbService.database;
            final dukas = await db.query('dukas');
            if (dukas.isNotEmpty && !customerData.containsKey('duka_id')) {
               customerData['duka_id'] = dukas.first['server_id'];
            }
            
            final response = await apiService.createCustomer(customerData, token);
            if (response['success'] == true) {
              newServerId = response['data']['customer']['id'];
              apiSuccess = true;
            }
          }
        } catch (e) {
          print('API operation failed: $e');
        }
      }

      // 2. Save Locally
      if (widget.customer != null) {
        await dbService.updateCustomer(widget.customer!['local_id'], {
          ...customerData,
          'sync_status': apiSuccess ? DatabaseService.statusSynced : DatabaseService.statusPending,
        });
      } else {
        final id = await dbService.createCustomer({
          ...customerData,
          'server_id': newServerId,
          'sync_status': apiSuccess ? DatabaseService.statusSynced : DatabaseService.statusPending,
        });
        if (apiSuccess && newServerId != null) {
          await dbService.updateCustomerServerId(id, newServerId);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiSuccess ? 'Customer saved successfully' : 'Saved locally. Will sync when online.'),
            backgroundColor: apiSuccess ? Colors.green : Colors.orange,
          ),
        );
        Navigator.pop(context, true);
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
    final isEditing = widget.customer != null;
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
          isEditing ? 'Edit Customer' : 'New Customer',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField(_nameController, 'Name *', validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
                  const SizedBox(height: 16),
                  _buildTextField(_emailController, 'Email', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildTextField(_phoneController, 'Phone', keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  _buildTextField(_addressController, 'Address', maxLines: 3),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveCustomer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4BB4FF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('Save Customer', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
    );
  }
}