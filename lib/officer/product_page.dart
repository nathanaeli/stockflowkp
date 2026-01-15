import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stockflowkp/l10n/app_localizations.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/services/sync_service.dart';
import 'package:stockflowkp/utils/debug_utils.dart';
import 'package:stockflowkp/utils/qr_scanner.dart';
import 'product_details_page.dart';
import 'add_product_page.dart';
import 'add_product_item_page.dart';
import 'edit_product_page.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  Map<int, int> _productStocks = {}; // Cache for stock calculations
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'name';
  int _pendingCount = 0;
  bool _isSyncing = false;
  List<String> _permissions = [];

  late AnimationController _fabController;
  late AnimationController _listAnimationController;
  final List<Animation<double>> _itemAnimations = [];
  Timer? _searchDebounceTimer;

  final SyncService _syncService = SyncService();
  final DatabaseService _dbService = DatabaseService();
  final DebugUtils _debugUtils = DebugUtils();

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadPermissions();
    _loadProducts();
  }

  @override
  void dispose() {
    _fabController.dispose();
    _listAnimationController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    try {
      final db = await _dbService.database;
      final userDataMaps = await db.query('user_data');
      if (userDataMaps.isNotEmpty) {
        final String jsonData = userDataMaps.first['data'] as String;
        final Map<String, dynamic> userData = jsonDecode(jsonData);
        final officerId = userData['data']['user']['id'];
        _permissions = await _dbService.getPermissionNamesByOfficer(officerId);
      }
    } catch (e) {
      print('Error loading permissions: $e');
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final db = await _dbService.database;
      final products = await db.query('products');

      // Get pending count
      final pendingCount = await _dbService.getPendingProductsCount();

      // Compute stocks for all products
      final stocks = <int, int>{};
      for (final product in products) {
        final localId = product['local_id'] as int;
        final serverId = product['server_id'] as int?;
        stocks[localId] = await _getTotalStock(localId, serverId);
      }

      setState(() {
        _products = products;
        _productStocks = stocks;
        _pendingCount = pendingCount;
        _applyFilterAndSort();
        _isLoading = false;
        _listAnimationController.forward(from: 0.0);
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToLoadProducts)),
        );
      }
    }
  }

  /// Sync pending products to server
  Future<void> _syncPendingProducts() async {
    if (_isSyncing) return;
    print('hellow');

    setState(() => _isSyncing = true);
    
    try {
      // Use the new sync method that a/?utomatically gets the token
      final pushResult = await _syncService.syncPendingProductsWithStoredToken();

      if (pushResult['success'] == true) {
        final syncedCount = pushResult['synced_count'] as int;
        final failedCount = pushResult['failed_count'] as int;
        
        if (mounted) {
          final localizations = AppLocalizations.of(context)!;
          
          if (syncedCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully synced $syncedCount product${syncedCount == 1 ? '' : 's'}'),
                backgroundColor: Colors.green,
              ),
            );
          }
          
          if (failedCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to sync $failedCount product${failedCount == 1 ? '' : 's'}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          
          if (syncedCount == 0 && failedCount == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(localizations.noProductsToSync)),
            );
          }
        }
      } else {
        if (mounted) {
          final localizations = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync failed: ${pushResult['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      // 2. Pull Updates (Sync with Server to handle soft deletes & updates)
      try {
        final token = await _syncService.getAuthToken();
        if (token != null) {
          final apiService = ApiService();
          // Call the sync endpoint to get updates and deleted IDs
          final response = await apiService.syncOfficerProducts(token);

          print('hellow');
          
          if (response != null) {
            // saveDashboardData handles 'products' upsert and 'deleted_product_ids' deletion
            await _dbService.saveDashboardData(response);
          }
        }
      } catch (e) {
        debugPrint('Pull sync failed: $e');
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
      await _loadProducts(); // Reload products to reflect changes (deletions/updates)
    }
  }

  Future<void> _scanBarcodeSearch() async {
    final localizations = AppLocalizations.of(context)!;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: QRCodeScanner(
            onQRCodeScanned: (code) {
              Navigator.pop(context, code);
            },
            initialMessage: localizations.scanProductBarcode,
          ),
        ),
      ),
    );

    if (result != null && result is String) {
      final cleanCode = result.trim();
      setState(() => _isLoading = true);
      try {
        final exactMatch = await _dbService.findProductByBarcodeOrSku(cleanCode);
        if (exactMatch != null) {
          setState(() {
            _searchQuery = cleanCode;
            _filteredProducts = [exactMatch];
            _isLoading = false;
          });
        } else {
          setState(() {
            _searchQuery = cleanCode;
            _applyFilterAndSort();
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _searchQuery = cleanCode;
          _applyFilterAndSort();
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilterAndSort() {
    List<Map<String, dynamic>> filtered = List.from(_products);

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return (p['name']?.toString().toLowerCase() ?? '').contains(query) ||
               (p['sku']?.toString().toLowerCase() ?? '').contains(query) ||
               (p['description']?.toString().toLowerCase() ?? '').contains(query);
      }).toList();
    }

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return (a['name'] ?? '').toString().compareTo(b['name'] ?? '');
        case 'sku':
          return (a['sku'] ?? '').toString().compareTo(b['sku'] ?? '');
        case 'price':
          final priceA = (a['selling_price'] ?? 0).toDouble();
          final priceB = (b['selling_price'] ?? 0).toDouble();
          return priceA.compareTo(priceB);
        default:
          return 0;
      }
    });

    setState(() => _filteredProducts = filtered);
  }

  /// Calculates total available stock using both local_id and server_id fallback
  Future<int> _getTotalStock(int productLocalId, int? serverId) async {
    try {
      final db = await DatabaseService().database;

      // Try server_id first (for synced products)
      List<Map<String, dynamic>> stockList = [];
      if (serverId != null) {
        stockList = await db.query(
          'stocks',
          where: 'product_id = ?',
          whereArgs: [serverId],
        );
      }

      // Fallback to local_id if no stock found
      if (stockList.isEmpty) {
        stockList = await db.query(
          'stocks',
          where: 'product_id = ?',
          whereArgs: [productLocalId],
        );
      }

      final int bulkStock = stockList.isNotEmpty ? (stockList.first['quantity'] as int? ?? 0) : 0;

      // Individual items - check both local_id and server_id to be safe
      String itemQuery = "SELECT COUNT(*) as count FROM product_items WHERE status = 'available' AND (product_id = ?";
      List<dynamic> args = [productLocalId];
      
      if (serverId != null) {
        itemQuery += " OR product_id = ?";
        args.add(serverId);
      }
      itemQuery += ")";

      final itemResult = await db.rawQuery(itemQuery, args);

      final int itemStock = itemResult.first['count'] as int;

      return bulkStock + itemStock;
    } catch (e) {
      print('Error calculating total stock: $e');
      return 0;
    }
  }

  EdgeInsets getPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width > 900) return const EdgeInsets.symmetric(horizontal: 60);
    if (width > 600) return const EdgeInsets.symmetric(horizontal: 40);
    return const EdgeInsets.symmetric(horizontal: 20);
  }

  double getImageSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width > 800) return 110;
    if (width > 500) return 95;
    return 85;
  }

  double getFontScale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width > 800) return 1.1;
    if (width < 360) return 0.9;
    return 1.0;
  }

  /// Check if user has a specific permission
  bool _hasPermission(String permission) {
    return _permissions.contains(permission);
  }

  /// NEW: Generate initials from product name
  String _getInitials(String name) {
    if (name.isEmpty) return 'P';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  /// NEW: Placeholder with first letter(s) of product name
  Widget _letterPlaceholder(double size, String productName) {
    final initials = _getInitials(productName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final padding = getPadding(context);
    final imageSize = getImageSize(context);
    final fontScale = getFontScale(context);
    final isLargeScreen = MediaQuery.sizeOf(context).width > 600;
    final bool isPushed = Navigator.canPop(context);

    final NumberFormat priceFormat = NumberFormat('#,##0', 'en_US');
    final NumberFormat qtyFormat = NumberFormat('#,##0', 'en_US');

    String formatPrice(dynamic price) {
      if (price == null) return '0';
      final num value = price is String ? num.tryParse(price) ?? 0 : price;
      return priceFormat.format(value);
    }

    String formatQuantity(int qty) {
      return '${qtyFormat.format(qty)} ${localizations.left}';
    }

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
          localizations.products,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 20 * fontScale,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
        
          // Sync button with pending count indicator
          if (_pendingCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.sync_rounded, color: Colors.white),
                  onPressed: _isSyncing ? null : _syncPendingProducts,
                  tooltip: _isSyncing ? localizations.syncing : localizations.syncPendingProducts,
                ),
                if (!_isSyncing && _pendingCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _pendingCount > 99 ? '99+' : _pendingCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: Colors.white),
            color: const Color(0xFF0A1B32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _applyFilterAndSort();
              });
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'name', child: Text(localizations.name, style: const TextStyle(color: Colors.white))),
              PopupMenuItem(value: 'sku', child: Text(localizations.sku, style: const TextStyle(color: Colors.white))),
              PopupMenuItem(value: 'price', child: Text(localizations.price, style: const TextStyle(color: Colors.white))),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E4976),
                  Color(0xFF0C223F),
                  Color(0xFF020B18),
                  Color(0xFF0A1B32),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
          SafeArea(
          child: Column(
            children: [
              Padding(
                  padding: padding.copyWith(top: 10, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.manageProducts,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 26 * fontScale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_filteredProducts.length} ${_filteredProducts.length == 1 ? localizations.item : localizations.items}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white60,
                        fontSize: 15 * fontScale,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          child: TextField(
                            onChanged: (v) {
                              _searchQuery = v;
                              _searchDebounceTimer?.cancel();
                              _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
                                _applyFilterAndSort();
                              });
                            },
                            style: TextStyle(color: Colors.white, fontSize: 15 * fontScale),
                            decoration: InputDecoration(
                              hintText: localizations.searchProducts,
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontSize: 15 * fontScale,
                              ),
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF4BB4FF)),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, color: Colors.white54),
                                      onPressed: () {
                                        setState(() {
                                          _searchQuery = '';
                                          _applyFilterAndSort();
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                          ),
                        ),
                      ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? _buildShimmer(padding)
                    : _filteredProducts.isEmpty
                        ? _buildEmptyState(fontScale, localizations)
                        : RefreshIndicator(
                            onRefresh: _loadProducts,
                            color: const Color(0xFF4BB4FF),
                            child: ListView.builder(
                              padding: padding.copyWith(top: 8, bottom: isPushed ? 120 : 100),
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                final animation = Tween<double>(
                                  begin: 0.0,
                                  end: 1.0,
                                ).animate(
                                  CurvedAnimation(
                                    parent: _listAnimationController,
                                    curve: Interval(
                                      (index * 0.1).clamp(0.0, 1.0),
                                      ((index * 0.1) + 0.5).clamp(0.0, 1.0),
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                                );
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: animation.drive(
                                      Tween<Offset>(
                                        begin: const Offset(0.0, 0.2),
                                        end: Offset.zero,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: _buildProductCard(
                                        _filteredProducts[index],
                                        imageSize,
                                        fontScale,
                                        isLargeScreen,
                                        formatPrice,
                                        formatQuantity,
                                        localizations,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
          ),
          if (isPushed) _buildFloatingActionBar(localizations),
        ],
      ),
      floatingActionButton: (isPushed || !_hasPermission('add_product')) ? null : ScaleTransition(
        scale: CurvedAnimation(parent: _fabController, curve: Curves.easeOutBack),
        child: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductPage()));
            _loadProducts();
          },
          backgroundColor: const Color(0xFF4BB4FF),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  Widget _buildFloatingActionBar(AppLocalizations localizations) {
    return Positioned(
      bottom: 35,
      left: 24,
      right: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _scanBarcodeSearch,
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                    label: Text(localizations.scan, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
               
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductPage()));
                        _loadProducts();
                      },
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      label: Text(localizations.addProduct, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4BB4FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 4,
                        shadowColor: const Color(0xFF4BB4FF).withOpacity(0.4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(
    Map<String, dynamic> product,
    double imageSize,
    double fontScale,
    bool isLarge,
    String Function(dynamic) formatPrice,
    String Function(int) formatQuantity,
    AppLocalizations localizations,
  ) {
    final bool isSynced = product['server_id'] != null;
    final String? imageUrl = product['image_url'] as String?;
    final String productName = product['name'] ?? localizations.noDescription;
    final int totalStock = _productStocks[product['local_id'] as int] ?? 0;
    final bool hasStock = totalStock > 0;
    final bool isLowStock = totalStock > 0 && totalStock <= 10;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)),
        ),
        child: Container(
          padding: EdgeInsets.all(isLarge ? 20 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                isSynced ? Colors.white.withOpacity(0.12) : Colors.orange.withOpacity(0.15),
                isSynced ? Colors.white.withOpacity(0.06) : Colors.orange.withOpacity(0.08),
                Colors.white.withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isSynced ? Colors.white.withOpacity(0.2) : Colors.orange.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isSynced ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) =>
                              progress == null ? child : _letterPlaceholder(imageSize, productName),
                          errorBuilder: (_, __, ___) => _letterPlaceholder(imageSize, productName),
                        )
                      : _letterPlaceholder(imageSize, productName),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            productName,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 17 * fontScale,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isSynced)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              localizations.local,
                              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product['description'] ?? localizations.noDescription,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 13 * fontScale),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _chip('${localizations.sku}: ${product['sku'] ?? 'N/A'}', Icons.tag),
                        _chip('TZS ${formatPrice(product['selling_price'])}', Icons.attach_money_rounded, color: const Color(0xFF4BB4FF)),
                        if (hasStock)
                          _chip(
                            formatQuantity(totalStock),
                            Icons.inventory_rounded,
                            color: isLowStock ? Colors.red : Colors.green,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  _actionButton(icon: Icons.visibility_rounded, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)));
                  }, color: Colors.white),
                  const SizedBox(height: 10),
                  if (_hasPermission('edit_product'))
                    _actionButton(icon: Icons.edit_rounded, onTap: () => _editProduct(product), color: Colors.blue),
                  if (_hasPermission('edit_product'))
                    const SizedBox(height: 10),
                  _actionButton(icon: Icons.inventory_rounded, onTap: () => _viewStock(product, localizations), color: Colors.green),
                  const SizedBox(height: 10),
                  if (_hasPermission('adding_product'))
                    _actionButton(icon: Icons.add_rounded, onTap: () => _addProductItem(product, localizations), color: Colors.blue),
                  if (_hasPermission('adding_product'))
                    const SizedBox(height: 10),
                  if (_hasPermission('delete_product'))
                    _actionButton(icon: Icons.delete_rounded, onTap: () => _deleteProduct(product, localizations), color: Colors.red),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (color ?? Colors.white).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color ?? Colors.white70),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: color ?? Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required IconData icon, required VoidCallback onTap, required Color color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildEmptyState(double fontScale, AppLocalizations localizations) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.white38),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty ? localizations.noProductsYet : localizations.noProductsFound,
            style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 18 * fontScale, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isEmpty ? localizations.tapAddFirstProduct : localizations.tryDifferentSearch,
            style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 14 * fontScale),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer(EdgeInsets padding) {
    return ListView.builder(
      padding: padding.copyWith(top: 8),
      itemCount: 7,
      itemBuilder: (_, index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.04),
              Colors.white.withOpacity(0.08),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 85,
              height: 85,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8, right: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Container(
                    height: 12,
                    width: 150,
                    margin: const EdgeInsets.only(bottom: 12, right: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        height: 10,
                        width: 60,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      Container(
                        height: 10,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (i) => Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewStock(Map<String, dynamic> product, AppLocalizations localizations) async {
    final int productLocalId = product['local_id'] as int;
    final int? serverId = product['server_id'] as int?;

    try {
      final db = await DatabaseService().database;

      List<Map<String, dynamic>> stockList = [];
      if (serverId != null) {
        stockList = await db.query('stocks', where: 'product_id = ?', whereArgs: [serverId]);
      }
      if (stockList.isEmpty) {
        stockList = await db.query('stocks', where: 'product_id = ?', whereArgs: [productLocalId]);
      }

      final int bulkQuantity = stockList.isNotEmpty ? (stockList.first['quantity'] as int? ?? 0) : 0;

      // Individual items - check both local_id and server_id to be safe
      String itemQuery = "SELECT COUNT(*) as count FROM product_items WHERE status = 'available' AND (product_id = ?";
      List<dynamic> args = [productLocalId];
      
      if (serverId != null) {
        itemQuery += " OR product_id = ?";
        args.add(serverId);
      }
      itemQuery += ")";

      final itemResult = await db.rawQuery(itemQuery, args);

      final int itemQuantity = itemResult.first['count'] as int;
      final int totalAvailable = bulkQuantity + itemQuantity;

      final NumberFormat qtyFormat = NumberFormat('#,##0', 'en_US');

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF0C223F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            '${localizations.stockInfo} - ${product['name']}',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${localizations.productType}: ${serverId != null ? localizations.online : localizations.offline}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text('${localizations.bulkStock}: ${qtyFormat.format(bulkQuantity)}', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Text('${localizations.trackedItemsAvailable}: ${qtyFormat.format(itemQuantity)}', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              Divider(color: Colors.white.withOpacity(0.3)),
              const SizedBox(height: 8),
              Text(
                '${localizations.totalAvailable}: ${qtyFormat.format(totalAvailable)}',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.close, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF4BB4FF))),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.couldNotLoadStockDetails)),
      );
    }
  }

  void _addProductItem(Map<String, dynamic> product, AppLocalizations localizations) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddProductItemPage(product: product)),
    );
  }

  /// Debug method to check user data and sync status
  Future<void> _debugSync() async {
    await DebugUtils.fullDebugReport();
    
    // Show a dialog with debug results
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.debugInformation),
          content: SingleChildScrollView(
            child: Text(
              '${AppLocalizations.of(context)!.debugInfoPrinted}\n\n'
              '${AppLocalizations.of(context)!.checkConsoleOutput}\n'
              '• ${AppLocalizations.of(context)!.userAuthDataStructure}\n'
              '• ${AppLocalizations.of(context)!.tokenLocationFormat}\n'
              '• ${AppLocalizations.of(context)!.pendingProductsStatus}\n'
              '• ${AppLocalizations.of(context)!.databaseSyncState}\n\n'
              '${AppLocalizations.of(context)!.informationHelpTroubleshoot}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.ok),
            ),
          ],
        ),
      );
    }
  }

  void _editProduct(Map<String, dynamic> product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProductPage(product: product)),
    );
    if (result == true) {
      _loadProducts();
    }
  }

  void _deleteProduct(Map<String, dynamic> product, AppLocalizations localizations) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0C223F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          localizations.deleteProduct,
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          localizations.areYouSureDeleteProduct(product['name'].toString()),
          style: GoogleFonts.plusJakartaSans(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel, style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(localizations.delete, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final db = await _dbService.database;
        await db.delete('products', where: 'local_id = ?', whereArgs: [product['local_id']]);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.productDeletedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
          _loadProducts();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.failedToDeleteProduct),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}