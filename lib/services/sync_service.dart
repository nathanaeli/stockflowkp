import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import 'api_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseService _dbService = DatabaseService();

  // Sync status constants
  static const int statusPending = 0;
  static const int statusSynced = 1;
  static const int statusFailed = 2;

  Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  /// Sync all pending products to the server with comprehensive error handling
  Future<Map<String, dynamic>> syncPendingProducts(String token) async {
    final db = await _dbService.database;

    try {
      // Get all pending products (local only, not synced)
      final pendingProducts = await db.query(
        'products',
        where: 'sync_status = ?',
        whereArgs: [statusPending],
      );

      if (pendingProducts.isEmpty) {
        return {
          'success': true,
          'message': 'No pending products to sync',
          'synced_count': 0,
          'failed_count': 0,
        };
      }

      int syncedCount = 0;
      int failedCount = 0;
      List<String> errors = [];
      bool abortSync = false;

      print(
        '🔄 Starting sync for ${pendingProducts.length} pending products...',
      );

      for (var product in pendingProducts) {
        if (abortSync) {
          failedCount++;
          continue;
        }

        try {
          final result = await _syncSingleProduct(product, token);
          if (result['success']) {
            syncedCount++;
            print('✅ Successfully synced product: ${product['name']}');
          } else {
            failedCount++;
            final error = result['error'] ?? 'Unknown error';
            errors.add('Failed to sync product ${product['name']}: $error');
            print('❌ Failed to sync product ${product['name']}: $error');

            // Handle specific error types
            if (result['authentication_error'] == true) {
              abortSync = true;
              errors.add('Authentication failed. Aborting remaining syncs.');
            } else if (result['validation_errors'] != null) {
              // Mark as permanently failed to prevent infinite retry loops
              await db.update(
                'products',
                {'sync_status': statusFailed},
                where: 'local_id = ?',
                whereArgs: [product['local_id']],
              );
              print(
                '⚠️ Marked ${product['name']} as failed (validation error)',
              );
            }
          }
        } catch (e) {
          failedCount++;
          final errorMsg = 'Exception syncing ${product['name']}: $e';
          errors.add(errorMsg);
          print('💥 $errorMsg');
        }
      }

      final success = failedCount == 0;
      final message =
          success
              ? 'All $syncedCount products synced successfully'
              : '$syncedCount products synced, $failedCount failed';

      print('📊 Sync completed: $message');

      return {
        'success': success,
        'message': message,
        'synced_count': syncedCount,
        'failed_count': failedCount,
        'errors': errors,
      };
    } catch (e) {
      final errorMsg = 'Sync operation failed: $e';
      print('💥 $errorMsg');
      return {
        'success': false,
        'message': errorMsg,
        'synced_count': 0,
        'failed_count': 0,
        'errors': [e.toString()],
      };
    }
  }

  /// Sync a single product to the server with improved error handling
  Future<Map<String, dynamic>> _syncSingleProduct(
    Map<String, dynamic> product,
    String token,
  ) async {
    try {
      print('🔄 Syncing product: ${product['name']}');

      // Prepare complete product data for API
      final productData = _prepareProductForApi(product);

      print('📦 Product data prepared: ${productData.toString()}');

      // Check for local image
      final String? localImagePath = product['image'];
      final bool hasLocalImage =
          localImagePath != null && File(localImagePath).existsSync();

      http.Response? mpResponse;

      if (hasLocalImage) {
        try {
          print('📸 Uploading with local image: $localImagePath');
          var request = http.MultipartRequest(
            'POST',
            Uri.parse('${ApiService.baseUrl}/api/officer/products'),
          );

          request.headers.addAll({
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          });

          // Remove image_url to avoid conflict with file upload (API requires only one)
          productData.remove('image_url');

          // Add fields
          productData.forEach((key, value) {
            if (value != null) {
              // Convert boolean to 1/0 for consistency in multipart, or string for others
              if (value is bool) {
                request.fields[key] = value ? '1' : '0';
              } else {
                request.fields[key] = value.toString();
              }
            }
          });

          // Add file (assuming server expects field 'image')
          request.files.add(
            await http.MultipartFile.fromPath('image', localImagePath),
          );

          var streamedResponse = await request.send();
          mpResponse = await http.Response.fromStream(streamedResponse);

          if (mpResponse.statusCode != 201) {
            print(
              '⚠️ Image upload failed (${mpResponse.statusCode}). Falling back to data-only sync.',
            );
            mpResponse = null; // Trigger fallback
          }
        } catch (e) {
          print(
            '⚠️ Image upload exception: $e. Falling back to data-only sync.',
          );
          mpResponse = null;
        }
      }

      http.Response response;
      if (mpResponse != null) {
        response = mpResponse;
      } else {
        // Restore image_url if it was removed or missing
        if (!productData.containsKey('image_url')) {
          productData['image_url'] =
              product['image_url'] ?? 'https://via.placeholder.com/150';
        }

        // Standard JSON upload if no image or fallback
        response = await http.post(
          Uri.parse('${ApiService.baseUrl}/api/officer/products'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(productData),
        );
      }

      print('📡 HTTP Response: ${response.statusCode} - ${response.body}');

      // Handle successful product creation
      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final serverProduct = responseData['data']['product'];
          final serverId = serverProduct['id'] as int;

          print('✅ Product created successfully with server ID: $serverId');

          // Update local product with server ID and sync status
          final db = await _dbService.database;
          await db.update(
            'products',
            {
              'server_id': serverId,
              'sync_status': statusSynced,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'local_id = ?',
            whereArgs: [product['local_id']],
          );

          // Handle stock and product items based on API response
          await _handleProductStockAndItems(serverProduct, product, token);

          return {
            'success': true,
            'message': 'Product synced successfully',
            'server_id': serverId,
          };
        } else {
          final errorMsg = responseData['message'] ?? 'Unknown API error';
          print('❌ API returned error: $errorMsg');
          return {
            'success': false,
            'error': errorMsg,
            'api_response': responseData,
          };
        }
      }

      // Handle validation errors (422)
      if (response.statusCode == 422) {
        final responseData = jsonDecode(response.body);
        final errors = responseData['errors'] ?? {};
        final errorMsg = responseData['message'] ?? 'Validation failed';
        print('❌ Validation error: $errorMsg');
        print('📋 Validation errors: $errors');

        return {
          'success': false,
          'error': '$errorMsg. Details: $errors',
          'validation_errors': errors,
        };
      }

      // Handle authentication errors (403, 401)
      if (response.statusCode == 403 || response.statusCode == 401) {
        final responseData = jsonDecode(response.body);
        final errorMsg = responseData['message'] ?? 'Authentication failed';
        print('🔐 Authentication error: $errorMsg');

        return {
          'success': false,
          'error': errorMsg,
          'authentication_error': true,
        };
      }

      // Handle other HTTP errors
      if (response.statusCode >= 400) {
        final responseData = jsonDecode(response.body);
        final errorMsg =
            responseData['message'] ?? 'HTTP Error ${response.statusCode}';
        print('❌ HTTP Error ${response.statusCode}: $errorMsg');

        return {
          'success': false,
          'error': errorMsg,
          'http_status': response.statusCode,
          'api_response': responseData,
        };
      }

      // Handle unexpected status codes
      final errorMsg = 'Unexpected response code: ${response.statusCode}';
      print('⚠️ $errorMsg');

      return {
        'success': false,
        'error': errorMsg,
        'http_status': response.statusCode,
        'response_body': response.body,
      };
    } catch (e) {
      final errorMsg = 'Exception during sync: $e';
      print('💥 $errorMsg');

      return {'success': false, 'error': errorMsg, 'exception': true};
    }
  }

  /// Handle stock and product items after successful product creation
  Future<void> _handleProductStockAndItems(
    Map<String, dynamic> serverProduct,
    Map<String, dynamic> localProduct,
    String token,
  ) async {
    try {
      final initialStock =
          int.tryParse(localProduct['initial_stock']?.toString() ?? '0') ?? 0;
      final trackItems = serverProduct['track_items'] as bool? ?? false;

      print('📦 Handling stock and items:');
      print('   Initial stock: $initialStock');
      print('   Track items: $trackItems');

      if (initialStock > 0) {
        // Add stock using the addStock API
        try {
          final stockResponse = await ApiService().addStock({
            'product_id': serverProduct['id'],
            'quantity': initialStock,
            'reason': 'Initial stock from sync',
          }, token);

          if (stockResponse['success'] == true) {
            print('✅ Stock added successfully: $initialStock units');
          } else {
            print('⚠️ Failed to add stock: ${stockResponse['message']}');
          }
        } catch (e) {
          print('⚠️ Error adding stock: $e');
        }

        // Handle product items if tracking is enabled
        if (trackItems) {
          print('📦 Creating individual product items: $initialStock');
          final apiService = ApiService();
          for (int i = 1; i <= initialStock; i++) {
            try {
              final itemResponse = await apiService.createProductItem({
                'product_id': serverProduct['id'],
                'qr_code':
                    '${serverProduct['sku']}-${i.toString().padLeft(4, '0')}',
                'status': 'available',
              }, token);

              if (itemResponse['success'] == true) {
                print('✅ Created product item $i');
              } else {
                print(
                  '⚠️ Failed to create item $i: ${itemResponse['message']}',
                );
              }
            } catch (e) {
              print('⚠️ Error creating item $i: $e');
            }
          }
        }
      } else {
        print('ℹ️ No initial stock to handle');
      }

      // Update local product with additional server data
      final db = await _dbService.database;
      await db.update(
        'products',
        {
          'server_sku': serverProduct['sku'],
          'server_image_url': serverProduct['image_url'],
          'sync_status': statusSynced,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'local_id = ?',
        whereArgs: [localProduct['local_id']],
      );
    } catch (e) {
      print('⚠️ Error handling stock and items: $e');
      // Don't throw here as the main product sync was successful
    }
  }

  /// Prepare complete product data for API submission following Laravel API requirements
  Map<String, dynamic> _prepareProductForApi(Map<String, dynamic> product) {
    // Ensure unit is lowercase as required by the API
    final unit = (product['unit'] as String?)?.toLowerCase() ?? 'pcs';

    // Get officer's duka assignment for the product
    final dukaId = product['duka_id'] ?? _getDefaultDukaId();

    final productData = {
      'name': product['name'],
      'description': product['description'] ?? '',
      'unit': unit,
      'buying_price':
          double.tryParse(product['base_price']?.toString() ?? '0') ?? 0.0,
      'selling_price':
          double.tryParse(product['selling_price']?.toString() ?? '0') ?? 0.0,
      'category_name': product['category_name'] ?? 'General',
      'duka_id': dukaId,
      // Remove initial_stock from product creation, will add stock separately
      'track_items':
          product['track_items'] == 1 || product['track_items'] == true,
      'barcode': product['barcode'],
      // Provide a default placeholder image URL when no image is available
      'image_url': product['image_url'] ?? 'https://via/placeholder.com/150',
    };

    print('📋 Prepared product data: $productData');
    return productData;
  }

  /// Get default duka ID for officer (placeholder implementation)
  Future<int?> _getDefaultDukaId() async {
    try {
      final db = await _dbService.database;
      final officerData = await db.query('user_data');

      if (officerData.isEmpty) {
        print('⚠️ No user data found for duka assignment');
        return null;
      }

      final userData = jsonDecode(officerData.first['data'] as String);
      final officerId = userData['data']['user']['id'];

      // Get officer's assignments
      final assignments = await db.query(
        'officer',
        where: 'server_id = ?',
        whereArgs: [officerId],
      );

      if (assignments.isNotEmpty) {
        final dukaId = assignments.first['duka_id'];
        print('🏪 Using duka ID: $dukaId');
        return dukaId as int?;
      }

      print('⚠️ No duka assignment found for officer');
      return null;
    } catch (e) {
      print('⚠️ Error getting default duka ID: $e');
      return null;
    }
  }

  /// Get count of pending products
  Future<int> getPendingProductCount() async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE sync_status = ?',
      [statusPending],
    );
    return result.first['count'] as int;
  }

  /// Get sync status summary
  Future<Map<String, int>> getSyncStatusSummary() async {
    final db = await _dbService.database;

    final pendingResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE sync_status = ?',
      [statusPending],
    );

    final syncedResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE sync_status = ?',
      [statusSynced],
    );

    return {
      'pending': pendingResult.first['count'] as int,
      'synced': syncedResult.first['count'] as int,
      'total':
          (pendingResult.first['count'] as int) +
          (syncedResult.first['count'] as int),
    };
  }

  /// Force sync a specific product by local_id
  Future<Map<String, dynamic>> syncSpecificProduct(
    int localProductId,
    String token,
  ) async {
    final db = await _dbService.database;

    final products = await db.query(
      'products',
      where: 'local_id = ? AND sync_status = ?',
      whereArgs: [localProductId, statusPending],
    );

    if (products.isEmpty) {
      return {
        'success': false,
        'message': 'Product not found or already synced',
      };
    }

    final product = products.first;
    final result = await _syncSingleProduct(product, token);

    return {
      'success': result['success'] ?? false,
      'message':
          (result['success'] ?? false)
              ? 'Product synced successfully'
              : (result['error'] ?? 'Failed to sync product'),
      'product_name': product['name'],
      'error': result['error'],
    };
  }

  /// Clean up failed sync attempts (optional utility)
  Future<void> cleanupFailedSyncs() async {
    final db = await _dbService.database;

    // Mark products that have failed multiple times for manual review
    final failedProducts = await db.query(
      'products',
      where: 'sync_status = ?',
      whereArgs: [statusFailed],
    );

    if (failedProducts.isNotEmpty) {
      print('🧹 Found ${failedProducts.length} failed products for cleanup');
      // You might want to implement logic here to handle products that have failed to sync
      // multiple times, such as marking them for manual review or retry
    }

    print('Cleanup completed');
  }

  /// Comprehensive sync for all pending data (products, stock, product items)
  Future<Map<String, dynamic>> syncAllPendingData(String token) async {
    print('🚀 Starting comprehensive sync of all pending data...');

    final results = {
      'products': await syncPendingProducts(token),
      'product_items': await syncPendingProductItems(token),
      'stock_movements': await syncPendingStockMovements(token),
    };

    // Calculate overall success with null safety
    final productsResult = results['products'] as Map<String, dynamic>? ?? {};
    final itemsResult = results['product_items'] as Map<String, dynamic>? ?? {};
    final stockResult =
        results['stock_movements'] as Map<String, dynamic>? ?? {};

    final allProductsSuccess = productsResult['success'] as bool? ?? false;
    final allItemsSuccess = itemsResult['success'] as bool? ?? false;
    final allStockSuccess = stockResult['success'] as bool? ?? false;

    final overallSuccess =
        allProductsSuccess && allItemsSuccess && allStockSuccess;

    final totalSynced =
        (productsResult['synced_count'] as int? ?? 0) +
        (itemsResult['synced_count'] as int? ?? 0) +
        (stockResult['synced_count'] as int? ?? 0);

    final totalFailed =
        (productsResult['failed_count'] as int? ?? 0) +
        (itemsResult['failed_count'] as int? ?? 0) +
        (stockResult['failed_count'] as int? ?? 0);

    print('📊 Comprehensive sync completed:');
    print('   Total synced: $totalSynced');
    print('   Total failed: $totalFailed');
    print('   Overall success: $overallSuccess');

    return {
      'success': overallSuccess,
      'message':
          overallSuccess
              ? 'All pending data synced successfully'
              : 'Some data failed to sync',
      'results': results,
      'summary': {'total_synced': totalSynced, 'total_failed': totalFailed},
    };
  }

  /// Sync pending product items (individual items with QR codes)
  Future<Map<String, dynamic>> syncPendingProductItems(String token) async {
    final db = await _dbService.database;

    try {
      final pendingItems = await db.query(
        'product_items',
        where: 'sync_status = ?',
        whereArgs: [statusPending],
      );

      if (pendingItems.isEmpty) {
        return {
          'success': true,
          'message': 'No pending product items to sync',
          'synced_count': 0,
          'failed_count': 0,
        };
      }

      int syncedCount = 0;
      int failedCount = 0;
      List<String> errors = [];

      print('🔄 Syncing ${pendingItems.length} pending product items...');

      for (var item in pendingItems) {
        try {
          final success = await _syncSingleProductItem(item, token);
          if (success) {
            syncedCount++;
            print('✅ Synced product item: ${item['qr_code']}');
          } else {
            failedCount++;
            errors.add('Failed to sync item: ${item['qr_code']}');
          }
        } catch (e) {
          failedCount++;
          errors.add('Error syncing item ${item['qr_code']}: $e');
        }
      }

      return {
        'success': failedCount == 0,
        'message':
            failedCount == 0
                ? 'All product items synced successfully'
                : 'Some product items failed to sync',
        'synced_count': syncedCount,
        'failed_count': failedCount,
        'errors': errors,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Product items sync failed: $e',
        'synced_count': 0,
        'failed_count': 0,
        'errors': [e.toString()],
      };
    }
  }

  /// Sync a single product item
  Future<bool> _syncSingleProductItem(
    Map<String, dynamic> item,
    String token,
  ) async {
    try {
      print('📦 Syncing product item: ${item['qr_code']}');

      final db = await _dbService.database;

      // 1. Resolve Product Server ID and Duka ID
      final productRes = await db.query(
        'products',
        columns: ['server_id', 'duka_id'],
        where: 'local_id = ?',
        whereArgs: [item['product_id']],
      );

      if (productRes.isEmpty) return false;

      final productServerId = productRes.first['server_id'] as int?;
      var dukaId = productRes.first['duka_id'] as int?;

      if (productServerId == null) {
        print('⏳ Parent product not synced yet for item ${item['local_id']}');
        return false;
      }

      // If duka_id is missing on product, try to get default from officer assignments
      if (dukaId == null) {
        dukaId = await _getDefaultDukaId();
      }

      if (dukaId == null) {
        print('❌ Missing duka_id for item sync');
        return false;
      }

      // 2. Call API
      final response = await ApiService().createProductItem({
        'product_id': productServerId,
        'duka_id': dukaId,
        'qr_code': item['qr_code'],
        'status': item['status'] ?? 'available',
      }, token);

      if (response['success'] == true) {
        // 3. Update local record with server_id
        await db.update(
          'product_items',
          {
            'server_id': response['data']['id'],
            'sync_status': statusSynced,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'local_id = ?',
          whereArgs: [item['local_id']],
        );
        return true;
      }
      return false;
    } catch (e) {
      print('💥 Error syncing product item: $e');
      return false;
    }
  }

  /// Syncs items for a specific product: pulls from server, then pushes pending.
  Future<void> syncProductItemsForProduct(
    int productServerId,
    int productLocalId,
  ) async {
    final token = await getAuthToken();
    if (token == null) {
      print('Cannot sync product items, no token.');
      return;
    }

    try {
      // 1. Pull from server
      final apiService = ApiService();
      final response = await apiService.getProductItemsByProductId(
        productServerId,
        token,
      );

      if (response['success'] == true && response['data'] != null) {
        final items = response['data'] as List;
        if (items.isNotEmpty) {
          await _dbService.saveSyncedProductItems(items, productLocalId);
          print(
            '✅ Pulled and saved ${items.length} items for product $productLocalId',
          );
        }
      }

      // 2. Push pending items for this product
      final db = await _dbService.database;
      final pendingItems = await db.query(
        'product_items',
        where: 'product_id = ? AND sync_status = ?',
        whereArgs: [productLocalId, statusPending],
      );

      if (pendingItems.isNotEmpty) {
        print(
          '🔄 Pushing ${pendingItems.length} pending items for product $productLocalId',
        );
        for (var item in pendingItems) {
          await _syncSingleProductItem(item, token);
        }
      }
    } catch (e) {
      print(
        '💥 Error during product items sync for product $productLocalId: $e',
      );
    }
  }

  /// Force sync a specific product item by local_id
  Future<Map<String, dynamic>> syncSpecificProductItem(
    int localItemId,
    String token,
  ) async {
    final db = await _dbService.database;

    final items = await db.query(
      'product_items',
      where: 'local_id = ? AND sync_status = ?',
      whereArgs: [localItemId, statusPending],
    );

    if (items.isEmpty) {
      return {'success': false, 'message': 'Item not found or already synced'};
    }

    final item = items.first;
    final success = await _syncSingleProductItem(item, token);

    return {
      'success': success,
      'message':
          success
              ? 'Product item synced successfully'
              : 'Failed to sync product item',
    };
  }

  /// Sync pending stock movements
  Future<Map<String, dynamic>> syncPendingStockMovements(String token) async {
    final db = await _dbService.database;

    try {
      final pendingMovements = await db.query(
        'stock_movements',
        where: 'sync_status = ?',
        whereArgs: [statusPending],
      );

      if (pendingMovements.isEmpty) {
        return {
          'success': true,
          'message': 'No pending stock movements to sync',
          'synced_count': 0,
          'failed_count': 0,
        };
      }

      int syncedCount = 0;
      int failedCount = 0;
      List<String> errors = [];

      print('🔄 Syncing ${pendingMovements.length} pending stock movements...');

      for (var movement in pendingMovements) {
        try {
          final success = await _syncSingleStockMovement(movement, token);
          if (success) {
            syncedCount++;
            print('✅ Synced stock movement: ${movement['id']}');
          } else {
            failedCount++;
            errors.add('Failed to sync movement: ${movement['id']}');
          }
        } catch (e) {
          failedCount++;
          errors.add('Error syncing movement ${movement['id']}: $e');
        }
      }

      return {
        'success': failedCount == 0,
        'message':
            failedCount == 0
                ? 'All stock movements synced successfully'
                : 'Some stock movements failed to sync',
        'synced_count': syncedCount,
        'failed_count': failedCount,
        'errors': errors,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Stock movements sync failed: $e',
        'synced_count': 0,
        'failed_count': 0,
        'errors': [e.toString()],
      };
    }
  }

  /// Sync a single stock movement
  Future<bool> _syncSingleStockMovement(
    Map<String, dynamic> movement,
    String token,
  ) async {
    try {
      print('📊 Syncing stock movement: ${movement['local_id']}');

      final db = await _dbService.database;
      final movementProductId = movement['product_id'] as int;

      // Resolve Product Server ID
      // The movement might store local_id or server_id. We need to find the product.

      // 1. Try assuming it's a local_id
      var productRes = await db.query(
        'products',
        columns: ['server_id'],
        where: 'local_id = ?',
        whereArgs: [movementProductId],
      );

      int? productServerId;

      if (productRes.isNotEmpty) {
        productServerId = productRes.first['server_id'] as int?;
      } else {
        // 2. Try assuming it's a server_id (product might be fully synced)
        productRes = await db.query(
          'products',
          columns: ['server_id'],
          where: 'server_id = ?',
          whereArgs: [movementProductId],
        );
        if (productRes.isNotEmpty) {
          productServerId = productRes.first['server_id'] as int?;
        }
      }

      if (productServerId == null) {
        print(
          '⏳ Parent product not synced yet for movement ${movement['local_id']}',
        );
        return false;
      }

      final int quantity = movement['quantity'] as int;

      // Determine duka_id (fallback to default if missing)
      final int dukaId = movement['duka_id'] ?? await _getDefaultDukaId();

      if (quantity > 0) {
        // ADD STOCK
        final response = await ApiService().addStock({
          'product_id': productServerId,
          'duka_id': dukaId,
          'quantity': quantity,
          'reason': movement['reason'],
        }, token);

        print("/////.........................................");
        print(response);

        if (response['success'] == true) {
          await db.update(
            'stock_movements',
            {
              'sync_status': statusSynced,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'local_id = ?',
            whereArgs: [movement['local_id']],
          );
          return true;
        }
      } else if (quantity < 0) {
        // REDUCE STOCK
        final int quantityToReduce = quantity.abs();

        // Parse reason string "type: notes" or just use as notes
        String reductionType = 'other';
        String notes = '';
        final String reasonStr = movement['reason'] ?? '';

        if (reasonStr.contains(':')) {
          final parts = reasonStr.split(':');
          reductionType = parts[0].trim();
          notes = parts.sublist(1).join(':').trim();
        } else {
          reductionType = 'other';
          notes = reasonStr;
        }

        final response = await ApiService().reduceStock({
          'product_id': productServerId,
          'duka_id': dukaId,
          'quantity': quantityToReduce,
          'type': reductionType, // API expects 'type' field for reason code
          'notes': notes,
        }, token);

        print("///// Reducing Stock Response ....................");
        print(response);

        if (response['success'] == true) {
          await db.update(
            'stock_movements',
            {
              'sync_status': statusSynced,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'local_id = ?',
            whereArgs: [movement['local_id']],
          );
          return true;
        }
      } else {
        // Quantity is 0, nothing to do
        return true;
      }

      return false;
    } catch (e) {
      print('💥 Error syncing stock movement: $e');
      return false;
    }
  }

  /// Get authentication token from stored user data
  Future<String?> getAuthToken() async {
    try {
      final db = await _dbService.database;
      final userDataMaps = await db.query('user_data');

      if (userDataMaps.isEmpty) {
        print('No user data found in database');
        return null;
      }

      final String jsonData = userDataMaps.first['data'] as String;
      final Map<String, dynamic> userData = jsonDecode(jsonData);

      // Try different possible token locations
      String? token;

      if (userData['token'] != null) {
        token = userData['token'] as String;
      } else if (userData['data'] != null &&
          userData['data']['token'] != null) {
        token = userData['data']['token'] as String;
      } else if (userData['access_token'] != null) {
        token = userData['access_token'] as String;
      } else if (userData['data'] != null &&
          userData['data']['access_token'] != null) {
        token = userData['data']['access_token'] as String;
      }

      if (token == null || token.isEmpty) {
        print('No valid token found in user data');
        print('User data structure: $userData');
      }

      return token;
    } catch (e) {
      print('Error retrieving auth token: $e');
      return null;
    }
  }

  /// Sync pending products using stored authentication token
  Future<Map<String, dynamic>> syncPendingProductsWithStoredToken() async {
    final token = await getAuthToken();

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'No valid authentication token found',
        'synced_count': 0,
        'failed_count': 0,
        'errors': ['Authentication token is missing or invalid'],
      };
    }

    return await syncPendingProducts(token);
  }

  /// Test method to validate synchronization logic
  Future<Map<String, dynamic>> testSyncFunctionality() async {
    print('🧪 Testing sync functionality...');

    try {
      final db = await _dbService.database;

      // Test 1: Check database connectivity
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      print('✅ Database connectivity: OK');
      print('📋 Available tables: ${tables.map((t) => t['name']).toList()}');

      // Test 2: Check pending products
      final pendingCount = await getPendingProductCount();
      print('📦 Pending products: $pendingCount');

      // Test 3: Check sync status summary
      final summary = await getSyncStatusSummary();
      print('📊 Sync status summary: $summary');

      // Test 4: Check authentication token
      final token = await getAuthToken();
      final hasToken = token != null && token.isNotEmpty;
      print('🔑 Authentication token: ${hasToken ? "Available" : "Missing"}');

      // Test 5: Check API connectivity (if token available)
      if (hasToken) {
        try {
          final testResponse = await http.get(
            Uri.parse('${ApiService.baseUrl}/api/officer/profile'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          );
          print(
            '🌐 API connectivity: ${testResponse.statusCode == 200 ? "OK" : "Issue (${testResponse.statusCode})"}',
          );
        } catch (e) {
          print('🌐 API connectivity: Failed ($e)');
        }
      }

      return {
        'success': true,
        'message': 'Sync functionality test completed',
        'test_results': {
          'database_connectivity': true,
          'pending_products': pendingCount,
          'sync_summary': summary,
          'has_auth_token': hasToken,
        },
      };
    } catch (e) {
      final errorMsg = 'Test failed: $e';
      print('💥 $errorMsg');

      return {
        'success': false,
        'message': errorMsg,
        'test_results': {'database_connectivity': false, 'error': e.toString()},
      };
    }
  }

  /// Get detailed sync information for debugging
  Future<Map<String, dynamic>> getDetailedSyncInfo() async {
    final db = await _dbService.database;

    try {
      // Get products by sync status
      final allProducts = await db.query('products');
      final pendingProducts =
          allProducts.where((p) => p['sync_status'] == statusPending).toList();
      final syncedProducts =
          allProducts.where((p) => p['sync_status'] == statusSynced).toList();

      // Get pending items count
      int pendingItemsCount = 0;
      int pendingMovementsCount = 0;

      try {
        final itemsResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM product_items WHERE sync_status = ?',
          [statusPending],
        );
        pendingItemsCount = itemsResult.first['count'] as int;
      } catch (e) {
        print('⚠️ Could not query product_items table: $e');
      }

      try {
        final movementsResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM stock_movements WHERE sync_status = ?',
          [statusPending],
        );
        pendingMovementsCount = movementsResult.first['count'] as int;
      } catch (e) {
        print('⚠️ Could not query stock_movements table: $e');
      }

      return {
        'success': true,
        'database_info': {
          'total_products': allProducts.length,
          'pending_products': pendingProducts.length,
          'synced_products': syncedProducts.length,
          'pending_product_items': pendingItemsCount,
          'pending_stock_movements': pendingMovementsCount,
        },
        'pending_products_sample':
            pendingProducts
                .take(3)
                .map(
                  (p) => {
                    'name': p['name'],
                    'local_id': p['local_id'],
                    'sync_status': p['sync_status'],
                    'created_at': p['created_at'],
                  },
                )
                .toList(),
        'api_configuration': {
          'base_url': ApiService.baseUrl,
          'has_token': (await getAuthToken()) != null,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to get detailed sync info: $e',
      };
    }
  }

  /// Sync a specific sale to the server
  Future<Map<String, dynamic>> syncSpecificSale(
    int localSaleId,
    String token,
  ) async {
    final db = await _dbService.database;

    try {
      // 1. Get Sale
      final sales = await db.query(
        'sales',
        where: 'local_id = ?',
        whereArgs: [localSaleId],
      );
      if (sales.isEmpty) return {'success': false, 'message': 'Sale not found'};
      final sale = sales.first;

      // 2. Get Items
      final items = await db.query(
        'sale_items',
        where: 'sale_local_id = ?',
        whereArgs: [localSaleId],
      );

      // 3. Prepare Items Data
      List<Map<String, dynamic>> apiItems = [];
      for (var item in items) {
        // Resolve Product Server ID
        final prodRes = await db.query(
          'products',
          columns: ['server_id'],
          where: 'local_id = ?',
          whereArgs: [item['product_local_id']],
        );
        int? productServerId;
        if (prodRes.isNotEmpty)
          productServerId = prodRes.first['server_id'] as int?;

        if (productServerId == null) {
          return {
            'success': false,
            'message': 'Cannot sync sale: Contains unsynced products',
          };
        }

        apiItems.add({
          'product_id': productServerId,
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'discount_amount': item['discount_amount'],
          'total': item['subtotal'],
          // Add logic for product_item_id if you track serialized items on backend
        });
      }

      // 4. Resolve Customer Server ID
      int? customerServerId;
      if (sale['customer_id'] != null) {
        final custRes = await db.query(
          'customers',
          columns: ['server_id'],
          where: 'local_id = ? OR server_id = ?',
          whereArgs: [sale['customer_id'], sale['customer_id']],
        );
        if (custRes.isNotEmpty) {
          customerServerId = custRes.first['server_id'] as int?;
        }
      }

      final saleData = {
        'customer_id': customerServerId,
        'total_amount': sale['total_amount'],
        'discount_amount': sale['discount_amount'],
        'discount_reason': sale['discount_reason'],
        'is_loan': sale['is_loan'] == 1,
        'items': apiItems,
        'payment_status': sale['payment_status'],
        'created_at': sale['created_at'], // Preserve creation time
      };

      // 5. Send to API
      final response = await ApiService().createSale(saleData, token);
      if (response['success'] == true) {
        final serverId = response['sale_id'];
        await _dbService.updateSaleServerId(localSaleId, serverId);
        return {'success': true, 'server_id': serverId};
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Unknown API error',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Sync exception: $e'};
    }
  }

  /// Sync all pending sales in the background
  Future<void> syncAllPendingSales(String token) async {
    final db = await _dbService.database;
    final pendingSales = await db.query(
      'sales',
      where: 'sync_status = ?',
      whereArgs: [statusPending],
    );

    if (pendingSales.isEmpty) return;

    for (var sale in pendingSales) {
      await syncSpecificSale(sale['local_id'] as int, token);
    }
  }

  /// Sync pending stock records directly from stocks table
  Future<Map<String, dynamic>> syncPendingStocks(String token) async {
    final db = await _dbService.database;

    try {
      final pendingStocks = await db.query(
        'stocks',
        where: 'sync_status = ?',
        whereArgs: [statusPending],
      );

      if (pendingStocks.isEmpty) {
        return {
          'success': true,
          'message': 'No pending stocks to sync',
          'synced_count': 0,
          'failed_count': 0,
        };
      }

      int syncedCount = 0;
      int failedCount = 0;
      List<String> errors = [];

      print('🔄 Syncing ${pendingStocks.length} pending stock records...');

      for (var stock in pendingStocks) {
        try {
          final success = await _syncSingleStock(stock, token);
          if (success) {
            syncedCount++;
            print('✅ Synced stock record: ${stock['local_id']}');
          } else {
            failedCount++;
            errors.add('Failed to sync stock: ${stock['local_id']}');
          }
        } catch (e) {
          failedCount++;
          errors.add('Error syncing stock ${stock['local_id']}: $e');
        }
      }

      return {
        'success': failedCount == 0,
        'message':
            failedCount == 0
                ? 'All stock records synced successfully'
                : 'Some stock records failed to sync',
        'synced_count': syncedCount,
        'failed_count': failedCount,
        'errors': errors,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Stock sync failed: $e',
        'synced_count': 0,
        'failed_count': 0,
        'errors': [e.toString()],
      };
    }
  }

  /// Sync a single stock record using the addStock API
  Future<bool> _syncSingleStock(
    Map<String, dynamic> stock,
    String token,
  ) async {
    try {
      print('📦 Syncing stock record: ${stock['local_id']}');

      final db = await _dbService.database;
      final stockProductId = stock['product_id'] as int;
      final quantity = stock['quantity'] as int;

      // Resolve Product Server ID
      var productRes = await db.query(
        'products',
        columns: ['server_id', 'local_id'],
        where: 'local_id = ? OR server_id = ?',
        whereArgs: [stockProductId, stockProductId],
      );

      if (productRes.isEmpty) {
        print('⏳ Parent product not found for stock ${stock['local_id']}');
        return false;
      }

      final product = productRes.first;
      final productServerId = product['server_id'] as int?;
      final productLocalId = product['local_id'] as int;

      if (productServerId == null) {
        // Product not synced yet, skip this stock for now
        print('⏳ Parent product not synced yet for stock ${stock['local_id']}');
        return false;
      }

      // Use the addStock API to add this stock quantity
      final response = await ApiService().addStock({
        'product_id': productServerId,
        'quantity': quantity,
        'reason': 'Stock addition from mobile app',
      }, token);

      if (response['success'] == true) {
        // Update local stock record as synced
        await db.update(
          'stocks',
          {
            'sync_status': statusSynced,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'local_id = ?',
          whereArgs: [stock['local_id']],
        );

        print('✅ Stock synced successfully: $quantity units');
        return true;
      } else {
        print(
          '⚠️ Failed to sync stock: ${response['message'] ?? 'Unknown error'}',
        );
        return false;
      }
    } catch (e) {
      print('💥 Error syncing stock: $e');
      return false;
    }
  }

  /// Comprehensive sync including stocks table
  Future<Map<String, dynamic>> syncAllPendingDataIncludingStocks(
    String token,
  ) async {
    print('🚀 Starting comprehensive sync including stocks...');

    final results = {
      'products': await syncPendingProducts(token),
      'product_items': await syncPendingProductItems(token),
      'stock_movements': await syncPendingStockMovements(token),
      'stocks': await syncPendingStocks(token), // Add stocks sync
    };

    // Calculate overall success
    final productsResult = results['products'] as Map<String, dynamic>? ?? {};
    final itemsResult = results['product_items'] as Map<String, dynamic>? ?? {};
    final stockMovementsResult =
        results['stock_movements'] as Map<String, dynamic>? ?? {};
    final stocksResult = results['stocks'] as Map<String, dynamic>? ?? {};

    final allProductsSuccess = productsResult['success'] as bool? ?? false;
    final allItemsSuccess = itemsResult['success'] as bool? ?? false;
    final allStockMovementsSuccess =
        stockMovementsResult['success'] as bool? ?? false;
    final allStocksSuccess = stocksResult['success'] as bool? ?? false;

    final overallSuccess =
        allProductsSuccess &&
        allItemsSuccess &&
        allStockMovementsSuccess &&
        allStocksSuccess;

    final totalSynced =
        (productsResult['synced_count'] as int? ?? 0) +
        (itemsResult['synced_count'] as int? ?? 0) +
        (stockMovementsResult['synced_count'] as int? ?? 0) +
        (stocksResult['synced_count'] as int? ?? 0);

    final totalFailed =
        (productsResult['failed_count'] as int? ?? 0) +
        (itemsResult['failed_count'] as int? ?? 0) +
        (stockMovementsResult['failed_count'] as int? ?? 0) +
        (stocksResult['failed_count'] as int? ?? 0);

    print('📊 Comprehensive sync (including stocks) completed:');
    print('   Total synced: $totalSynced');
    print('   Total failed: $totalFailed');
    print('   Overall success: $overallSuccess');

    return {
      'success': overallSuccess,
      'message':
          overallSuccess
              ? 'All pending data (including stocks) synced successfully'
              : 'Some data failed to sync',
      'results': results,
      'summary': {'total_synced': totalSynced, 'total_failed': totalFailed},
    };
  }
}
