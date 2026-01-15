import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:url_launcher/url_launcher.dart';

class TenantInfoPage extends StatefulWidget {
  const TenantInfoPage({super.key});

  @override
  State<TenantInfoPage> createState() => _TenantInfoPageState();
}

class _TenantInfoPageState extends State<TenantInfoPage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _tenantData;
  bool _isLoading = true;
  bool _isEditMode = false;
  bool _isSaving = false;
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _websiteController = TextEditingController();
  final _currencyController = TextEditingController();
  
  String _selectedTimezone = 'Africa/Nairobi';
  final List<String> _timezones = [
    'Africa/Nairobi',
    'Africa/Dar_es_Salaam',
    'Africa/Kampala',
    'Africa/Kigali',
    'Africa/Addis_Ababa',
    'Africa/Cairo',
    'Africa/Johannesburg',
    'Africa/Lagos',
    'UTC',
  ];
  
  File? _selectedLogo;
  final ImagePicker _imagePicker = ImagePicker();

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _loadTenantData();
    _controller.forward();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _currencyController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadTenantData() async {
    final dbService = DatabaseService();
    final tenantAccount = await dbService.getTenantAccount();
    
    if (mounted) {
      setState(() {
        _tenantData = tenantAccount;
        _isLoading = false;
        
        // Initialize form controllers with existing data
        if (tenantAccount != null) {
          _companyNameController.text = tenantAccount['company_name'] ?? '';
          _descriptionController.text = tenantAccount['description'] ?? '';
          _phoneController.text = tenantAccount['phone'] ?? '';
          _emailController.text = tenantAccount['email'] ?? '';
          _addressController.text = tenantAccount['address'] ?? '';
          _websiteController.text = (tenantAccount['website'] as String?)?.isNotEmpty == true 
              ? tenantAccount['website'] 
              : 'https://stockflowkp.online';
          _currencyController.text = tenantAccount['currency'] ?? 'KES';
          final loadedTz = tenantAccount['timezone'] ?? 'Africa/Nairobi';
          if (!_timezones.contains(loadedTz)) {
            _timezones.add(loadedTz);
          }
          _selectedTimezone = loadedTz;
        }
      });
    }
  }

  Future<void> _saveTenantData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final dbService = DatabaseService();
      
      final updatedData = {
        'company_name': _companyNameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() 
            : null,
        'phone': _phoneController.text.trim().isNotEmpty 
            ? _phoneController.text.trim() 
            : null,
        'email': _emailController.text.trim().isNotEmpty 
            ? _emailController.text.trim() 
            : null,
        'address': _addressController.text.trim().isNotEmpty 
            ? _addressController.text.trim() 
            : null,
        'website': _websiteController.text.trim().isNotEmpty 
            ? _websiteController.text.trim() 
            : 'https://stockflowkp.com',
        'currency': _currencyController.text.trim().isNotEmpty 
            ? _currencyController.text.trim() 
            : null,
        'timezone': _selectedTimezone,
        'logo': _selectedLogo != null ? _selectedLogo!.path : _tenantData?['logo'],
        'logo_url': _tenantData?['logo_url'],
      };

      await dbService.updateTenantAccount(updatedData);
      
      // Reload data to get updated information
      await _loadTenantData();
      
      setState(() {
        _isEditMode = false;
        _selectedLogo = null;
      });
      
      _showSuccessMessage('Company information updated successfully!');
    } catch (e) {
      _showErrorMessage('Failed to update company information: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _pickLogo() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      
      if (image != null) {
        setState(() {
          _selectedLogo = File(image.path);
        });
      }
    } catch (e) {
      _showErrorMessage('Failed to pick image: $e');
    }
  }

  Future<void> _contactSupport() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@stockflowkp.com',
      queryParameters: {
        'subject': 'Support Request: ${_tenantData?['company_name'] ?? 'Tenant Info'}',
      },
    );

    try {
      if (!await launchUrl(emailLaunchUri)) {
        _showErrorMessage('Could not launch email client');
      }
    } catch (e) {
      _showErrorMessage('Error launching email: $e');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final fontScale = size.width < 400 ? 0.85 : 1.0;

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
          _isEditMode ? 'Edit Company Info' : 'Company Info',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18 * fontScale,
          ),
        ),
        actions: [
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isEditMode = true;
                });
              },
            ),
          if (_isEditMode)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.cancel_rounded, color: Colors.white70),
                  onPressed: () {
                    setState(() {
                      _isEditMode = false;
                      _selectedLogo = null;
                      _loadTenantData(); // Reset form to original values
                    });
                  },
                ),
                IconButton(
                  icon: _isSaving 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save_rounded, color: Colors.white),
                  onPressed: _isSaving ? null : _saveTenantData,
                ),
              ],
            ),
        ],
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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4BB4FF)))
              : _tenantData == null && !_isEditMode
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.business_rounded,
                            size: 64,
                            color: Colors.white54,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No company information available',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white54,
                              fontSize: 14 * fontScale,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isEditMode = true;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4BB4FF),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Add Company Information'),
                          ),
                        ],
                      ),
                    )
                  : _buildContent(fontScale),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(double fontScale) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      child: _isEditMode ? _buildEditForm(fontScale) : _buildViewForm(fontScale),
    );
  }

  Widget _buildEditForm(double fontScale) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo Section
            _buildLogoEdit(),
            const SizedBox(height: 32),

            // Form Fields
            _buildTextFormField(
              controller: _companyNameController,
              label: 'Company Name',
              icon: Icons.business_rounded,
              fontScale: fontScale,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Company name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildTextFormField(
              controller: _descriptionController,
              label: 'Description',
              icon: Icons.description_rounded,
              fontScale: fontScale,
              maxLines: 3,
              validator: null,
            ),
            const SizedBox(height: 24),

            // Contact Information
            _buildSectionTitle('Contact Information', fontScale),
            const SizedBox(height: 16),

            _buildTextFormField(
              controller: _phoneController,
              label: 'Phone',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              fontScale: fontScale,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final phoneRegex = RegExp(r'^[+]?[0-9\s\-\(\)]{10,}$');
                  if (!phoneRegex.hasMatch(value)) {
                    return 'Please enter a valid phone number';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildTextFormField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_rounded,
              keyboardType: TextInputType.emailAddress,
              fontScale: fontScale,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
                  if (!emailRegex.hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildTextFormField(
              controller: _addressController,
              label: 'Address',
              icon: Icons.location_on_rounded,
              maxLines: 2,
              fontScale: fontScale,
              validator: null,
            ),
            const SizedBox(height: 16),

            _buildTextFormField(
              controller: _websiteController,
              label: 'Website',
              icon: Icons.language_rounded,
              fontScale: fontScale,
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  try {
                    Uri.parse(value);
                  } catch (e) {
                    return 'Please enter a valid website URL';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Business Settings
            _buildSectionTitle('Business Settings', fontScale),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildTextFormField(
                    controller: _currencyController,
                    label: 'Currency',
                    icon: Icons.attach_money_rounded,
                    fontScale: fontScale,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Currency is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedTimezone,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14 * fontScale,
                    ),
                    dropdownColor: const Color(0xFF0A1B32),
                    decoration: InputDecoration(
                      labelText: 'Timezone',
                      labelStyle: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 12 * fontScale,
                      ),
                      prefixIcon: const Icon(
                        Icons.access_time_rounded,
                        color: Color(0xFF4BB4FF),
                        size: 20,
                      ),
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
                        borderSide: const BorderSide(color: Color(0xFF4BB4FF), width: 2),
                      ),
                    ),
                    items: _timezones.map((String tz) {
                      return DropdownMenuItem<String>(
                        value: tz,
                        child: Text(tz, style: TextStyle(fontSize: 14 * fontScale)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedTimezone = newValue;
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Timezone is required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveTenantData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4BB4FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Save Changes',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15 * fontScale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewForm(double fontScale) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Logo Section
          _buildLogoView(),

          // Company Name
          Text(
            _tenantData!['company_name'] as String? ?? 'Unknown Company',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 22 * fontScale,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_tenantData!['description'] != null)
            Text(
              _tenantData!['description'] as String,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white54,
                fontSize: 13 * fontScale,
              ),
            ),
          const SizedBox(height: 32),

          // Info Cards
          _buildInfoCard(Icons.phone_rounded, 'Phone', _tenantData!['phone'] as String?, fontScale),
          _buildInfoCard(Icons.email_rounded, 'Email', _tenantData!['email'] as String?, fontScale),
          _buildInfoCard(Icons.location_on_rounded, 'Address', _tenantData!['address'] as String?, fontScale),
          _buildInfoCard(Icons.language_rounded, 'Website', (_tenantData!['website'] as String?)?.isNotEmpty == true ? _tenantData!['website'] as String : 'https://stockflowkp.com', fontScale),
          
          const SizedBox(height: 16),
          
          // Additional Details
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                _buildDetailRow('Currency', _tenantData!['currency'] as String?, fontScale),
                const Divider(color: Colors.white10, height: 24),
                _buildDetailRow('Timezone', _tenantData!['timezone'] as String?, fontScale),
                const Divider(color: Colors.white10, height: 24),
                _buildDetailRow('Tenant ID', _tenantData!['tenant_id']?.toString(), fontScale),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _contactSupport,
              icon: const Icon(Icons.support_agent_rounded),
              label: Text(
                'Contact Support',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16 * fontScale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLogoEdit() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickLogo,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
              ),
              child: _buildLogoImage(_selectedLogo ?? (_tenantData?['logo'] != null 
                ? File(_tenantData!['logo'] as String) 
                : null)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap to change logo',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoView() {
    final localPath = _tenantData!['logo'] as String?;
    final remoteUrl = _tenantData!['logo_url'] as String?;
    
    ImageProvider? imageProvider;
    if (localPath != null && localPath.isNotEmpty && File(localPath).existsSync()) {
      imageProvider = FileImage(File(localPath));
    } else if (remoteUrl != null && remoteUrl.isNotEmpty) {
      imageProvider = NetworkImage(remoteUrl);
    }

    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
        image: imageProvider != null ? DecorationImage(image: imageProvider, fit: BoxFit.contain) : null,
      ),
      child: imageProvider == null 
          ? const Icon(Icons.business_rounded, size: 48, color: Colors.white54)
          : null,
    );
  }

  Widget _buildLogoImage(File? imageFile) {
    if (imageFile != null && imageFile.existsSync()) {
      return ClipOval(
        child: Image.file(
          imageFile,
          width: 116,
          height: 116,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.business_rounded, size: 48, color: Colors.white54);
          },
        ),
      );
    }
    
    return const Icon(Icons.add_a_photo_rounded, size: 32, color: Colors.white54);
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    required double fontScale,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 14 * fontScale,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white54,
          fontSize: 12 * fontScale,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF4BB4FF),
          size: 20,
        ),
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
          borderSide: const BorderSide(color: Color(0xFF4BB4FF), width: 2),
        ),
        errorStyle: GoogleFonts.plusJakartaSans(
          color: Colors.red[300],
          fontSize: 11 * fontScale,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, double fontScale) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 16 * fontScale,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String? value, double fontScale) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4BB4FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF4BB4FF), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11 * fontScale)),
                Text(value, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14 * fontScale, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, double fontScale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 13 * fontScale)),
        Text(value ?? '-', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13 * fontScale)),
      ],
    );
  }
}