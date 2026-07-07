import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../models/user.dart';

/// Port of src/services/userService.ts.
class UserService {
  UserService._();

  static final UserService instance = UserService._();

  ApiClient get _api => ApiClient.instance;

  Future<UserProfile> getMe() async {
    final res = await _api.get('/api/v1/users/me') as Map<String, dynamic>;
    return UserProfile.fromJson(res);
  }

  Future<UserProfile> getUserById(String id) async {
    final res = await _api.get('/api/v1/users/$id') as Map<String, dynamic>;
    return UserProfile.fromJson(res);
  }

  /// PUT /api/v1/users/me accepts Username, Bio, Avatar and AnonAlias
  /// (multipart).
  Future<UserProfile> updateMe({
    String? username,
    String? bio,
    String? anonAlias,
    http.MultipartFile? avatarFile,
  }) async {
    final res = await _api.multipart(
      'PUT',
      '/api/v1/users/me',
      fields: {
        if (username != null) 'Username': username,
        if (bio != null) 'Bio': bio,
        if (anonAlias != null) 'AnonAlias': anonAlias,
      },
      files: [if (avatarFile != null) avatarFile],
    ) as Map<String, dynamic>?;
    return UserProfile.fromJson(res ?? const {});
  }

  /// PATCH /api/v1/users/me/anon flips IsAnonDefault on the server (a toggle —
  /// it takes no parameters). Call it only when the desired value differs.
  Future<void> toggleAnonDefault() async {
    await _api.patch('/api/v1/users/me/anon');
  }

  // ── author info cache (avatars + premium), like the web app ──
  final Map<String, UserProfile?> _userCache = {};

  Future<UserProfile?> fetchUserCached(String id) async {
    if (id.isEmpty) return null;
    if (_userCache.containsKey(id)) return _userCache[id];
    try {
      final u = await getUserById(id);
      _userCache[id] = u;
      return u;
    } catch (_) {
      _userCache[id] = null;
      return null;
    }
  }
}
