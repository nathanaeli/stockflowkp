import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/l10n/app_localizations.dart';
import 'package:stockflowkp/services/sync_service.dart';
import 'edit_product_page.dart';
// import 'add_product_item_page.dart';
import 'add_stock_page.dart';
import 'reduce_stock_page.dart';
import 'Advancedpage/addingproduct.dart';

// Skeleton loading widget for animated loading state
class ProductCardSkeleton extends StatefulWidget {
  const ProductCardSkeleton({super.key});

  @override
  State<ProductCardSkeleton> createState() => _ProductCardSkeletonState();
}

class _ProductCardSkeletonState extends State<ProductCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LocalProductPage extends StatefulWidget {
  final Future<void> Function()? onRefresh;
  const LocalProductPage({super.key, this.onRefresh});

  @override
  State<LocalProductPage> createState() => _LocalProductPageState();
}

class _LocalProductPageState extends State<LocalProductPage> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _allLocalProducts = [];
  List<Map<String, dynamic>> _filteredProducts = []; // For search filtering
  List<String> _permissions = []; // Store officer permissions
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    await _loadPermissions();
    await _loadLocalData();
  }

  // Filter products based on search query
  void _runFilter(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredProducts = _allLocalProducts;
      });
    } else {
      setState(() {
        _filteredProducts =
            _allLocalProducts
                .where(
                  (product) => (product['name'] as String)
                      .toLowerCase()
                      .contains(query.toLowerCase()),
                )
                .toList();
      });
    }
  }

  // Fetch permissions to control editing access
  Future<void> _loadPermissions() async {
    try {
      final db = await _dbService.database;
      final userDataMaps = await db.query('user_data');
      if (userDataMaps.isNotEmpty) {
        final Map<String, dynamic> userData = jsonDecode(
          userDataMaps.first['data'] as String,
        );
        final officerId = userData['data']['user']['id'];
        _permissions = await _dbService.getPermissionNamesByOfficer(officerId);
      }
    } catch (e) {
      debugPrint('Error loading permissions: $e');
    }
  }

  Future<void> _loadLocalData() async {
    setState(() => _isLoading = true);

    try {
      if (widget.onRefresh != null) {
        await widget.onRefresh!().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            // Silent timeout, proceed to local data
            debugPrint('Refresh timed out, falling back to local data');
          },
        );
      }
    } catch (e) {
      debugPrint('Refresh error or timeout: $e');
    }

    final db = await _dbService.database;

    // Combine locally added (pending) and server-synced products
    final List<Map<String, dynamic>> localAdded = await db.query('products');
    final List<Map<String, dynamic>> serverDownloaded = await db.query(
      'productsinfo',
    );

    final List<Map<String, dynamic>> allRawProducts = [
      ...localAdded,
      ...serverDownloaded,
    ];

    // Calculate accurate stock for each product
    final List<Map<String, dynamic>> productsWithStock = [];

    for (var product in allRawProducts) {
      final productId =
          product['server_id'] as int? ?? product['local_id'] as int;

      final int accurateStock = await _dbService.calculateProductStock(
        productId,
      );

      // Create a modifiable copy of the product map and update stock
      final Map<String, dynamic> productWithStock = Map<String, dynamic>.from(
        product,
      );
      productWithStock['current_stock'] = accurateStock;
      productsWithStock.add(productWithStock);
    }

    setState(() {
      _allLocalProducts = productsWithStock;
      _filteredProducts = productsWithStock; // Initialize filtered list
      _isLoading = false;
    });

    // Re-apply filter if search text exists
    if (_searchController.text.isNotEmpty) {
      _runFilter(_searchController.text);
    }
  }

  bool _hasPermission(String permission) => _permissions.contains(permission);

  @override
  Widget build(BuildContext context) {
    // Calculate top padding based on status bar + toolbar + search bar height
    final double topPadding =
        MediaQuery.of(context).padding.top + kToolbarHeight + 80;

    return Scaffold(
      backgroundColor: Colors.transparent, // Allow OfficerHome gradient to show
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        scrolledUnderElevation: 0,
        title: Text(
          AppLocalizations.of(context)!.inventory,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: const Color(0xFF0A1B32).withOpacity(0.5)),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_hasPermission('adding_product'))
            _buildGlassIconButton(
              icon: Icons.add_rounded,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddProductPage(),
                  ),
                );
                _loadLocalData();
              },
              tooltip: 'Add Product',
            ),
          const SizedBox(width: 8),
          _buildGlassIconButton(
            icon: Icons.refresh_rounded,
            onTap: _loadLocalData,
            tooltip: AppLocalizations.of(context)!.refreshInventory,
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: _runFilter,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchProducts,
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      body:
          _isLoading
              ? Padding(
                padding: EdgeInsets.only(top: topPadding),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: 5,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => const ProductCardSkeleton(),
                ),
              )
              : Padding(
                padding: EdgeInsets.only(top: topPadding),
                child:
                    _filteredProducts.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: _filteredProducts.length,
                          separatorBuilder:
                              (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildFinancialProductCard(
                              _filteredProducts[index],
                            );
                          },
                        ),
              ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildFinancialProductCard(Map<String, dynamic> product) {
    final double sellPrice =
        (product['selling_price'] as num?)?.toDouble() ?? 0.0;
    final double buyPrice = (product['base_price'] as num?)?.toDouble() ?? 0.0;
    final double profit = sellPrice - buyPrice;
    final double margin = buyPrice > 0 ? (profit / buyPrice) * 100 : 100.0;
    final int stock = product['current_stock'] as int? ?? 0;
    final bool isLowStock = stock <= 5 && stock > 0;
    final bool isOutOfStock = stock == 0;

    // Check if item is only on phone (pending) or on server
    final bool isPending =
        product['sync_status'] == 0 || product['server_id'] == null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isPending
                      ? Colors.orange.withOpacity(0.4)
                      : isOutOfStock
                      ? Colors.red.withOpacity(0.2)
                      : isLowStock
                      ? Colors.amber.withOpacity(0.2)
                      : Colors.white.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: isPending
                    ? Colors.orange.withOpacity(0.1)
                    : isOutOfStock
                    ? Colors.red.withOpacity(0.08)
                    : Colors.blue.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImagePlaceholder(product['name'] ?? 'P', isPending),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  product['name'] ?? 'Unnamed',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Text(
                                  'SKU: ${product['sku'] ?? 'N/A'}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white60,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isOutOfStock
                                      ? Colors.red.withOpacity(0.15)
                                      : isLowStock
                                      ? Colors.amber.withOpacity(0.15)
                                      : Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isOutOfStock
                                        ? Colors.red.withOpacity(0.3)
                                        : isLowStock
                                        ? Colors.amber.withOpacity(0.3)
                                        : Colors.green.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_rounded,
                                      size: 12,
                                      color: isOutOfStock
                                          ? Colors.red
                                          : isLowStock
                                          ? Colors.amber
                                          : Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${product['current_stock'] ?? 0}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isOutOfStock
                                            ? Colors.red
                                            : isLowStock
                                            ? Colors.amber
                                            : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Spacer(),
                              if (_hasPermission('edit_product')) ...[
                                _buildActionIcon(
                                  icon: Icons.add_box_rounded,
                                  color: Colors.amberAccent,
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                                AddStockPage(product: product),
                                      ),
                                    );
                                    if (result == true) _loadLocalData();
                                  },
                                ),
                                const SizedBox(width: 8),

                                // NEW Reduce Stock Button
                                _buildActionIcon(
                                  icon: Icons.remove_circle_rounded,
                                  color: Colors.redAccent,
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => ReduceStockPage(
                                              product: product,
                                            ),
                                      ),
                                    );
                                    if (result == true) _loadLocalData();
                                  },
                                ),
                              ],

                              // NEW Add Item Button
                              // if (_hasPermission('edit_product'))
                              //   _buildActionIcon(
                              //     icon: Icons.qr_code_2_rounded,
                              //     color: Colors.greenAccent,
                              //     onTap: () async {
                              //       await Navigator.push(
                              //         context,
                              //         MaterialPageRoute(
                              //           builder:
                              //               (_) => AddProductItemPage(
                              //                 product: product,
                              //               ),
                              //         ),
                              //       );
                              //     },
                              //   ),
                              // const SizedBox(width: 8),

                              // Existing Edit Button
                              if (_hasPermission('edit_product'))
                                _buildActionIcon(
                                  icon: Icons.edit_rounded,
                                  color: const Color(0xFF4BB4FF),
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => EditProductPage(
                                              product: product,
                                            ),
                                      ),
                                    );
                                    if (result == true) _loadLocalData();
                                  },
                                ),
                              const SizedBox(width: 8),
                              // NEW Delete Button
                              if (_hasPermission('delete_product'))
                                _buildActionIcon(
                                  icon: Icons.delete_outline_rounded,
                                  color: const Color(
                                    0xFFEF4444,
                                  ), // Red for delete
                                  onTap: () => _confirmDelete(product),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.08)),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _priceColumn(
                            AppLocalizations.of(context)!.costPrice,
                            buyPrice,
                            Colors.white60,
                          ),
                        ),
                        Container(height: 24, width: 1, color: Colors.white12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: _priceColumn(
                              AppLocalizations.of(context)!.sellingPrice,
                              sellPrice,
                              const Color(0xFF4BB4FF),
                            ),
                          ),
                        ),
                        _profitBadge(profit, margin),
                      ],
                    ),
                    if (isPending) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.cloud_off_rounded,
                              size: 14,
                              color: Colors.orangeAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.of(context)!.waitingForSync,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.orangeAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: color.withOpacity(0.1),
        splashColor: color.withOpacity(0.2),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  // Confirmation Dialog
  void _confirmDelete(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF0A1B32),
            title: Text(
              "Delete Product",
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            content: Text(
              "Are you sure you want to delete ${product['name']}? This action cannot be undone.",
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await _handleDelete(product);
                },
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _handleDelete(Map<String, dynamic> product) async {
    // 1. Prevent multiple taps during loading
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final int? serverId = product['server_id'] as int?;
      final int localId = product['local_id'] as int;
      final String productName = product['name'] ?? "Product";

      // Get Auth Token
      final token = await SyncService().getAuthToken();

      // IF SERVER ID EXISTS: Call API First
      if (serverId != null) {
        if (token == null) {
          throw Exception("Authentication token not found. Please sync first.");
        }

        try {
          // Call Backend API
          await ApiService().deleteProduct(serverId, token);
        } catch (e) {
          // If server deletion fails (e.g. stock exists), stop here and show error.
          // Do NOT delete locally if server delete fails.
          // Exception message usually comes from throw Exception(body['message']) in ApiService
          throw Exception("Server Error: $e");
        }
      }

      // IF SERVER DELETE SUCCESSFUL (OR LOCAL-ONLY): Delete Local Data
      final db = await _dbService.database;
      await db.transaction((txn) async {
        // Remove from the table where locally-added products stay before sync
        await txn.delete(
          'products',
          where: 'local_id = ?',
          whereArgs: [localId],
        );

        if (serverId != null) {
          // Remove from the table where server-synced products are stored
          await txn.delete(
            'productsinfo',
            where: 'id = ?',
            whereArgs: [serverId],
          );

          // FIFO Cleanup: Clean up stock movements to keep the local DB light
          await txn.delete(
            'stock_movements',
            where: 'product_id = ?',
            whereArgs: [serverId],
          );
        }
      });

      // 4. UI SUCCESS FEEDBACK
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$productName successfully removed"),
            backgroundColor: Colors.green,
          ),
        );
        // Reload the list to show the updated inventory
        _loadLocalData();
      }
    } catch (e) {
      debugPrint("Delete error: $e");
      String errorMessage = e.toString();
      // Clean up exception string if it starts with Exception:
      if (errorMessage.startsWith("Exception: ")) {
        errorMessage = errorMessage.substring(11);
      }
      // Clean up "Server Error: Exception: " pattern if double wrapped
      if (errorMessage.startsWith("Server Error: Exception: ")) {
        errorMessage = errorMessage.substring(23);
      } else if (errorMessage.startsWith("Server Error: ")) {
        errorMessage = errorMessage.substring(14);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // Always stop loading, even if it fails
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper for the stock warning dialog
  Future<bool?> _showStockWarning(String name, int stock) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Stock Alert"),
            content: Text(
              "Product '$name' still has $stock units in stock. Deleting it will remove all inventory records. Continue?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Delete Anyway",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  Widget _priceColumn(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            color: Colors.white38,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _currencyFormat.format(value),
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _profitBadge(double profit, double margin) {
    final bool isLoss = profit < 0;
    final Color themeColor =
        isLoss ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final Color bgColor =
        isLoss ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Icon(
                isLoss
                    ? Icons.trending_down_rounded
                    : Icons.trending_up_rounded,
                size: 14,
                color: themeColor,
              ),
              const SizedBox(width: 2),
              Text(
                '${isLoss ? "" : "+"}${margin.toStringAsFixed(1)}%',
                style: GoogleFonts.plusJakartaSans(
                  color: themeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Text(
            AppLocalizations.of(context)!.margin,
            style: GoogleFonts.plusJakartaSans(
              color: themeColor.withOpacity(0.8),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(String name, bool isPending) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              isPending
                  ? [Colors.orange.shade400, Colors.orange.shade700]
                  : [
                    const Color(0xFF4BB4FF),
                    const Color(0xFF0277BD),
                  ], // Matches app blue
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:
                isPending
                    ? Colors.orange.withOpacity(0.2)
                    : Colors.blue.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'P',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF4BB4FF).withOpacity(0.15),
                  const Color(0xFF0277BD).withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF4BB4FF).withOpacity(0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4BB4FF).withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: const Color(0xFF4BB4FF).withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            AppLocalizations.of(context)!.noLocalProductsFound,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              AppLocalizations.of(context)!.addProductsOrSync,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.white60,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
