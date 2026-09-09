import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  // Get token from storage
  Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  // Save token to storage
  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Clear token
  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Get headers
  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};

    if (includeAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Generic GET request
  Future<dynamic> get(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _getHeaders(includeAuth: requiresAuth);

      final response = await http
          .get(url, headers: headers)
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  // Generic POST request
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _getHeaders(includeAuth: requiresAuth);

      final response = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  // Generic PUT request
  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _getHeaders(includeAuth: requiresAuth);

      final response = await http
          .put(url, headers: headers, body: jsonEncode(body))
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  // Generic DELETE request
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _getHeaders(includeAuth: requiresAuth);

      final response = await http
          .delete(url, headers: headers)
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  // Handle response
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      clearToken();
      throw ApiException('Unauthorized. Please login again.');
    } else if (response.statusCode == 403) {
      throw ApiException('Access forbidden');
    } else if (response.statusCode == 404) {
      throw ApiException('Resource not found');
    } else if (response.statusCode >= 500) {
      throw ApiException('Server error. Please try again later.');
    } else {
      final error = jsonDecode(response.body);
      String errorMessage = 'Request failed';

      if (error['detail'] != null) {
        if (error['detail'] is String) {
          errorMessage = error['detail'];
        } else if (error['detail'] is List) {
          // Handle FastAPI validation errors
          errorMessage = (error['detail'] as List)
              .map((e) => e['msg'] ?? e.toString())
              .join('\n');
        } else {
          errorMessage = error['detail'].toString();
        }
      }

      throw ApiException(errorMessage);
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
