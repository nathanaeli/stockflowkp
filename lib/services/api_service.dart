import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import 'package:stockflowkp/services/database_service.dart';

class ApiService {
  static const String baseUrl = 'https://stockflowkp.online/';

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw body['message'] ?? 'Login failed';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw body['message'] ?? 'Registration failed';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteCustomer(int id, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/customers/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData; // Success
      } else {
        throw responseData['message'] ?? 'Failed to delete customer';
      }
    } catch (e) {
      throw 'Connection error: $e';
    }
  }

  Future<Map<String, dynamic>> deleteTenantAccount(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/deleteaccount'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw responseData['message'] ?? 'Failed to delete account';
      }
    } catch (e) {
      throw 'Connection error: $e';
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/forgot-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> resetPassword(
    String email,
    String password,
    String passwordConfirmation,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reset-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'token': token,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> syncOfficerProducts(
    String token, {
    String? lastSync,
  }) async {
    try {
      // Ensure baseUrl is defined in your class, or replace with your actual API URL
      final uri = Uri.parse('$baseUrl/officer/sync');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({if (lastSync != null) 'last_sync': lastSync}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Sync failed [${response.statusCode}]: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Sync error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> getOfficerDashboard(
    int officerId,
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/officer/dashboard/$officerId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch dashboard: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Dashboard fetch error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getOfficerPermissionsi(
    int officerId,
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/officer/permissions/$officerId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch permissions: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Permissions fetch error: $e');
      rethrow;
    }
  }

  // Add Product API (Multipart)
  Future<Map<String, dynamic>> addProduct(
    Map<String, dynamic> productData,
    File? imageFile,
    String token,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/api/officer/products');
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Add fields
      productData.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      // Add image if exists
      if (imageFile != null) {
        final stream = http.ByteStream(imageFile.openRead());
        final length = await imageFile.length();
        final multipartFile = http.MultipartFile(
          'image',
          stream,
          length,
          filename: imageFile.path.split('/').last,
        );
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to add product: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Add product error: $e');
      rethrow;
    }
  }

  // Update Product API (Multipart)
  Future<Map<String, dynamic>> updateProduct(
    int productId,
    Map<String, dynamic> productData,
    File? imageFile,
    String token,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/api/officer/products/$productId');

      final request = http.MultipartRequest(
        'POST',
        uri,
      ); // Using POST with _method spoofing is safer for files in PHP
      request.fields['_method'] = 'PUT';

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      productData.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      if (imageFile != null) {
        final stream = http.ByteStream(imageFile.openRead());
        final length = await imageFile.length();
        final multipartFile = http.MultipartFile(
          'image',
          stream,
          length,
          filename: imageFile.path.split('/').last,
        );
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to update product: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Update product error: $e');
      rethrow;
    }
  }

  // Delete Product API
  Future<Map<String, dynamic>> deleteProduct(
    int productId,
    String token,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/officer/products/$productId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to delete product: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Delete product error: $e');
      rethrow;
    }
  }

  // Create Product Item API
  Future<Map<String, dynamic>> createProductItem(
    Map<String, dynamic> itemData,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/officer/product-items'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(itemData),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to create product item');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getProductItemsByProductId(
    int productServerId,
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/officer/product-items/by-product/$productServerId',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to fetch product items');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Update Stock API
  Future<Map<String, dynamic>> updateStock(
    Map<String, dynamic> stockData,
    String token,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/officer/stock'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(stockData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to update stock: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Update stock error: $e');
      rethrow;
    }
  }

  // Add Stock API
  Future<Map<String, dynamic>> addStock(
    Map<String, dynamic> stockData,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/officer/stock'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(stockData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['error'] ??
              body['message'] ??
              'Failed to add stock: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Add stock error: $e');
      rethrow;
    }
  }

  // Reduce Stock API
  Future<Map<String, dynamic>> reduceStock(
    Map<String, dynamic> stockData,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/stocks/reduce'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(stockData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['error'] ??
              body['message'] ??
              'Failed to reduce stock: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Reduce stock error: $e');
      rethrow;
    }
  }

  // Get Products API
  Future<Map<String, dynamic>> getProducts(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/officer/products'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch products: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Category Management ---
  Future<Map<String, dynamic>> getCategories(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/officer/categories?per_page=100'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch categories: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCategory(
    Map<String, dynamic> data,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/officer/categories'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['error'] ?? body['message'] ?? 'Failed to create category',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCategory(
    int id,
    Map<String, dynamic> data,
    String token,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/officer/categories/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['error'] ?? body['message'] ?? 'Failed to update category',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteCategory(int id, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/officer/categories/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['error'] ?? body['message'] ?? 'Failed to delete category',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Customer Management ---
  Future<Map<String, dynamic>> getCustomers(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/officer/customers?per_page=100'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch customers: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCustomer(
    Map<String, dynamic> data,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/officer/customers'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['error'] ?? body['message'] ?? 'Failed to create customer',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCustomer(
    int id,
    Map<String, dynamic> data,
    String token,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/officer/customers/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['error'] ?? body['message'] ?? 'Failed to update customer',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Sales Management ---
  Future<Map<String, dynamic>> getSales(
    String token, {
    Map<String, dynamic>? filters,
  }) async {
    try {
      String queryString = '?per_page=100';
      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null) queryString += '&$key=$value';
        });
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/officer/sales$queryString'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch sales: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createSale(
    Map<String, dynamic> data,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/officer/sales'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['error'] ?? body['message'] ?? 'Failed to create sale',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateSale(
    int id,
    Map<String, dynamic> data,
    String token,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/sales/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['error'] ?? body['message'] ?? 'Failed to update sale',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteSale(int id, String token) async {
    try {
      // 1. Send DELETE request to the server
      final response = await http.get(
        Uri.parse('$baseUrl/api/sales/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // 2. Remove from local SQLite database if server delete was successful
        final dbService = DatabaseService();
        await dbService.deleteLocalSale(id);

        return body;
      } else {
        throw Exception(
          body['error'] ?? body['message'] ?? 'Failed to delete sale',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteProducthere(
    int productId,
    String token,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/officer/products/$productId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return body;
      } else {
        throw Exception(
          body['message'] ?? 'Failed to delete product from server',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSaleDetails(int id, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sales/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch sale details: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSalesWithItems(
    String token, {
    Map<String, dynamic>? filters,
  }) async {
    try {
      String queryString = '';
      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null) queryString += '&$key=$value';
        });
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/officer/sales-with-items$queryString'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch sales with items: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSaleInvoice(int id, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/officer/sales/$id/invoice'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch sale invoice: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getLoanPayments(
    String token, {
    Map<String, dynamic>? filters,
  }) async {
    try {
      String queryString = '?per_page=100';
      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null) queryString += '&$key=$value';
        });
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/officer/loan-payments$queryString'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch loan payments: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createLoanPayment(
    Map<String, dynamic> data,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/officer/loan-payments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['error'] ?? body['message'] ?? 'Failed to create loan payment',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getLoanPaymentDetails(
    int id,
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/officer/loan-payments/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch loan payment details: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateLoanPayment(
    int id,
    Map<String, dynamic> data,
    String token,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/officer/loan-payments/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['error'] ?? body['message'] ?? 'Failed to update loan payment',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteLoanPayment(int id, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/officer/loan-payments/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['error'] ?? body['message'] ?? 'Failed to delete loan payment',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getLoanPaymentsForSale(
    int saleId,
    String token, {
    Map<String, dynamic>? filters,
  }) async {
    try {
      String queryString = '';
      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null) queryString += '&$key=$value';
        });
      }

      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/officer/sales/$saleId/loan-payments$queryString',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch loan payments for sale: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTenantDetails(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tenant/details'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch tenant details: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTenantDukas(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tenant/dukas'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch tenant dukas: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // Future<Map<String, dynamic>> getDukaProducts(String token, int dukaId) async {
  //   try {
  //     final response = await http.get(
  //       Uri.parse('$baseUrl/api/tenant/duka/$dukaId/products'),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Accept': 'application/json',
  //       },
  //     );

  //     if (response.statusCode == 200) {
  //       return jsonDecode(response.body);
  //     } else {
  //       throw Exception(
  //         'Failed to fetch duka products: ${response.statusCode} - ${response.body}',
  //       );
  //     }
  //   } catch (e) {
  //     rethrow;
  //   }
  // }

  // Get comprehensive duka overview and analytics
  // Future<Map<String, dynamic>> getDukaOverview(
  //   String token,
  //   int dukaId, {
  //   String? startDate,
  //   String? endDate,
  // }) async {
  //   try {
  //     String queryString = '';
  //     if (startDate != null || endDate != null) {
  //       queryString = '?';
  //       if (startDate != null) queryString += 'start_date=$startDate';
  //       if (startDate != null && endDate != null) queryString += '&';
  //       if (endDate != null) queryString += 'end_date=$endDate';
  //     }

  //     final response = await http.get(
  //       Uri.parse('$baseUrl/api/tenant/duka/$dukaId/overview$queryString'),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Accept': 'application/json',
  //       },
  //     );

  //     if (response.statusCode == 200) {
  //       return jsonDecode(response.body);
  //     } else {
  //       throw Exception(
  //         'Failed to fetch duka overview: ${response.statusCode} - ${response.body}',
  //       );
  //     }
  //   } catch (e) {
  //     rethrow;
  //   }
  // }

  // --- Tenant Management APIs ---

  // Future<Map<String, dynamic>> createDuka(
  //   Map<String, dynamic> dukaData,
  //   String token,
  // ) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse('$baseUrl/api/tenant/duka'),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Content-Type': 'application/json',
  //         'Accept': 'application/json',
  //       },
  //       body: jsonEncode(dukaData),
  //     );

  //     if (response.statusCode == 201) {
  //       return jsonDecode(response.body);
  //     } else {
  //       final body = jsonDecode(response.body);
  //       throw Exception(body['message'] ?? 'Failed to create duka');
  //     }
  //   } catch (e) {
  //     rethrow;
  //   }
  // }

  // Future<Map<String, dynamic>> getOfficers(String token) async {
  //   try {
  //     final response = await http.get(
  //       Uri.parse('$baseUrl/api/tenant/officers'),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Accept': 'application/json',
  //       },
  //     );

  //     if (response.statusCode == 200) {
  //       return jsonDecode(response.body);
  //     } else {
  //       throw Exception(
  //         'Failed to fetch officers: ${response.statusCode} - ${response.body}',
  //       );
  //     }
  //   } catch (e) {
  //     rethrow;
  //   }
  // }

  // Future<Map<String, dynamic>> createOfficer(
  //   Map<String, dynamic> officerData,
  //   String token,
  // ) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse('$baseUrl/api/tenant/officer'),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Content-Type': 'application/json',
  //         'Accept': 'application/json',
  //       },
  //       body: jsonEncode(officerData),
  //     );

  //     if (response.statusCode == 201) {
  //       return jsonDecode(response.body);
  //     } else {
  //       final body = jsonDecode(response.body);
  //       throw Exception(body['message'] ?? 'Failed to create officer');
  //     }
  //   } catch (e) {
  //     rethrow;
  //   }
  // }

  Future<Map<String, dynamic>> updateOfficer(
    int officerId,
    Map<String, dynamic> officerData,
    String token,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/tenant/officer/$officerId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(officerData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to update officer');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteOfficer(
    int officerId,
    String token,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/tenant/officer/$officerId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to delete officer');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTenantAccount(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tenant/tenant-account'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch tenant account: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateTenantAccount(
    Map<String, dynamic> accountData,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tenant/account'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(accountData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to update tenant account');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDukaPlan(String token, int dukaId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tenant/duka/$dukaId/plan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch duka plan: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Duka plan fetch error: $e');
      rethrow;
    }
  }

  // Get detailed product information with full analytics
  Future<Map<String, dynamic>> getProductDetails(
    int productId,
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tenant/dukasproducts/$productId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch product details: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Product details fetch error: $e');
      rethrow;
    }
  }

  // --- Tenant Product CRUD ---

  Future<Map<String, dynamic>> updateTenantProduct(
    int productId,
    Map<String, dynamic> productData,
    String token, {
    String? imagePath,
  }) async {
    try {
      // Use POST with _method=PUT for reliable multipart handling in Laravel
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/tenant/products/$productId'),
      );
      request.fields['_method'] = 'PUT';

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      productData.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      if (imagePath != null && File(imagePath).existsSync()) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imagePath),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to update product');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteTenantProduct(
    int productId,
    String token,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/tenant/products/$productId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to delete product');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Registration & Plans API ---

  Future<Map<String, dynamic>> getPlans({String? token}) async {
    try {
      final headers = {'Accept': 'application/json'};

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/tenant/plans'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch plans: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Plans fetch error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> registerTenant(
    Map<String, dynamic> registrationData,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tenant/register'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(registrationData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Registration failed');
      }
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDukaProducts(int dukaId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tenant/duka/$dukaId/products'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch duka products: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTenantSales(
    String token, {
    int? dukaId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/tenant/sales').replace(
        queryParameters: {if (dukaId != null) 'duka_id': dukaId.toString()},
      );

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
        throw Exception(
          'Failed to fetch tenant sales: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getConsolidatedProfitLoss(
    String token, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      String queryString = '';
      if (startDate != null) queryString += '?start_date=$startDate';
      if (endDate != null) {
        queryString += '${queryString.isEmpty ? '?' : '&'}end_date=$endDate';
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/tenant/reports/consolidated-pl$queryString'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch P&L report: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }
  // --- Tenant Officer Management ---

  Future<Map<String, dynamic>> getTenantOfficers(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tenant/officers'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch officers: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createTenantOfficer(
    String token,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tenant/officer'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['message'] ?? 'Failed to create officer: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateTenantOfficer(
    String token,
    int officerId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/tenant/officer/$officerId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['message'] ?? 'Failed to update officer: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteTenantOfficer(
    String token,
    int officerId,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/tenant/officer/$officerId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['message'] ?? 'Failed to delete officer: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getOfficerPermissions(
    String token,
    int officerId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tenant/officers/$officerId/permissions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch officer permissions: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateOfficerPermissions(
    String token,
    int officerId,
    List<String> permissions,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tenant/officers/$officerId/permissions/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'permissions': permissions}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['message'] ??
              'Failed to update permissions: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Category Management ---

  Future<Map<String, dynamic>> getTenantCategories(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tenant/categories'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch categories: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createTenantCategory(
    String token,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tenant/categories'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['message'] ??
              'Failed to create category: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateTenantCategory(
    String token,
    int categoryId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/tenant/categories/$categoryId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['message'] ??
              'Failed to update category: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteTenantCategory(
    String token,
    int categoryId,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/tenant/categories/$categoryId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(
          body['message'] ??
              'Failed to delete category: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getLowStockProducts(
    String token, {
    int threshold = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tenant/reports/low-stock?threshold=$threshold'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch low stock products: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTransactionReport(
    String token, {
    int? dukaId,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, String>{'page': page.toString()};
      if (dukaId != null) queryParams['duka_id'] = dukaId.toString();
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }

      final uri = Uri.parse(
        '$baseUrl/api/tenant/reports/transactions',
      ).replace(queryParameters: queryParams);

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
        throw Exception(
          'Failed to fetch transaction report: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getInventoryAndLoanAnalysis(
    String token, {
    int? dukaId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (dukaId != null) queryParams['duka_id'] = dukaId.toString();

      final uri = Uri.parse(
        '$baseUrl/api/tenant/reports/aging-and-stock',
      ).replace(queryParameters: queryParams);

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
        throw Exception(
          'Failed to fetch analysis report: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createDuka(
    Map<String, dynamic> dukaData,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/officer/dukas'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(dukaData),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to create duka');
      }
    } catch (e) {
      rethrow;
    }
  }
}
