import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/database_service.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _categories = [];
  String? _token;
  String _searchQuery = '';
  late AnimationController _animationController;

  // Predefined category colors and icons
  final Map<String, Map<String, dynamic>> _categoryThemes = {
    'electronics': {
      'color': const Color(0xFF6366F1),
      'icon': Icons.devices_rounded,
    },
    'clothing': {
      'color': const Color(0xFFEC4899),
      'icon': Icons.checkroom_rounded,
    },
    'food': {
      'color': const Color(0xFF10B981),
      'icon': Icons.restaurant_rounded,
    },
    'furniture': {
      'color': const Color(0xFFF59E0B),
      'icon': Icons.chair_rounded,
    },
    'books': {
      'color': const Color(0xFF8B5CF6),
      'icon': Icons.menu_book_rounded,
    },
    'sports': {
      'color': const Color(0xFF06B6D4),
      'icon': Icons.sports_soccer_rounded,
    },
    'beauty': {'color': const Color(0xFFF97316), 'icon': Icons.spa_rounded},
    'toys': {'color': const Color(0xFFEF4444), 'icon': Icons.toys_rounded},
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadCategories();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userData = await _dbService.getUserData();
      if (userData != null && userData['data'] != null) {
        _token = userData['data']['token'];

        final response = await _apiService.getTenantCategories(_token!);
        final categories = response['data'] as List? ?? [];

        if (mounted) {
          setState(() {
            _categories = categories;
            _isLoading = false;
          });
          _animationController.forward();
        }
      } else {
        if (mounted) {
          setState(() {
            _error = "User session not found.";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load categories: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteCategory(int categoryId, int productCount) async {
    if (_token == null) return;

    if (productCount > 0) {
      _showAnimatedSnackBar(
        'Cannot delete: This category has $productCount product${productCount > 1 ? "s" : ""}',
        Colors.orange,
        Icons.warning_amber_rounded,
      );
      return;
    }

    final confirm = await _showDeleteDialog();
    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);
      await _apiService.deleteTenantCategory(_token!, categoryId);
      await _loadCategories();
      if (mounted) {
        _showAnimatedSnackBar(
          'Category deleted successfully',
          Colors.green,
          Icons.check_circle,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showAnimatedSnackBar('Failed to delete: $e', Colors.red, Icons.error);
      }
    }
  }

  Future<bool?> _showDeleteDialog() {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => Theme(
            data: ThemeData.dark(),
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E1E2E),
                      const Color(0xFF1E1E2E).withOpacity(0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Delete Category?',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This action cannot be undone. The category will be permanently removed.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: Text(
                              'Delete',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

  void _showAnimatedSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAddEditCategoryModal([Map<String, dynamic>? category]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _AddEditCategoryForm(
            token: _token!,
            category: category,
            onSave: () {
              Navigator.pop(context);
              _loadCategories();
            },
          ),
    );
  }

  Map<String, dynamic> _getCategoryTheme(String? name) {
    if (name == null) {
      return {'color': const Color(0xFF4BB4FF), 'icon': Icons.category};
    }
    final lowerName = name.toLowerCase();
    for (var key in _categoryThemes.keys) {
      if (lowerName.contains(key)) {
        return _categoryThemes[key]!;
      }
    }
    // Default theme
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
    ];
    return {
      'color': colors[name.hashCode % colors.length],
      'icon': Icons.category,
    };
  }

  int get _activeCategories =>
      _categories.where((c) => c['status'] == 'active').length;

  List<dynamic> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;
    return _categories
        .where(
          (cat) =>
              cat['name']?.toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4BB4FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: Color(0xFF4BB4FF),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading categories...',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return _buildErrorView();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _buildFloatingActionButton(),
      body: _categories.isEmpty ? _buildEmptyState() : _buildCategoriesList(),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => _showAddEditCategoryModal(),
      backgroundColor: const Color(0xFF4BB4FF),
      elevation: 8,
      icon: const Icon(Icons.add_rounded, size: 24),
      label: Text(
        "New Category",
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 1),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF4BB4FF).withOpacity(0.2),
                        const Color(0xFF4BB4FF).withOpacity(0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.category_outlined,
                    size: 80,
                    color: const Color(0xFF4BB4FF).withOpacity(0.8),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            "No Categories Yet",
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Organize your inventory by creating\nproduct categories",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showAddEditCategoryModal(),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Create First Category'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4BB4FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              color: Colors.redAccent,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Oops! Something went wrong',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadCategories,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4BB4FF),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animated Stats Card
          _buildStatsCard(),
          const SizedBox(height: 24),

          // Search Bar
          _buildSearchBar(),
          const SizedBox(height: 24),

          // Categories List Header
          _buildSectionHeader(),
          const SizedBox(height: 16),

          // Categories Grid
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child:
                _filteredCategories.isEmpty
                    ? _buildNoResults()
                    : _buildCategoriesGrid(),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4BB4FF).withOpacity(0.2),
                    const Color(0xFF4BB4FF).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF4BB4FF).withOpacity(0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4BB4FF).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4BB4FF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.category_rounded,
                      color: Color(0xFF4BB4FF),
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Categories',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white60,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '$_activeCategories',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 32,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _activeCategories == 1 ? "Active" : "Active",
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF4BB4FF),
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'out of ${_categories.length} total',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        style: GoogleFonts.plusJakartaSans(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search categories...',
          hintStyle: GoogleFonts.plusJakartaSans(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      color: Colors.white54,
                    ),
                    onPressed: () => setState(() => _searchQuery = ''),
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF4BB4FF),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'ALL CATEGORIES',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4BB4FF).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_filteredCategories.length}',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF4BB4FF),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No categories found',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white60,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: _filteredCategories.length,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value,
                child: _buildCategoryCard(_filteredCategories[index]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final status = category['status'] ?? 'active';
    final isActive = status == 'active';
    final productCount = category['products_count'] ?? 0;
    final theme = _getCategoryTheme(category['name']);
    final color = theme['color'] as Color;
    final icon = theme['icon'] as IconData;

    return Hero(
      tag: 'category_${category['id']}',
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(isActive ? 0.15 : 0.05),
                color.withOpacity(isActive ? 0.05 : 0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isActive
                      ? color.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive ? color.withOpacity(0.2) : Colors.transparent,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showAddEditCategoryModal(category),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 26),
                      ),
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                        color: const Color(0xFF2A2A35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showAddEditCategoryModal(category);
                          } else if (value == 'delete') {
                            _deleteCategory(category['id'], productCount);
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
                                      'Edit',
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
                                      'Delete',
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
                  const Spacer(),
                  Text(
                    category['name'] ?? 'Unknown',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (category['description'] != null &&
                      category['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      category['description'],
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 14,
                                color: color,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '$productCount items',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isActive
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isActive ? Icons.check_circle : Icons.remove_circle,
                          size: 14,
                          color: isActive ? Colors.greenAccent : Colors.grey,
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
    );
  }
}

class _AddEditCategoryForm extends StatefulWidget {
  final String token;
  final Map<String, dynamic>? category;
  final VoidCallback onSave;

  const _AddEditCategoryForm({
    required this.token,
    this.category,
    required this.onSave,
  });

  @override
  State<_AddEditCategoryForm> createState() => _AddEditCategoryFormState();
}

class _AddEditCategoryFormState extends State<_AddEditCategoryForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  String _status = 'active';
  bool _isLoading = false;
  late AnimationController _animController;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animController.forward();

    final category = widget.category;
    _nameController = TextEditingController(text: category?['name'] ?? '');
    _descriptionController = TextEditingController(
      text: category?['description'] ?? '',
    );
    _status = category?['status'] ?? 'active';
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'status': _status,
      };

      if (widget.category == null) {
        await _apiService.createTenantCategory(widget.token, data);
      } else {
        await _apiService.updateTenantCategory(
          widget.token,
          widget.category!['id'],
          data,
        );
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
    final isEditing = widget.category != null;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _animController.value) * 300),
          child: Opacity(
            opacity: _animController.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E1E2E),
                    const Color(0xFF1E1E2E).withOpacity(0.98),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle Bar
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4BB4FF),
                                    Color(0xFF2196F3),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isEditing
                                    ? Icons.edit
                                    : Icons.add_circle_outline,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEditing
                                        ? 'Edit Category'
                                        : 'New Category',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    isEditing
                                        ? 'Update category details'
                                        : 'Create a new product category',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white54,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Form Fields
                        _buildTextField(
                          controller: _nameController,
                          label: 'Category Name',
                          hint: 'e.g. Electronics, Clothing, Food',
                          icon: Icons.category_outlined,
                          validator:
                              (v) =>
                                  v!.isEmpty
                                      ? 'Category name is required'
                                      : null,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _descriptionController,
                          label: 'Description (Optional)',
                          hint: 'Brief description of this category',
                          icon: Icons.description_outlined,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),
                        _buildStatusDropdown(),
                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4BB4FF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                    : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isEditing
                                              ? Icons.check_circle_outline
                                              : Icons.add_circle_outline,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          isEditing
                                              ? 'Update Category'
                                              : 'Create Category',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white.withOpacity(0.3),
          fontSize: 12,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white70,
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF4BB4FF), size: 22),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4BB4FF), width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      value: _status,
      items: [
        DropdownMenuItem(
          value: 'active',
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.greenAccent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Active',
                style: GoogleFonts.plusJakartaSans(color: Colors.white),
              ),
            ],
          ),
        ),
        DropdownMenuItem(
          value: 'inactive',
          child: Row(
            children: [
              const Icon(Icons.remove_circle, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Text(
                'Inactive',
                style: GoogleFonts.plusJakartaSans(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
      onChanged: (val) => setState(() => _status = val!),
      dropdownColor: const Color(0xFF2A2A35),
      decoration: InputDecoration(
        labelText: 'Status',
        labelStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white70,
          fontSize: 14,
        ),
        prefixIcon: const Icon(
          Icons.toggle_on_outlined,
          color: Color(0xFF4BB4FF),
          size: 22,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4BB4FF), width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }
}
