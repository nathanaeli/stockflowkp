import 'dart:convert';
import '../services/database_service.dart';

class DebugUtils {
  static final DatabaseService _dbService = DatabaseService();

  /// Debug method to check user data structure and token location
  static Future<void> debugUserData() async {
    try {
      final db = await _dbService.database;
      final userDataMaps = await db.query('user_data');

      print('=== USER DATA DEBUG ===');
      print('Total records: ${userDataMaps.length}');

      if (userDataMaps.isEmpty) {
        print('❌ No user data found');
        return;
      }

      for (int i = 0; i < userDataMaps.length; i++) {
        final record = userDataMaps[i];
        print('\\n--- Record $i ---');
        print('ID: ${record['id']}');

        final String jsonData = record['data'] as String;
        print('Raw JSON length: ${jsonData.length}');

        try {
          final Map<String, dynamic> userData = jsonDecode(jsonData);
          print('Parsed JSON keys: ${userData.keys.toList()}');

          // Print the full structure for analysis
          print('Full structure:');
          print(_prettyPrintJson(userData));

          // Check for token in various locations
          _checkTokenLocations(userData);
        } catch (e) {
          print('❌ Failed to parse JSON: $e');
          print('Raw data: $jsonData');
        }
      }
      print('\\n=== END DEBUG ===');
    } catch (e) {
      print('❌ Debug failed: $e');
    }
  }

  /// Check different possible token locations
  static void _checkTokenLocations(Map<String, dynamic> data) {
    print('\\n🔍 Checking token locations:');

    // Direct token
    if (data['token'] != null) {
      print('✅ Found token at data["token"]: ${data['token']}');
    }

    // Access token direct
    if (data['access_token'] != null) {
      print(
        '✅ Found access_token at data["access_token"]: ${data['access_token']}',
      );
    }

    // Check data object
    if (data['data'] != null && data['data'] is Map) {
      final dataObj = data['data'] as Map<String, dynamic>;
      print('📁 Found data object with keys: ${dataObj.keys.toList()}');

      if (dataObj['token'] != null) {
        print('✅ Found token at data["data"]["token"]: ${dataObj['token']}');
      }

      if (dataObj['access_token'] != null) {
        print(
          '✅ Found access_token at data["data"]["access_token"]: ${dataObj['access_token']}',
        );
      }

      // Check user object
      if (dataObj['user'] != null && dataObj['user'] is Map) {
        final userObj = dataObj['user'] as Map<String, dynamic>;
        print('👤 Found user object with keys: ${userObj.keys.toList()}');

        if (userObj['token'] != null) {
          print(
            '✅ Found token at data["data"]["user"]["token"]: ${userObj['token']}',
          );
        }

        if (userObj['access_token'] != null) {
          print(
            '✅ Found access_token at data["data"]["user"]["access_token"]: ${userObj['access_token']}',
          );
        }
      }
    }

    // Check for any field containing 'token'
    _findTokenFields(data);
  }

  /// Recursively find any fields containing 'token'
  static void _findTokenFields(dynamic obj, {String prefix = ''}) {
    if (obj is Map) {
      for (final entry in obj.entries) {
        final key = entry.key as String;
        final value = entry.value;

        if (key.toLowerCase().contains('token')) {
          print('🎯 Found token-like field: $prefix$key = $value');
        }

        if (value is Map || value is List) {
          _findTokenFields(value, prefix: '$prefix$key.');
        }
      }
    } else if (obj is List) {
      for (int i = 0; i < obj.length; i++) {
        _findTokenFields(obj[i], prefix: '$prefix[$i]');
      }
    }
  }

  /// Pretty print JSON for debugging
  static String _prettyPrintJson(dynamic json, {int indent = 2}) {
    try {
      final encoder = JsonEncoder.withIndent(' ' * indent);
      return encoder.convert(json);
    } catch (e) {
      return 'Failed to format JSON: $e';
    }
  }

  /// Debug pending products
  static Future<void> debugPendingProducts() async {
    try {
      final db = await _dbService.database;
      final pendingProducts = await db.query(
        'products',
        where: 'sync_status = ?',
        whereArgs: [DatabaseService.statusPending],
      );

      print('\\n=== PENDING PRODUCTS DEBUG ===');
      print('Pending products count: ${pendingProducts.length}');

      for (int i = 0; i < pendingProducts.length; i++) {
        final product = pendingProducts[i];
        print('\\n--- Product $i ---');
        print('local_id: ${product['local_id']}');
        print('server_id: ${product['server_id']}');
        print('name: ${product['name']}');
        print('sku: ${product['sku']}');
        print('sync_status: ${product['sync_status']}');
        print('created_at: ${product['created_at']}');
      }
      print('\\n=== END PENDING PRODUCTS DEBUG ===');
    } catch (e) {
      print('❌ Pending products debug failed: $e');
    }
  }

  /// Complete debug report
  static Future<void> fullDebugReport() async {
    print('🔍 STARTING COMPLETE DEBUG REPORT');
    print('Timestamp: ${DateTime.now()}');

    await debugUserData();
    await debugPendingProducts();

    print('\\n🏁 COMPLETE DEBUG REPORT FINISHED');
  }
}
