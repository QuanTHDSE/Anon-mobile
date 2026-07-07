import 'dart:convert';

import '../core/api_client.dart';
import '../models/user.dart';

/// Port of src/services/authService.ts — login/register/forgot-password,
/// JWT payload decoding, local user persistence.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  ApiClient get _api => ApiClient.instance;

  AppUser? getCurrentUser() => AppUser.decode(_api.readUserJson());

  bool get isLoggedIn =>
      _api.token != null && _api.token!.isNotEmpty && getCurrentUser() != null;

  Future<AppUser> login(String email, String password) async {
    final res = await _api.post('/api/v1/auth/login', {
      'email': email,
      'password': password,
    }) as Map<String, dynamic>;
    return _storeAuthResponse(res, fallbackEmail: email);
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String anonAlias,
  }) async {
    final res = await _api.post('/api/v1/auth/register', {
      'username': username,
      'email': email,
      'password': password,
      'anonAlias': anonAlias,
    }) as Map<String, dynamic>?;
    final data = res ?? <String, dynamic>{};
    if (_extractToken(data).isNotEmpty) {
      await _storeAuthResponse(data,
          fallbackEmail: email, fallbackName: username);
    }
    return data;
  }

  Future<void> forgotPassword(String email) async {
    await _api.post('/api/v1/auth/forgot-password', {'email': email});
  }

  Future<void> resetPassword(
      String email, String token, String newPassword) async {
    await _api.post('/api/v1/auth/reset-password', {
      'email': email,
      'token': token,
      'newPassword': newPassword,
    });
  }

  Future<void> verifyEmail(String email, String token) async {
    await _api.post('/api/v1/auth/verify-email', {
      'email': email,
      'token': token,
    });
  }

  Future<void> logout() async {
    final access = _api.token;
    final refresh = _api.refreshToken;
    if (access != null && refresh != null) {
      try {
        await _api.post('/api/v1/auth/logout', {
          'accessToken': access,
          'refreshToken': refresh,
        });
      } catch (_) {}
    }
    await _api.clearSession();
  }

  // ── helpers ─────────────────────────────────────────

  String _extractToken(Map<String, dynamic> res) =>
      (res['token'] ?? res['accessToken'] ?? '').toString();

  Future<AppUser> _storeAuthResponse(
    Map<String, dynamic> res, {
    String? fallbackEmail,
    String? fallbackName,
  }) async {
    final token = _extractToken(res);
    await _api.saveTokens(
      accessToken: token,
      refresh: (res['refreshToken'] ?? res['refresh_token'])?.toString(),
    );

    final jwt = decodeJwtPayload(token);
    final userObj = res['user'] is Map<String, dynamic>
        ? res['user'] as Map<String, dynamic>
        : const <String, dynamic>{};

    String? s(dynamic v) => v is String && v.isNotEmpty ? v : null;

    final name = s(fallbackName) ??
        s(userObj['username']) ??
        s(userObj['name']) ??
        s(jwt['username']) ??
        s(jwt['name']) ??
        s(jwt['preferred_username']) ??
        (s(jwt['sub']) != null && !jwt['sub'].toString().contains('@')
            ? s(jwt['sub'])
            : null) ??
        s(userObj['email'])?.split('@').first ??
        s(jwt['email'])?.split('@').first ??
        fallbackEmail?.split('@').first ??
        'User';

    final email =
        s(userObj['email']) ?? s(jwt['email']) ?? fallbackEmail ?? '';
    final id =
        s(res['userId']) ?? s(userObj['id']) ?? s(jwt['sub']) ?? '';
    final role = _roleFromJwt(jwt) == 'admin' ? 'admin' : 'user';

    final user = AppUser(id: id, email: email, name: name, role: role);
    await _api.saveUserJson(user.encode());
    return user;
  }

  String? _roleFromJwt(Map<String, dynamic> jwt) {
    final candidates = [
      jwt['role'],
      jwt['roles'],
      jwt['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'],
    ];
    for (final c in candidates) {
      if (c is String && c.isNotEmpty) return c.toLowerCase();
      if (c is List) {
        final first = c.whereType<String>().firstOrNull;
        if (first != null) return first.toLowerCase();
      }
    }
    return null;
  }
}

/// Decode a JWT payload as UTF-8 JSON (Vietnamese-safe).
Map<String, dynamic> decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length < 2) return {};
    final normalized = base64Url.normalize(parts[1]);
    final json = utf8.decode(base64Url.decode(normalized));
    final decoded = jsonDecode(json);
    return decoded is Map<String, dynamic> ? decoded : {};
  } catch (_) {
    return {};
  }
}
