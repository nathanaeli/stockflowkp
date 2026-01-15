import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/services/api_service.dart';

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  List<Map<String, dynamic>> _permissions = [];
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  int? _officerId;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);
    
    try {
      // Get user data to get officer ID
      _userData = await DatabaseService().getUserData();
      if (_userData != null) {
        _officerId = _userData!['data']['user']['id'];
        
        // Fetch permissions from database
        _permissions = await DatabaseService().getPermissionsByOfficer(_officerId!);
        
        // Also try to refresh from API
        await _refreshPermissionsFromAPI();
      }
    } catch (e) {
      print('Error loading permissions: $e');
      _showErrorSnackBar('Failed to load permissions');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshPermissionsFromAPI() async {
    try {
      final token = _userData!['data']['token'];
      final apiService = ApiService();
      
      // Fetch fresh permissions from API
      final permissionsResponse = await apiService.getOfficerPermissions(_officerId!, token);
      
      if (permissionsResponse['data'] != null) {
        // Save permissions to database and update local list
        await DatabaseService().saveCategoriesAndPermissions({
          'data': {
            'user': {
              'id': _officerId,
              'permissions': permissionsResponse['data']['permissions']
            }
          }
        });
        
        // Refresh local list
        _permissions = await DatabaseService().getPermissionsByOfficer(_officerId!);
        setState(() {});
      }
    } catch (e) {
      print('API refresh failed, using database data: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [Color(0xFF1E4976), Color(0xFF0A1B32), Color(0xFF020B18)],
              ),
            ),
          ),
          
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Custom Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                    child: Row(
                      children: [
                        _buildGlassIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "My Permissions",
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 24,
                                ),
                              ),
                              Text(
                                "View your access rights",
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white38,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildGlassIconButton(
                          icon: Icons.refresh_rounded,
                          onTap: _loadPermissions,
                        ),
                      ],
                    ),
                  ),
                ),

                // Permissions List
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
                    child: _isLoading
                        ? _buildLoadingIndicator()
                        : _permissions.isEmpty
                            ? _buildEmptyState()
                            : _buildPermissionsList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF4BB4FF),
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading permissions...',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Permissions Found',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You don\'t have any assigned permissions yet.',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsList() {
    return Column(
      children: _permissions.map((permission) => _buildPermissionCard(permission)).toList(),
    );
  }

  Widget _buildPermissionCard(Map<String, dynamic> permission) {
    final permissionText = permission['permission'] ?? 'Unknown Permission';
    final createdAt = permission['created_at'] ?? '';
    
    // Parse and format the created date
    String formattedDate = '';
    if (createdAt.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(createdAt);
        formattedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } catch (e) {
        formattedDate = 'Unknown date';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Permission Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4BB4FF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF4BB4FF),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Permission Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatPermissionName(permissionText),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate.isNotEmpty ? 'Granted on $formattedDate' : 'Active permission',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Active',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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

  String _formatPermissionName(String permission) {
    // Convert permission string to more readable format
    if (permission.contains('.')) {
      final parts = permission.split('.');
      final action = parts.last;
      final resource = parts.length > 1 ? parts[parts.length - 2] : '';
      
      switch (action.toLowerCase()) {
        case 'create':
          return 'Create $resource';
        case 'read':
          return 'View $resource';
        case 'update':
          return 'Edit $resource';
        case 'delete':
          return 'Delete $resource';
        case 'manage':
          return 'Manage $resource';
        default:
          return permission.replaceAll('.', ' ').split(' ').map((word) => 
            word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : ''
          ).join(' ');
      }
    }
    
    return permission.replaceAll('_', ' ').split(' ').map((word) => 
      word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : ''
    ).join(' ');
  }
}