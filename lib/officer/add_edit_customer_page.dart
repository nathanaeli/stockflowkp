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
    _nameController = TextEditingController(
      text: widget.customer?['name'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.customer?['email'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.customer?['phone'] ?? '',
    );
    _addressController = TextEditingController(
      text: widget.customer?['address'] ?? '',
    );
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

      // Resolve Duka ID
      // If we are editing, use existing duka_id.
      // If creating, try to find an assigned duka from local DB to attach to the customer.
      int? dukaId = widget.customer?['duka_id'];

      if (widget.customer == null) {
        final db = await dbService.database;
        final dukas = await db.query('dukas');
        if (dukas.isNotEmpty) {
          // Use the first assigned duka's server_id
          dukaId = dukas.first['server_id'] as int?;
        }
      }

      final customerData = {
        'name': _nameController.text.trim(),
        'email':
            _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
        'phone':
            _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
        'address':
            _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
        'status': _status,
        if (dukaId != null) 'duka_id': dukaId,
      };

      bool apiSuccess = false;
      int? newServerId;

      final isOnline = await syncService.hasInternetConnection();

      // 1. Try API if online (Send Direct to Server)
      if (token != null && isOnline) {
        try {
          if (widget.customer != null &&
              widget.customer!['server_id'] != null) {
            // Update existing synced customer
            await apiService.updateCustomer(
              widget.customer!['server_id'],
              customerData,
              token,
            );
            apiSuccess = true;
          } else {
            // Create new customer OR Sync pending customer (exists locally but not on server)
            final response = await apiService.createCustomer(
              customerData,
              token,
            );
            if (response['success'] == true) {
              newServerId = response['data']['customer']['id'];
              apiSuccess = true;
            }
          }
        } catch (e) {
          debugPrint('API operation failed: $e');
        }
      }

      // 2. Save/Update Locally
      if (widget.customer != null) {
        // Updating existing local record
        final updateData = {
          ...customerData,
          'sync_status':
              apiSuccess
                  ? DatabaseService.statusSynced
                  : DatabaseService.statusPending,
        };

        // If we just synced a previously pending customer, update its server_id
        if (newServerId != null) {
          updateData['server_id'] = newServerId;
        }

        await dbService.updateCustomer(
          widget.customer!['local_id'],
          updateData,
        );
      } else {
        // Creating new local record
        final id = await dbService.createCustomer({
          ...customerData,
          'server_id': newServerId,
          'sync_status':
              apiSuccess
                  ? DatabaseService.statusSynced
                  : DatabaseService.statusPending,
        });
        if (apiSuccess && newServerId != null) {
          await dbService.updateCustomerServerId(id, newServerId);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiSuccess
                  ? 'Customer saved successfully'
                  : 'Saved locally. Will sync when online.',
            ),
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Customer' : 'New Customer',
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (widget.customer != null &&
                      (widget.customer!['sync_status'] == 0 ||
                          widget.customer!['sync_status'] ==
                              DatabaseService.statusPending))
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.5),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            color: Colors.orange,
                            size: 28,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Not Synced',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Locally saved. Sync to backend.',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.orange.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _saveCustomer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Sync Now'),
                          ),
                        ],
                      ),
                    ),
                  _buildTextField(
                    _nameController,
                    'Name *',
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _emailController,
                    'Email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _phoneController,
                    'Phone',
                    keyboardType: TextInputType.phone,
                  ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : Text(
                                'Save Customer',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
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

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
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
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
    );
  }
}
