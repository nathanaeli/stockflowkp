import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/services/api_service.dart';

class OfficerPermissionsPage extends StatefulWidget {
  final String token;
  final int officerId;
  final String officerName;

  const OfficerPermissionsPage({
    super.key,
    required this.token,
    required this.officerId,
    required this.officerName,
  });

  @override
  State<OfficerPermissionsPage> createState() => _OfficerPermissionsPageState();
}

class _OfficerPermissionsPageState extends State<OfficerPermissionsPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _permissionsMatrix = [];
  Map<String, dynamic>? _planInfo;
  List<dynamic>? _assignedDukas;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getOfficerPermissions(
        widget.token,
        widget.officerId,
      );

      print(response);

      if (mounted) {
        setState(() {
          _permissionsMatrix = response['data']['permissions_matrix'] ?? [];
          _planInfo = response['data']['plan_info'];
          _assignedDukas = response['data']['assigned_dukas'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load permissions: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePermission(
    int? permissionId,
    String? permissionName,
    bool isGranted,
  ) async {
    // Optimistic update
    final index = _permissionsMatrix.indexWhere((p) {
      if (permissionId != null && p['permission_id'] == permissionId) {
        return true;
      }
      return permissionName != null && p['permission_name'] == permissionName;
    });
    if (index == -1) return;

    final oldState = _permissionsMatrix[index]['is_granted'];
    setState(() {
      _permissionsMatrix[index]['is_granted'] = isGranted;
    });

    try {
      // Collect ALL granted permissions as strings (required by backend "replace all" logic)
      final List<String> grantedPermissions =
          _permissionsMatrix
              .where(
                (p) => p['is_granted'] == true && p['permission_name'] != null,
              )
              .map<String>((p) => p['permission_name'].toString())
              .toList();

      await _apiService.updateOfficerPermissions(
        widget.token,
        widget.officerId,
        grantedPermissions,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isGranted ? 'Permission granted ✓' : 'Permission revoked',
            ),
            backgroundColor: isGranted ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _permissionsMatrix[index]['is_granted'] = oldState;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int get _grantedCount =>
      _permissionsMatrix.where((p) => p['is_granted'] == true).length;
  int get _totalCount => _permissionsMatrix.length;

  String _formatPermissionName(String name) {
    return name
        .split('_')
        .map(
          (word) =>
              word.isNotEmpty
                  ? '${word[0].toUpperCase()}${word.substring(1)}'
                  : '',
        )
        .join(' ');
  }

  IconData _getPermissionIcon(String permissionName) {
    if (permissionName.contains('product')) return Icons.inventory_2_outlined;
    if (permissionName.contains('sale')) return Icons.point_of_sale_outlined;
    if (permissionName.contains('customer')) return Icons.people_outline;
    if (permissionName.contains('report')) return Icons.assessment_outlined;
    if (permissionName.contains('stock')) return Icons.inventory_outlined;
    if (permissionName.contains('dashboard')) return Icons.dashboard_outlined;
    if (permissionName.contains('order')) return Icons.shopping_cart_outlined;
    if (permissionName.contains('supplier')) return Icons.business_outlined;
    return Icons.security_outlined;
  }

  @override
  Widget build(BuildContext context) {
    // Group permissions by 'feature'
    final Map<String, List<dynamic>> groupedPermissions = {};
    for (var perm in _permissionsMatrix) {
      final feature = perm['feature'] ?? 'General';
      if (!groupedPermissions.containsKey(feature)) {
        groupedPermissions[feature] = [];
      }
      groupedPermissions[feature]!.add(perm);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.officerName,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Manage Permissions',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4BB4FF)),
              )
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadPermissions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4BB4FF),
                      ),
                      child: const Text('Retry'),
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
                    _buildStatsCard(),
                    const SizedBox(height: 16),

                    // Plan Info
                    if (_planInfo != null) ...[
                      _buildPlanInfoCard(),
                      const SizedBox(height: 24),
                    ],

                    // Help Text
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.lightBlueAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Toggle switches to grant or revoke permissions. Changes are saved automatically.',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Permissions List
                    ...groupedPermissions.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4BB4FF),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  entry.key.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...entry.value.map((perm) {
                            final permissionId = perm['permission_id'];
                            final permissionName =
                                perm['permission_name']?.toString();
                            final feature =
                                perm['feature']?.toString() ?? 'System';

                            // Determine Display Name from API -> Formatted Name -> Feature
                            String displayName =
                                perm['display_name']?.toString() ?? '';
                            if (displayName.trim().isEmpty) {
                              if (permissionName != null &&
                                  permissionName.isNotEmpty) {
                                displayName = _formatPermissionName(
                                  permissionName,
                                );
                              } else {
                                displayName = '$feature Access';
                              }
                            }

                            final isGranted = perm['is_granted'] == true;

                            // Determine Description from API -> Generic Fallback
                            String description =
                                perm['description']?.toString() ?? '';
                            if (description.isEmpty) {
                              description = 'Manage $feature functionality';
                            }

                            // Icon handling (can remain UI logic or move to backend if needed, keeping simple heuristic for now)
                            final icon =
                                permissionName != null
                                    ? _getPermissionIcon(permissionName)
                                    : Icons.security_outlined;

                            return _buildPermissionCard(
                              displayName: displayName,
                              description: description,
                              icon: icon,
                              isGranted: isGranted,
                              onChanged:
                                  (val) => _updatePermission(
                                    permissionId,
                                    permissionName,
                                    val,
                                  ),
                            );
                          }),
                          const SizedBox(height: 24),
                        ],
                      );
                    }),
                  ],
                ),
              ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        border: Border.all(color: const Color(0xFF4BB4FF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4BB4FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.verified_user,
              color: Color(0xFF4BB4FF),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Permissions',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_grantedCount of $_totalCount granted',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  _grantedCount > 0
                      ? Colors.green.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _grantedCount > 0 ? 'Active' : 'Limited',
              style: GoogleFonts.plusJakartaSans(
                color: _grantedCount > 0 ? Colors.greenAccent : Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required String displayName,
    required String description,
    required IconData icon,
    required bool isGranted,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isGranted ? 0.08 : 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isGranted
                  ? const Color(0xFF4BB4FF).withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
          width: isGranted ? 2 : 1,
        ),
      ),
      child: Theme(
        data: ThemeData(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  isGranted
                      ? const Color(0xFF4BB4FF).withOpacity(0.2)
                      : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isGranted ? const Color(0xFF4BB4FF) : Colors.grey,
              size: 22,
            ),
          ),
          title: Text(
            displayName,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white60,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Switch(
            value: isGranted,
            activeColor: const Color(0xFF4BB4FF),
            activeTrackColor: const Color(0xFF4BB4FF).withOpacity(0.5),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
            onChanged: onChanged,
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.white54),
                      const SizedBox(width: 8),
                      Text(
                        'What this allows:',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isGranted
                              ? Colors.green.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isGranted ? Icons.check_circle : Icons.lock_outline,
                          size: 14,
                          color:
                              isGranted
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isGranted ? 'Access Granted' : 'Access Denied',
                          style: GoogleFonts.plusJakartaSans(
                            color:
                                isGranted
                                    ? Colors.greenAccent
                                    : Colors.orangeAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.15),
            Colors.purple.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: Colors.purpleAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _planInfo!['name'] ?? 'Current Plan',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_planInfo!['max_dukas'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Supports up to ${_planInfo!['max_dukas']} stores',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
