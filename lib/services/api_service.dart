import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

/// Exception thrown when an API call fails
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

/// Centralized API service for all network requests
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();
  String? _authToken;

  /// Set authentication token
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Clear authentication token
  void clearAuthToken() {
    _authToken = null;
  }

  /// Get headers for API requests
  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  /// Handle API response
  dynamic _handleResponse(http.Response response) {
    if (kDebugMode) {
      print('API Response [${response.statusCode}]: ${response.body}');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return null;
      }
      try {
        return json.decode(response.body);
      } catch (e) {
        debugPrint('Error decoding response: $e');
        return response.body;
      }
    } else if (response.statusCode == 401) {
      throw ApiException(
        AppConstants.authError,
        statusCode: response.statusCode,
      );
    } else if (response.statusCode >= 500) {
      throw ApiException(
        AppConstants.serverError,
        statusCode: response.statusCode,
      );
    } else {
      String message = AppConstants.unknownError;
      try {
        final data = json.decode(response.body);
        message = data['message'] ?? data['error'] ?? message;
      } catch (_) {}

      throw ApiException(
        message,
        statusCode: response.statusCode,
        data: response.body,
      );
    }
  }

  /// Handle network errors
  dynamic _handleError(dynamic error) {
    debugPrint('API Error: $error');

    if (error is SocketException) {
      throw ApiException(AppConstants.networkError);
    } else if (error is http.ClientException) {
      throw ApiException(AppConstants.networkError);
    } else if (error is ApiException) {
      throw error;
    } else {
      throw ApiException(AppConstants.unknownError);
    }
  }

  /// GET request
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    try {
      var uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      if (kDebugMode) {
        print('GET Request: $uri');
      }

      final response = await _client
          .get(
            uri,
            headers: _getHeaders(includeAuth: requiresAuth),
          )
          .timeout(AppConstants.apiTimeout);

      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// POST request
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');

      if (kDebugMode) {
        print('POST Request: $uri');
        print('Body: ${json.encode(body)}');
      }

      final response = await _client
          .post(
            uri,
            headers: _getHeaders(includeAuth: requiresAuth),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(AppConstants.apiTimeout);

      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// PUT request
  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');

      if (kDebugMode) {
        print('PUT Request: $uri');
        print('Body: ${json.encode(body)}');
      }

      final response = await _client
          .put(
            uri,
            headers: _getHeaders(includeAuth: requiresAuth),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(AppConstants.apiTimeout);

      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// PATCH request
  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');

      if (kDebugMode) {
        print('PATCH Request: $uri');
        print('Body: ${json.encode(body)}');
      }

      final response = await _client
          .patch(
            uri,
            headers: _getHeaders(includeAuth: requiresAuth),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(AppConstants.apiTimeout);

      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// DELETE request
  Future<dynamic> delete(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');

      if (kDebugMode) {
        print('DELETE Request: $uri');
      }

      final response = await _client
          .delete(
            uri,
            headers: _getHeaders(includeAuth: requiresAuth),
          )
          .timeout(AppConstants.apiTimeout);

      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Dispose client
  void dispose() {
    _client.close();
  }
}
