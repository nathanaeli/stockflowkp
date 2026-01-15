import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class ApiService {
  static const String baseUrl = 'http://192.168.0.21:8000';

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

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/forgot-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: jsonEncode({'email': email}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> resetPassword(String email, String password, String passwordConfirmation, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reset-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
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

   Future<Map<String, dynamic>?> syncOfficerProducts(String token, {String? lastSync}) async {
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
        body: jsonEncode({
          if (lastSync != null) 'last_sync': lastSync,
        }),
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

  Future<Map<String, dynamic>> getOfficerDashboard(int officerId, String token) async {
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
        throw Exception('Failed to fetch dashboard: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Dashboard fetch error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getOfficerPermissions(int officerId, String token) async {
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
        throw Exception('Failed to fetch permissions: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Permissions fetch error: $e');
      rethrow;
    }
  }

  // Add Product API
  Future<Map<String, dynamic>> addProduct(Map<String, dynamic> productData, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/officer/products'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(productData),
      );
     

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to add product: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Add product error: $e');
      rethrow;
    }
  }

  // Create Product Item API
  Future<Map<String, dynamic>> createProductItem(Map<String, dynamic> itemData, String token) async {
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

  Future<Map<String, dynamic>> getProductItemsByProductId(int productServerId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/officer/product-items/by-product/$productServerId'),
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
  Future<Map<String, dynamic>> updateStock(Map<String, dynamic> stockData, String token) async {
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
        throw Exception('Failed to update stock: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Update stock error: $e');
      rethrow;
    }
  }

  // Add Stock API
  Future<Map<String, dynamic>> addStock(Map<String, dynamic> stockData, String token) async {
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
        throw Exception(body['error'] ?? body['message'] ?? 'Failed to add stock: ${response.statusCode}');
      }
    } catch (e) {
      print('Add stock error: $e');
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
        throw Exception('Failed to fetch products: ${response.statusCode} - ${response.body}');
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
        throw Exception('Failed to fetch categories: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> data, String token) async {
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
        throw Exception(body['error'] ?? body['message'] ?? 'Failed to create category');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCategory(int id, Map<String, dynamic> data, String token) async {
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
        throw Exception(body['error'] ?? body['message'] ?? 'Failed to update category');
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
        throw Exception(body['error'] ?? body['message'] ?? 'Failed to delete category');
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
        throw Exception('Failed to fetch customers: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> data, String token) async {
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
        throw Exception(body['error'] ?? body['message'] ?? 'Failed to create customer');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCustomer(int id, Map<String, dynamic> data, String token) async {
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
        throw Exception(body['error'] ?? body['message'] ?? 'Failed to update customer');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Sales Management ---
  Future<Map<String, dynamic>> getSales(String token, {Map<String, dynamic>? filters}) async {
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
        throw Exception('Failed to fetch sales: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createSale(Map<String, dynamic> data, String token) async {
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
        throw Exception(body['error'] ?? body['message'] ?? 'Failed to create sale');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSaleDetails(int id, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/officer/sales/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch sale details: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSalesWithItems(String token, {Map<String, dynamic>? filters}) async {
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
        throw Exception('Failed to fetch sales with items: ${response.statusCode} - ${response.body}');
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
        throw Exception('Failed to fetch sale invoice: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getLoanPayments(String token, {Map<String, dynamic>? filters}) async {
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
        throw Exception('Failed to fetch loan payments: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createLoanPayment(Map<String, dynamic> data, String token) async {
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
        throw Exception(body['error'] ?? body['message'] ?? 'Failed to create loan payment');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getLoanPaymentDetails(int id, String token) async {
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
        throw Exception('Failed to fetch loan payment details: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateLoanPayment(int id, Map<String, dynamic> data, String token) async {
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
        throw Exception(body['error'] ?? body['message'] ?? 'Failed to update loan payment');
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
        throw Exception(body['error'] ?? body['message'] ?? 'Failed to delete loan payment');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getLoanPaymentsForSale(int saleId, String token, {Map<String, dynamic>? filters}) async {
    try {
      String queryString = '';
      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null) queryString += '&$key=$value';
        });
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/officer/sales/$saleId/loan-payments$queryString'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch loan payments for sale: ${response.statusCode} - ${response.body}');
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
        throw Exception('Failed to fetch tenant details: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDukaProducts(String token, int dukaId) async {
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
        throw Exception('Failed to fetch duka products: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get comprehensive duka overview and analytics
  Future<Map<String, dynamic>> getDukaOverview(String token, int dukaId, {String? startDate, String? endDate}) async {
    try {
      String queryString = '';
      if (startDate != null || endDate != null) {
        queryString = '?';
        if (startDate != null) queryString += 'start_date=$startDate';
        if (startDate != null && endDate != null) queryString += '&';
        if (endDate != null) queryString += 'end_date=$endDate';
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/tenant/duka/$dukaId/overview$queryString'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch duka overview: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Tenant Management APIs ---

  Future<Map<String, dynamic>> createDuka(Map<String, dynamic> dukaData, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tenant/duka'),
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

  Future<Map<String, dynamic>> getOfficers(String token) async {
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
        throw Exception('Failed to fetch officers: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createOfficer(Map<String, dynamic> officerData, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tenant/officer'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(officerData),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to create officer');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateOfficer(int officerId, Map<String, dynamic> officerData, String token) async {
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

  Future<Map<String, dynamic>> deleteOfficer(int officerId, String token) async {
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
        throw Exception('Failed to fetch tenant account: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateTenantAccount(Map<String, dynamic> accountData, String token) async {
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
        throw Exception('Failed to fetch duka plan: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Duka plan fetch error: $e');
      rethrow;
    }
  }

  // Get detailed product information with full analytics
  Future<Map<String, dynamic>> getProductDetails(int productId, String token) async {
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
        throw Exception('Failed to fetch product details: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Product details fetch error: $e');
      rethrow;
    }
  }

  // --- Tenant Product CRUD ---

  Future<Map<String, dynamic>> updateTenantProduct(int productId, Map<String, dynamic> productData, String token, {String? imagePath}) async {
    try {
      // Use POST with _method=PUT for reliable multipart handling in Laravel
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/tenant/products/$productId'));
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
        request.files.add(await http.MultipartFile.fromPath('image', imagePath));
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

  Future<Map<String, dynamic>> deleteTenantProduct(int productId, String token) async {
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

  Future<Map<String, dynamic>> getPlans(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tenant/plans'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch plans: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Plans fetch error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> registerTenant(Map<String, dynamic> registrationData, String token) async {
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
}
