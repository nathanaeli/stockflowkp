import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/tenants/officer_permissions_page.dart';

class OfficersPage extends StatefulWidget {
  const OfficersPage({super.key});

  @override
  State<OfficersPage> createState() => _OfficersPageState();
}

class _OfficersPageState extends State<OfficersPage> {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _officers = [];
  List<dynamic> _dukas = [];
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userData = await _dbService.getUserData();
      if (userData != null && userData['data'] != null) {
        _token = userData['data']['token'];

        // Fetch Officers
        final officersResponse = await _apiService.getTenantOfficers(_token!);
        final officers = officersResponse['data']['officers'] as List? ?? [];

        // Fetch Dukas (for assignment)
        final dukasResponse = await _apiService.getTenantDukas(_token!);
        final dukas = dukasResponse['data'] as List? ?? [];

        if (mounted) {
          setState(() {
            _officers = officers;
            _dukas = dukas;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = "User session not found."; // TODO: Add translation
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load data: $e"; // TODO: Add translation
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteOfficer(int officerId) async {
    if (_token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Delete Officer',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'This will remove the officer from your team. They will lose access to the system immediately.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Delete',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);
      await _apiService.deleteTenantOfficer(_token!, officerId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  'Officer removed successfully',
                  style: GoogleFonts.plusJakartaSans(),
                ),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddEditOfficerModal([Map<String, dynamic>? officer]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => _AddEditOfficerForm(
            token: _token!,
            dukas: _dukas,
            officer: officer,
            onSave: () {
              Navigator.pop(context);
              _loadData();
            },
          ),
    );
  }

  int get _activeOfficers =>
      _officers.where((o) => o['status'] == 'active').length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4BB4FF)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4BB4FF),
              ),
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Team Management",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditOfficerModal(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4BB4FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: Text(
                    "Add Officer",
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _officers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.people_outline,
                              size: 48,
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No Team Members Yet",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Start building your team by adding officers",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                    : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF4BB4FF).withOpacity(0.2),
                                  const Color(0xFF4BB4FF).withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF4BB4FF).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4BB4FF,
                                    ).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.groups_rounded,
                                    color: Color(0xFF4BB4FF),
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Team Overview',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white60,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$_activeOfficers Active ${_activeOfficers == 1 ? "Officer" : "Officers"}',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'out of ${_officers.length} total',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white54,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Officers List Header
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Row(
                              children: [
                                Text(
                                  'STAFF MEMBERS',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4BB4FF,
                                    ).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${_officers.length}',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF4BB4FF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Officers List
                          ..._officers.map(
                            (officer) => _buildOfficerCard(officer),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficerCard(Map<String, dynamic> officer) {
    final assignment = officer['assignment'] ?? {};
    final status = officer['status'] ?? 'inactive';
    final isActive = status == 'active';
    final dukaName = assignment['duka_name'] ?? 'Unassigned';
    final role = assignment['role'] ?? 'officer';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isActive ? 0.08 : 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isActive
                  ? const Color(0xFF4BB4FF).withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showAddEditOfficerModal(officer),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                Hero(
                  tag: 'officer_${officer['id']}',
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4BB4FF),
                          const Color(0xFF4BB4FF).withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4BB4FF).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        (officer['name'] ?? 'U').substring(0, 1).toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              officer['name'] ?? 'Unknown',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isActive
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isActive
                                      ? Icons.check_circle
                                      : Icons.remove_circle_outline,
                                  size: 8,
                                  color:
                                      isActive
                                          ? Colors.greenAccent
                                          : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: GoogleFonts.plusJakartaSans(
                                    color:
                                        isActive
                                            ? Colors.greenAccent
                                            : Colors.grey,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        officer['email'] ?? '',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.store_outlined,
                            size: 12,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dukaName,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.work_outline,
                            size: 12,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            role.replaceAll('_', ' '),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Actions
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.more_vert,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                  color: const Color(0xFF2A2A35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showAddEditOfficerModal(officer);
                    } else if (value == 'permissions') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => OfficerPermissionsPage(
                                token: _token!,
                                officerId: officer['id'],
                                officerName: officer['name'] ?? 'Officer',
                              ),
                        ),
                      );
                    } else if (value == 'delete') {
                      _deleteOfficer(officer['id']);
                    }
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Edit Details',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'permissions',
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4BB4FF,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.verified_user_outlined,
                                  size: 16,
                                  color: Color(0xFF4BB4FF),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Manage Permissions',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: Colors.redAccent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Remove Officer',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddEditOfficerForm extends StatefulWidget {
  final String token;
  final List<dynamic> dukas;
  final Map<String, dynamic>? officer;
  final VoidCallback onSave;

  const _AddEditOfficerForm({
    required this.token,
    required this.dukas,
    this.officer,
    required this.onSave,
  });

  @override
  State<_AddEditOfficerForm> createState() => _AddEditOfficerFormState();
}

class _AddEditOfficerFormState extends State<_AddEditOfficerForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;

  int? _selectedDukaId;
  String _selectedRole = 'officer';
  bool _isActive = true;
  bool _isLoading = false;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    final officer = widget.officer;
    _nameController = TextEditingController(text: officer?['name'] ?? '');
    _emailController = TextEditingController(text: officer?['email'] ?? '');
    _phoneController = TextEditingController(text: officer?['phone'] ?? '');
    _passwordController = TextEditingController();

    if (officer != null) {
      final assignment = officer['assignment'] ?? {};
      _selectedDukaId = assignment['duka_id'];
      _selectedRole = assignment['role'] ?? 'officer';
      _isActive = officer['status'] == 'active';
    } else {
      if (widget.dukas.isNotEmpty) {
        _selectedDukaId = widget.dukas.first['id'];
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDukaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Please select a store'),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'duka_id': _selectedDukaId,
        'role': _selectedRole,
      };

      if (widget.officer == null) {
        data['password'] = _passwordController.text;
        await _apiService.createTenantOfficer(widget.token, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text('Officer added successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (_passwordController.text.isNotEmpty) {
          data['password'] = _passwordController.text;
        }
        data['status'] = _isActive;
        await _apiService.updateTenantOfficer(
          widget.token,
          widget.officer!['id'],
          data,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text('Officer updated successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      widget.onSave();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.officer != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Officer' : 'Add New Officer',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        isEditing
                            ? 'Update officer details'
                            : 'Fill in the details below',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Personal Info Section
              _buildSectionHeader('Personal Information', Icons.person_outline),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      hint: 'e.g. John Doe',
                      validator: (v) => v!.isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      hint: 'e.g. john@example.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v!.isEmpty ? 'Email is required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      hint: 'e.g. +255 712 345 678',
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Security & Role Section
              _buildSectionHeader('Security & Role', Icons.security_outlined),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _passwordController,
                      label: isEditing ? 'New Password (Optional)' : 'Password',
                      icon: Icons.lock_outline,
                      hint: 'Min. 8 characters',
                      obscureText: true,
                      validator: (v) {
                        if (!isEditing && (v == null || v.length < 8)) {
                          return 'Min 8 characters required';
                        }
                        if (isEditing && v!.isNotEmpty && v.length < 8) {
                          return 'Min 8 characters required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      value: _selectedDukaId,
                      label: 'Assign to Store',
                      icon: Icons.store_outlined,
                      items:
                          widget.dukas.map<DropdownMenuItem<int>>((duka) {
                            return DropdownMenuItem<int>(
                              value: duka['id'],
                              child: Text(
                                duka['name'],
                                style: const TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                      onChanged: (val) => setState(() => _selectedDukaId = val),
                    ),
                    const SizedBox(height: 12),
                    // Removed role dropdown - defaulting to 'officer'
                  ],
                ),
              ),

              if (isEditing) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      'Account Status',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _isActive
                          ? 'Officer can access the system'
                          : 'Officer access is blocked',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                    value: _isActive,
                    activeColor: const Color(0xFF4BB4FF),
                    onChanged: (val) => setState(() => _isActive = val),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4BB4FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isEditing
                                    ? Icons.check_circle_outline
                                    : Icons.person_add_outlined,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isEditing ? 'Update Officer' : 'Create Officer',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF4BB4FF).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF4BB4FF), size: 14),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 11,
        ),
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
        prefixIcon: Icon(icon, color: Colors.white70, size: 18),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4BB4FF), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: const Color(0xFF2A2A35),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
        prefixIcon: Icon(icon, color: Colors.white70, size: 18),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4BB4FF), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }
}
