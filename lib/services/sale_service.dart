import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/sync_service.dart';

class SaleService {
  final SyncService _syncService = SyncService();

  Future<String?> _getToken() async {
    return await _syncService.getAuthToken();
  }

  /// 1. Get Sale Items List
  Future<Map<String, dynamic>> getSaleItems({
    int? saleId,
    int? productId,
    int? dukaId,
    int? customerId,
    String? dateFrom,
    String? dateTo,
    int perPage = 15,
    int page = 1,
  }) async {
    final token = await _getToken();
    if (token == null) return {'success': false, 'message': 'Authentication failed'};

    final queryParams = {
      if (saleId != null) 'sale_id': saleId.toString(),
      if (productId != null) 'product_id': productId.toString(),
      if (dukaId != null) 'duka_id': dukaId.toString(),
      if (customerId != null) 'customer_id': customerId.toString(),
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      'per_page': perPage.toString(),
      'page': page.toString(),
    };

    final uri = Uri.parse('${ApiService.baseUrl}/api/officer/sale-items')
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch sale items: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 2. Get Sale Item Details
  Future<Map<String, dynamic>> getSaleItemDetails(int id) async {
    final token = await _getToken();
    if (token == null) return {'success': false, 'message': 'Authentication failed'};

    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/officer/sale-items/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch details: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 3. Get Sale Items by Sale ID
  Future<Map<String, dynamic>> getItemsBySaleId(int saleId) async {
    final token = await _getToken();
    if (token == null) return {'success': false, 'message': 'Authentication failed'};

    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/officer/sales/$saleId/items'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch items: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 4. Update Sale Item
  Future<Map<String, dynamic>> updateSaleItem(int id, {
    int? quantity,
    double? unitPrice,
    double? discountAmount,
  }) async {
    final token = await _getToken();
    if (token == null) return {'success': false, 'message': 'Authentication failed'};

    final body = {
      if (quantity != null) 'quantity': quantity,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (discountAmount != null) 'discount_amount': discountAmount,
    };

    try {
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/api/officer/sale-items/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['error'] ?? 'Update failed: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 5. Delete Sale Item
  Future<Map<String, dynamic>> deleteSaleItem(int id) async {
    final token = await _getToken();
    if (token == null) return {'success': false, 'message': 'Authentication failed'};

    try {
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}/api/officer/sale-items/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['error'] ?? 'Delete failed: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}