import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/services/sync_service.dart';
import 'package:stockflowkp/utils/qr_scanner.dart';

class CheckStockPage extends StatefulWidget {
  final String? initialBarcode;
  const CheckStockPage({super.key, this.initialBarcode});

  @override
  State<CheckStockPage> createState() => _CheckStockPageState();
}

class _CheckStockPageState extends State<CheckStockPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  bool _canAddStock = false;
  bool _canReduceStock = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    if (widget.initialBarcode != null) {
      _searchController.text = widget.initialBarcode!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchProducts(widget.initialBarcode!);
      });
    }
  }

  Future<void> _loadPermissions() async {
    try {
      final dbService = DatabaseService();
      final userData = await dbService.getUserData();
      if (userData != null) {
        final user = userData['data']['user'];
        final role = user['role'];
        
        if (role == 'tenant') {
          if (mounted) {
            setState(() {
              _canAddStock = true;
              _canReduceStock = true;
            });
          }
        } else {
          final officerId = user['id'];
          final perms = await dbService.getPermissionNamesByOfficer(officerId);
          if (mounted) {
            setState(() {
              _canAddStock = perms.contains('add_stock');
              _canReduceStock = perms.contains('reduce_stock');
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading permissions: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final products = await DatabaseService().searchProducts(query);
      
      // Debug: Log the search results
      debugPrint('Search query: "$query"');
      debugPrint('Found ${products.length} products');
      
      for (var product in products) {
        final stockDetails = await _getStockDetails(product);
        debugPrint('Product: ${product['name']}, Total Stock: ${stockDetails['total']}');
      }
      
      setState(() {
        _searchResults = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching products: $e')),
        );
      }
    }
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: QRCodeScanner(
            onQRCodeScanned: (code) {
              Navigator.pop(context, code);
            },
            initialMessage: 'Scan product barcode to check stock',
          ),
        ),
      ),
    );

    if (result != null && result is String) {
      _searchController.text = result;
      _searchProducts(result);
    }
  }

  Future<void> _showLowStockProducts() async {
    setState(() => _isLoading = true);
    
    try {
      final lowStockProducts = await DatabaseService().getLowStockProducts(threshold: 10);
      
      debugPrint('Found ${lowStockProducts.length} low stock products');
      
      setState(() {
        _searchResults = lowStockProducts;
        _hasSearched = true;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${lowStockProducts.length} low stock products'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading low stock products: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _getStockDetails(Map<String, dynamic> product) async {
    try {
      final db = await DatabaseService().database;
      final int? localId = product['local_id'] as int?;
      final int? serverId = product['server_id'] as int?;

      // Validate that we have at least one valid ID
      if (localId == null && serverId == null) {
        debugPrint('Product has no valid ID: $product');
        return {
          'bulk': 0,
          'items': 0,
          'total': 0,
          'sync_status': 1,
          'last_updated': null,
        };
      }

      // Bulk Stock - Try to get stock records
      List<Map<String, dynamic>> stockList = [];
      
      if (serverId != null) {
        stockList = await db.query('stocks', where: 'product_id = ?', whereArgs: [serverId]);
      }
      
      // If no stock found with server_id, try with local_id
      if (stockList.isEmpty && localId != null) {
        stockList = await db.query('stocks', where: 'product_id = ?', whereArgs: [localId]);
      }
      
      // Get bulk stock quantity
      final int bulkStock = stockList.isNotEmpty ? (stockList.first['quantity'] as int? ?? 0) : 0;
      
      // Get sync status and last updated
      final int syncStatus = stockList.isNotEmpty ? (stockList.first['sync_status'] as int? ?? 1) : 1;
      final String? lastUpdated = stockList.isNotEmpty ? (stockList.first['updated_at'] as String?) : null;

      // Item Stock - Count available individual items
      int itemStock = 0;
      
      if (localId != null || serverId != null) {
        String itemQuery = "SELECT COUNT(*) as count FROM product_items WHERE status = 'available' AND (";
        List<dynamic> args = [];
        
        if (localId != null) {
          itemQuery += "product_id = ?";
          args.add(localId);
        }
        
        if (serverId != null) {
          if (localId != null) {
            itemQuery += " OR ";
          }
          itemQuery += "product_id = ?";
          args.add(serverId);
        }
        
        itemQuery += ")";
        
        try {
          final itemResult = await db.rawQuery(itemQuery, args);
          itemStock = itemResult.first['count'] as int? ?? 0;
        } catch (e) {
          debugPrint('Error querying product items: $e');
          itemStock = 0;
        }
      }

      final int totalStock = bulkStock + itemStock;
      
      debugPrint('Stock details for ${product['name']}: bulk=$bulkStock, items=$itemStock, total=$totalStock');

      return {
        'bulk': bulkStock,
        'items': itemStock,
        'total': totalStock,
        'sync_status': syncStatus,
        'last_updated': lastUpdated,
      };
    } catch (e, stack) {
      debugPrint('Error getting stock details: $e\n$stack');
      // Return default values on error
      return {
        'bulk': 0,
        'items': 0,
        'total': 0,
        'sync_status': 1,
        'last_updated': null,
      };
    }
  }

  Future<void> _syncStock(Map<String, dynamic> product) async {
    setState(() => _isLoading = true);
    try {
      final syncService = SyncService();
      final token = await syncService.getAuthToken();
      
      if (token != null) {
        final db = await DatabaseService().database;
        final int localId = product['local_id'];
        final int? serverId = product['server_id'];
        
        if (serverId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product must be synced first'), backgroundColor: Colors.orange),
            );
          }
          return;
        }

        // Get stock record from stocks table
        final stockList = await db.query('stocks', 
          where: 'product_id = ? OR product_id = ?',
          whereArgs: [serverId, localId],
          limit: 1
        );

        if (stockList.isEmpty) {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('No stock record found'), backgroundColor: Colors.orange),
             );
           }
           return;
        }

        final stock = stockList.first;
        final int quantity = stock['quantity'] as int;

        if (quantity <= 0) {
           if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cannot sync: Quantity must be positive to add stock'), backgroundColor: Colors.orange),
            );
           }
           return;
        }

        // Call API to add stock
        final response = await ApiService().addStock({
          'product_id': serverId,
          'quantity': quantity,
          'reason': 'Manual sync',
        }, token);

        if (response['success'] == true) {
          final serverStock = response['data']['stock'];

          // Update local stock to match server info
          await db.update('stocks', 
            {
              'quantity': serverStock['new_quantity'],
              'server_id': serverStock['id'],
              'sync_status': 1, 
              'updated_at': serverStock['updated_at'] ?? DateTime.now().toIso8601String()
            }, 
            where: 'local_id = ?', 
            whereArgs: [stock['local_id']]
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Stock added successfully'), backgroundColor: Colors.green),
            );
            setState(() {}); 
          }
        } else {
           if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Sync failed: ${response['message']}'), backgroundColor: Colors.red),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _adjustStock(Map<String, dynamic> product, int quantityChange, String reason, bool isAdding) async {
    // Show loading indicator
    setState(() => _isLoading = true);

    try {
      // 1. Adjust stock locally first
      await DatabaseService().adjustStock(product, quantityChange, reason);

      // Show success message for local update
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock updated locally.'), backgroundColor: Colors.green),
        );
        setState((){}); // Refresh the list
      }

      // 2. Check for internet connection
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.contains(ConnectivityResult.none)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No internet connection. Changes will sync later.'), backgroundColor: Colors.orange),
          );
        }
        return; // Exit if no connection
      }

      // 3. Attempt to sync with the server
      final syncService = SyncService();
      final token = await syncService.getAuthToken();
      final int? serverId = product['server_id'];
      final int? dukaId = product['duka_id'];

      if (token == null || serverId == null || dukaId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot sync now. Missing required info (token, serverId, or dukaId).'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final apiService = ApiService();
      try {
        final response = await apiService.updateStock({
          'product_id': serverId,
          'duka_id': dukaId,
          'quantity_change': quantityChange.abs(), // API expects positive integer
          'operation': isAdding ? 'add' : 'reduce',
          'reason': reason,
        }, token);

        if (response['success'] == true) {
          // If server sync is successful, update local stock record to be 'synced'
          final db = await DatabaseService().database;
          final serverStock = response['data']['stock'];

          // Find the local stock record again to update it
           List<Map<String, dynamic>> stocks = await db.query('stocks', where: 'product_id = ? OR product_id = ?', whereArgs: [serverId, product['local_id']]);
          
          if(stocks.isNotEmpty){
             await db.update(
                'stocks',
                {
                  'quantity': serverStock['new_quantity'],
                  'sync_status': 1, // Mark as synced
                  'updated_at': serverStock['updated_at'] ?? DateTime.now().toIso8601String(),
                },
                where: 'local_id = ?',
                whereArgs: [stocks.first['local_id']]);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Stock successfully synced with server.'), backgroundColor: Colors.green),
            );
          }
        } else {
          throw Exception(response['message'] ?? 'Unknown error during sync');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sync failed: $e. Will retry later.'), backgroundColor: Colors.red),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adjusting stock: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Hide loading indicator
      if (mounted) setState(() => _isLoading = false);
      // Refresh list to show updated stock info
      setState(() {});
    }
  }

  Future<void> _showAdjustStockDialog(Map<String, dynamic> product, int currentBulk) async {
    if (!_canAddStock && !_canReduceStock) return;

    final qtyController = TextEditingController();
    final reasonController = TextEditingController();
    bool isAdding = _canAddStock;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0A1B32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Adjust Stock', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? 'Unknown Product',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current Bulk Stock: $currentBulk',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (_canAddStock)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setStateDialog(() => isAdding = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isAdding ? const Color(0xFF4BB4FF).withOpacity(0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isAdding ? const Color(0xFF4BB4FF) : Colors.white24),
                          ),
                          child: Center(
                            child: Text('Add (+)', style: GoogleFonts.plusJakartaSans(color: isAdding ? const Color(0xFF4BB4FF) : Colors.white54, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                    if (_canAddStock && _canReduceStock)
                    const SizedBox(width: 10),
                    if (_canReduceStock)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setStateDialog(() => isAdding = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isAdding ? Colors.redAccent.withOpacity(0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: !isAdding ? Colors.redAccent : Colors.white24),
                          ),
                          child: Center(
                            child: Text('Remove (-)', style: GoogleFonts.plusJakartaSans(color: !isAdding ? Colors.redAccent : Colors.white54, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Reason (Optional)',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final qty = int.tryParse(qtyController.text) ?? 0;
                  if (qty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a positive quantity.'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  // Close the dialog first
                  Navigator.pop(context);

                  final change = isAdding ? qty : -qty;
                  final reason = reasonController.text.trim().isEmpty 
                      ? (isAdding ? 'Manual Addition' : 'Manual Reduction') 
                      : reasonController.text.trim();

                  // Call the new central method
                  await _adjustStock(product, change, reason, isAdding);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4BB4FF),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Check Stock',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Search product or scan...',
                                      hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white54),
                                      border: InputBorder.none,
                                      icon: const Icon(Icons.search, color: Colors.white54),
                                      suffixIcon: _searchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, color: Colors.white54),
                                              onPressed: () {
                                                _searchController.clear();
                                                _searchProducts('');
                                              },
                                            )
                                          : null,
                                    ),
                                    onSubmitted: _searchProducts,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: _scanBarcode,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4BB4FF).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF4BB4FF).withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF4BB4FF)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Low Stock Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showLowStockProducts,
                          icon: const Icon(Icons.warning_rounded, size: 18),
                          label: const Text('View Low Stock Products'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.withOpacity(0.2),
                            foregroundColor: Colors.orange,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.orange.withOpacity(0.3)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF4BB4FF)))
                      : _searchResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _hasSearched ? Icons.search_off_rounded : Icons.inventory_2_outlined,
                                    size: 64,
                                    color: Colors.white24,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _hasSearched ? 'No products found' : 'Search or scan to check stock',
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 16),
                                  ),
                                  if (_hasSearched) ...[
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        if (_searchController.text.isEmpty) {
                                          _showLowStockProducts();
                                        } else {
                                          _searchProducts(_searchController.text);
                                        }
                                      },
                                      icon: const Icon(Icons.refresh_rounded, size: 18),
                                      label: const Text('Try Again'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white.withOpacity(0.1),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () async {
                                if (_searchController.text.isEmpty) {
                                  await _showLowStockProducts();
                                } else {
                                  await _searchProducts(_searchController.text);
                                }
                              },
                              color: const Color(0xFF4BB4FF),
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final product = _searchResults[index];
                                  return _buildStockCard(product);
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard(Map<String, dynamic> product) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getStockDetails(product),
      builder: (context, snapshot) {
        final stock = snapshot.data ?? {'bulk': 0, 'items': 0, 'total': 0, 'sync_status': 1};
        final total = stock['total'] as int;
        final isLowStock = total <= 10;
        final isSynced = stock['sync_status'] == 1;
        final lastUpdated = stock['last_updated'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: product['image_url'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              product['image_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  (product['name'] ?? 'P')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              (product['name'] ?? 'P')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'] ?? 'Unknown',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SKU: ${product['sku'] ?? 'N/A'}',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isLowStock ? Colors.red : Colors.green).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isLowStock ? 'LOW STOCK' : 'IN STOCK',
                          style: GoogleFonts.plusJakartaSans(
                            color: isLowStock ? Colors.red : Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!isSynced) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _syncStock(product),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cloud_upload_rounded, color: Colors.orange, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'Unsynced (Tap to push)',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (lastUpdated != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Updated: ${DateFormat('MMM d, HH:mm').format(DateTime.parse(lastUpdated))}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStockInfo('Total', total.toString(), isLowStock ? Colors.redAccent : Colors.white),
                    Container(width: 1, height: 30, color: Colors.white10),
                    _buildStockInfo('Bulk', stock['bulk'].toString(), Colors.blueAccent),
                    Container(width: 1, height: 30, color: Colors.white10),
                    _buildStockInfo('Items', stock['items'].toString(), Colors.orangeAccent),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_canAddStock || _canReduceStock)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAdjustStockDialog(product, stock['bulk'] as int),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Adjust Stock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStockInfo(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
