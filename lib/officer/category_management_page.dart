import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/services/sync_service.dart';
import 'category_products_page.dart';

class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  List<Map<String, dynamic>> _categories = [];
  Map<int, int> _productCounts = {};
  bool _isLoading = true;
  final DatabaseService _dbService = DatabaseService();
  final ApiService _apiService = ApiService();
  final SyncService _syncService = SyncService();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _syncCategoriesInBackground();
  }

  // Helper for font scaling
  double _getFontScale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return 0.85;
    if (width > 600) return 1.0;
    return 0.9;
  }

  Future<void> _loadCategories() async {
    final categories = await _dbService.getAllCategories();
    final counts = await _dbService.getCategoryProductCounts();
    if (mounted) {
      setState(() {
        _categories = categories;
        _productCounts = counts;
        _isLoading = false;
      });
    }
  }

  Future<void> _syncCategoriesInBackground() async {
    try {
      final token = await _syncService.getAuthToken();
      if (token != null) {
        // 1. Fetch from API
        final response = await _apiService.getCategories(token);
        if (response['success'] == true && response['data'] != null) {
          final apiCategories = response['data']['categories'] as List;
          
          // 2. Save to DB
          // Note: This uses the existing method which replaces categories. 
          // In a full offline-first app, you might want to merge instead of replace 
          // to preserve local-only pending items.
          await _dbService.saveCategoriesAndPermissions({
            'data': {
              'user': {
                'id': (await _dbService.getUserData())?['data']['user']['id'],
                'categories': apiCategories
              }
            }
          });
          
          _loadCategories();
        }
      }
    } catch (e) {
      print('Background category sync failed: $e');
    }
  }

  Future<void> _showAddEditDialog({Map<String, dynamic>? category}) async {
    final fontScale = _getFontScale(context);
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?['name']);
    final descController = TextEditingController(text: category?['description']);
    int? parentId = category?['parent_id'];
    String status = category?['status'] ?? 'active';

    // Filter out self from parent options if editing
    final parentOptions = _categories.where((c) {
      if (!isEditing) return true;
      return c['local_id'] != category['local_id'];
    }).toList();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1B32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEditing ? 'Edit Category' : 'New Category', 
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18 * fontScale),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameController, 'Name', fontScale),
                const SizedBox(height: 16),
                _buildTextField(descController, 'Description', fontScale, maxLines: 3),
                const SizedBox(height: 16),
                // Parent Dropdown
                DropdownButtonFormField<int>(
                  value: parentId,
                  dropdownColor: const Color(0xFF1E4976),
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14 * fontScale),
                  decoration: _inputDecoration('Parent Category', fontScale),
                  items: [
                    DropdownMenuItem<int>(value: null, child: Text('None (Root)', style: TextStyle(fontSize: 14 * fontScale))),
                    ...parentOptions.map((c) => DropdownMenuItem<int>(
                      value: c['server_id'] ?? c['local_id'], // Prefer server_id for API compatibility
                      child: Text(c['name'], style: TextStyle(fontSize: 14 * fontScale)),
                    )),
                  ],
                  onChanged: (val) => setState(() => parentId = val),
                ),
                const SizedBox(height: 16),
                // Status Dropdown
                DropdownButtonFormField<String>(
                  value: status,
                  dropdownColor: const Color(0xFF1E4976),
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14 * fontScale),
                  decoration: _inputDecoration('Status', fontScale),
                  items: [
                    DropdownMenuItem(value: 'active', child: Text('Active', style: TextStyle(fontSize: 14 * fontScale))),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive', style: TextStyle(fontSize: 14 * fontScale))),
                  ],
                  onChanged: (val) => setState(() => status = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 14 * fontScale)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                Navigator.pop(context);
                await _saveCategory(
                  isEditing: isEditing,
                  localId: category?['local_id'],
                  serverId: category?['server_id'],
                  data: {
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                    'parent_id': parentId,
                    'status': status,
                  },
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4BB4FF)),
              child: Text(isEditing ? 'Update' : 'Create', style: TextStyle(fontSize: 14 * fontScale, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCategory({
    required bool isEditing,
    int? localId,
    int? serverId,
    required Map<String, dynamic> data,
  }) async {
    setState(() => _isLoading = true);
    
    try {
      final token = await _syncService.getAuthToken();
      bool apiSuccess = false;
      int? newServerId;

      // 1. Try API if online
      if (token != null) {
        try {
          if (isEditing && serverId != null) {
            await _apiService.updateCategory(serverId, data, token);
            apiSuccess = true;
          } else if (!isEditing) {
            final response = await _apiService.createCategory(data, token);
            if (response['success'] == true) {
              newServerId = response['data']['category']['id'];
              apiSuccess = true;
            }
          }
        } catch (e) {
          print('API operation failed: $e');
          // Continue to local save
        }
      }

      // 2. Save Locally
      if (isEditing) {
        await _dbService.updateCategory(localId!, {
          ...data,
          'sync_status': apiSuccess ? DatabaseService.statusSynced : DatabaseService.statusPending,
        });
      } else {
        final id = await _dbService.createCategory({
          ...data,
          'server_id': newServerId,
          'sync_status': apiSuccess ? DatabaseService.statusSynced : DatabaseService.statusPending,
        });
        if (apiSuccess && newServerId != null) {
          // Ensure server_id is set if we got it from API
          await _dbService.updateCategoryServerId(id, newServerId);
        }
      }

      _showSnackBar(
        apiSuccess 
          ? 'Category ${isEditing ? 'updated' : 'created'} successfully' 
          : 'Saved locally. Will sync when online.',
        isError: !apiSuccess
      );

      _loadCategories();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final fontScale = _getFontScale(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1B32),
        title: Text('Delete Category?', style: TextStyle(color: Colors.white, fontSize: 18 * fontScale)),
        content: Text(
          'Are you sure you want to delete "${category['name']}"?',
          style: TextStyle(color: Colors.white70, fontSize: 14 * fontScale),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 14 * fontScale))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red, fontSize: 14 * fontScale)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final token = await _syncService.getAuthToken();
      
      // Try API delete first if it has a server ID
      if (category['server_id'] != null && token != null) {
        try {
          await _apiService.deleteCategory(category['server_id'], token);
        } catch (e) {
          _showSnackBar('Failed to delete from server: $e', isError: true);
          setState(() => _isLoading = false);
          return; // Don't delete locally if server delete fails to avoid sync issues
        }
      }

      // Delete locally
      await _dbService.deleteCategory(category['local_id']);
      _showSnackBar('Category deleted');
      _loadCategories();
    } catch (e) {
      _showSnackBar('Error deleting category: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.orange : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, double fontScale) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white70, fontSize: 14 * fontScale),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, double fontScale, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: Colors.white, fontSize: 14 * fontScale),
      decoration: _inputDecoration(label, fontScale),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = _getFontScale(context);
    
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
          'Categories',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20 * fontScale),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              setState(() => _isLoading = true);
              _syncCategoriesInBackground();
            },
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4BB4FF)))
              : _categories.isEmpty
                  ? Center(child: Text('No categories found', style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 16 * fontScale)))
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 400, // Responsive grid
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: 100, // Fixed height for cards
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final cat = _categories[index];
                                return _buildCategoryCard(cat, fontScale);
                              },
                              childCount: _categories.length,
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: const Color(0xFF4BB4FF),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat, double fontScale) {
    final isSynced = cat['sync_status'] == DatabaseService.statusSynced;
    final name = cat['name'] as String? ?? 'Unknown';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final serverId = cat['server_id'] as int?;
    final productCount = serverId != null ? (_productCounts[serverId] ?? 0) : 0;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryProductsPage(category: cat),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Icon/Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4BB4FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF4BB4FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 20 * fontScale,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15 * fontScale,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!isSynced)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6.0),
                                  child: Icon(Icons.cloud_off_rounded, size: 14, color: Colors.orange[300]),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (cat['status'] == 'active' ? Colors.green : Colors.grey).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  cat['status']?.toUpperCase() ?? 'ACTIVE',
                                  style: TextStyle(
                                    color: cat['status'] == 'active' ? Colors.greenAccent : Colors.grey,
                                    fontSize: 9 * fontScale,
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4BB4FF).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$productCount Products',
                                  style: TextStyle(
                                    color: const Color(0xFF4BB4FF),
                                    fontSize: 9 * fontScale,
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Actions
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => _showAddEditDialog(category: cat),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(Icons.edit_rounded, color: Colors.white70, size: 20 * fontScale),
                          ),
                        ),
                        InkWell(
                          onTap: () => _deleteCategory(cat),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.8), size: 20 * fontScale),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}