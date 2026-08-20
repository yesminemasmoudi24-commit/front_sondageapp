import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'api_exception.dart';
import 'api_response.dart';

/// Client HTTP compatible avec Laravel Sanctum + format ApiResponse.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const _tokenKey = 'auth_token';

  final http.Client _client;
  String? _token;

  String? get token => _token;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${ApiConfig.baseUrl}$normalized').replace(queryParameters: query);
  }

  Map<String, String> _headers({bool jsonBody = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      // Évite le cache navigateur (Flutter web) qui garde d'anciennes listes GET.
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      if (jsonBody) 'Content-Type': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  static const Duration _timeout = Duration(seconds: 20);

  Future<http.Response> _withTimeout(Future<http.Response> future) {
    return future.timeout(
      _timeout,
      onTimeout: () => throw ApiException(
        'Le serveur ne répond pas (timeout). Vérifie que Laravel tourne.',
        statusCode: 408,
      ),
    );
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? query,
    T Function(dynamic raw)? parser,
  }) async {
    final response = await _withTimeout(
      _client.get(_uri(path, query), headers: _headers()),
    );
    return _handle(response, parser);
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic raw)? parser,
  }) async {
    final response = await _withTimeout(
      _client.post(
        _uri(path),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _handle(response, parser);
  }

  Future<ApiResponse<T>> put<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic raw)? parser,
  }) async {
    final response = await _withTimeout(
      _client.put(
        _uri(path),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _handle(response, parser);
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    T Function(dynamic raw)? parser,
  }) async {
    final response = await _withTimeout(
      _client.delete(_uri(path), headers: _headers()),
    );
    return _handle(response, parser);
  }

  /// Télécharge un fichier binaire (PDF / Excel export).
  Future<List<int>> getBytes(String path) async {
    final response = await _withTimeout(
      _client.get(
        _uri(path),
        headers: _headers(jsonBody: false),
      ),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw ApiException(
      'Download failed (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  ApiResponse<T> _handle<T>(
    http.Response response,
    T Function(dynamic raw)? parser,
  ) {
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      json = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'success': false, 'message': 'Invalid JSON', 'data': decoded};
    } catch (_) {
      throw ApiException(
        'Invalid server response (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final api = ApiResponse.fromJson(json, parser: parser);

    if (response.statusCode >= 200 && response.statusCode < 300 && api.success) {
      return api;
    }

    throw ApiException(
      api.message.isNotEmpty ? api.message : 'Request failed',
      statusCode: response.statusCode,
      errors: api.errors ?? json['errors'],
    );
  }
}
