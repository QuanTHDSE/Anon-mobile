import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Error surfaced from the API with a user-readable (Vietnamese) message.
/// Mirrors the error extraction in the web app's apiClient.ts.
class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// HTTP client for the AnonWork API. Port of src/services/apiClient.ts:
/// Bearer token auth, automatic refresh on 401, tolerant error extraction.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const String _tokenKey = 'anon.token';
  static const String _refreshTokenKey = 'anon.refreshToken';
  static const String _userKey = 'anon.user';

  SharedPreferences? _prefs;
  String? token;
  String? refreshToken;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    token = _prefs!.getString(_tokenKey);
    refreshToken = _prefs!.getString(_refreshTokenKey);
  }

  Future<void> saveTokens({String? accessToken, String? refresh}) async {
    if (accessToken != null && accessToken.isNotEmpty) {
      token = accessToken;
      await _prefs?.setString(_tokenKey, accessToken);
    }
    if (refresh != null && refresh.isNotEmpty) {
      refreshToken = refresh;
      await _prefs?.setString(_refreshTokenKey, refresh);
    }
  }

  Future<void> saveUserJson(String json) async {
    await _prefs?.setString(_userKey, json);
  }

  String? readUserJson() => _prefs?.getString(_userKey);

  Future<void> clearSession() async {
    token = null;
    refreshToken = null;
    await _prefs?.remove(_tokenKey);
    await _prefs?.remove(_refreshTokenKey);
    await _prefs?.remove(_userKey);
  }

  Map<String, String> _headers({bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path) => _request('GET', path);

  Future<dynamic> post(String path, [Object? body]) =>
      _request('POST', path, body: body ?? <String, dynamic>{});

  Future<dynamic> put(String path, [Object? body]) =>
      _request('PUT', path, body: body ?? <String, dynamic>{});

  Future<dynamic> patch(String path, [Object? body]) =>
      _request('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _request('DELETE', path);

  /// Multipart request (create/update post, update profile...). `method` may
  /// be POST, PUT or PATCH.
  ///
  /// For repeated list fields (e.g. `Tags`) pass indexed keys — ASP.NET Core
  /// binds `Tags[0]`, `Tags[1]`, ... to `List<string> Tags`. Repeated files
  /// with the same field name are supported natively via [files].
  Future<dynamic> multipart(
    String method,
    String path, {
    Map<String, String> fields = const {},
    List<http.MultipartFile> files = const [],
    bool retried = false,
  }) async {
    final req = http.MultipartRequest(method, Uri.parse('$apiBaseUrl$path'));
    if (token != null && token!.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.fields.addAll(fields);
    req.files.addAll(files);

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 401 && !retried && await _tryRefresh()) {
      return multipart(method, path,
          fields: fields, files: files, retried: true);
    }
    return _handleResponse(res);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    bool retried = false,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final headers = _headers();
    late http.Response res;
    switch (method) {
      case 'GET':
        res = await http.get(uri, headers: headers);
      case 'POST':
        res = await http.post(uri, headers: headers, body: jsonEncode(body));
      case 'PUT':
        res = await http.put(uri, headers: headers, body: jsonEncode(body));
      case 'PATCH':
        res = await http.patch(uri,
            headers: headers, body: body == null ? null : jsonEncode(body));
      case 'DELETE':
        res = await http.delete(uri, headers: headers);
      default:
        throw ArgumentError('Unsupported method $method');
    }

    final isAuthEndpoint = path.startsWith('/api/v1/auth/');
    if (res.statusCode == 401 && !retried && !isAuthEndpoint) {
      if (await _tryRefresh()) {
        return _request(method, path, body: body, retried: true);
      }
      await clearSession();
      throw ApiException(
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.', 401);
    }
    return _handleResponse(res);
  }

  dynamic _handleResponse(http.Response res) {
    if (res.statusCode == 403) {
      final detail = _extractError(res);
      throw ApiException(
        detail.startsWith('HTTP ')
            ? 'Không có quyền thực hiện thao tác này.'
            : detail,
        403,
      );
    }
    if (res.statusCode >= 400) {
      throw ApiException(_extractError(res), res.statusCode);
    }
    if (res.statusCode == 204 || res.bodyBytes.isEmpty) return null;
    final contentType = res.headers['content-type'] ?? '';
    if (!contentType.contains('application/json')) return null;
    // Always decode as UTF-8 so Vietnamese text doesn't turn into mojibake.
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  String _extractError(http.Response res) {
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map<String, dynamic>) {
        // ASP.NET Core ModelState validation errors
        final errors = body['errors'];
        if (errors is Map<String, dynamic>) {
          final msgs = errors.values
              .whereType<List>()
              .expand((e) => e)
              .map((e) => e.toString())
              .toList();
          if (msgs.isNotEmpty) return msgs.join(', ');
        }
        final message = body['message'];
        if (message is List) return message.join(', ');
        final text = (message ?? body['error'] ?? body['title'])?.toString();
        if (text != null && text.isNotEmpty) return text;
      }
    } catch (_) {}
    return 'HTTP ${res.statusCode}';
  }

  Future<bool> _tryRefresh() async {
    final rt = refreshToken;
    if (rt == null || rt.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/api/v1/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': rt}),
      );
      if (res.statusCode >= 400) return false;
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is! Map<String, dynamic>) return false;
      final newToken = (data['token'] ?? data['accessToken'])?.toString();
      if (newToken == null || newToken.isEmpty) return false;
      await saveTokens(
        accessToken: newToken,
        refresh: (data['refreshToken'] ?? data['refresh_token'])?.toString(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
