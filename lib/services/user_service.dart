import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../models/user.dart';
import 'search_service.dart';
import 'subscription_service.dart';

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

  Future<List<TopContributor>> getTopContributors({
    int limit = 20,
    int? month,
    int? year,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      if (month != null) 'month': '$month',
      if (year != null) 'year': '$year',
    };
    final qs = Uri(queryParameters: query).query;
    final res = await _api.get('/api/v1/users/top-contributors?$qs');
    if (res is! Map<String, dynamic>) return const [];
    final list = (res['contributors'] ?? res['items'] ?? []) as List;
    return list
        .whereType<Map<String, dynamic>>()
        .map(TopContributor.fromJson)
        .toList();
  }

  // ── author info cache (avatars + premium), like the web app ──
  final Map<String, UserProfile?> _userCache = {};
  final Map<String, bool> _premiumCache = {};
  final Map<String, DateTime> _premiumCacheTime = {};
  final Map<String, Future<bool>> _premiumInflight = {};

  static const Duration _premiumCacheTtl = Duration(minutes: 5);

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

  /// Resolves public Premium status from the user profile first, then falls
  /// back to active subscriptions. Results are cached briefly because author
  /// names can occur many times across feeds, comments and community lists.
  Future<bool> getUserPremium(String id, {String? username}) {
    if (id.isEmpty) return Future.value(false);

    final cachedAt = _premiumCacheTime[id];
    if (cachedAt != null &&
        DateTime.now().difference(cachedAt) < _premiumCacheTtl) {
      return Future.value(_premiumCache[id] ?? false);
    }

    final inFlight = _premiumInflight[id];
    if (inFlight != null) return inFlight;

    final request = () async {
      var profile = _userCache[id];
      var publicStatusResolved = false;
      var isPremium = profile?.isPremium == true;
      var searchName = username?.trim() ?? '';

      if (!isPremium && searchName.isEmpty) {
        profile = await fetchUserCached(id);
        isPremium = profile?.isPremium == true;
        searchName = profile?.username.trim() ?? '';
      }

      // The public user detail currently omits Premium status, while the
      // public user-search DTO exposes the authoritative
      // `hasActiveSubscription` field. Match by id so similar usernames never
      // receive the wrong badge.
      if (!isPremium && searchName.isNotEmpty) {
        try {
          final result = await SearchService.instance.searchUsers(
            searchName,
            pageSize: 20,
          );
          for (final user in result.users) {
            if (user.id == id) {
              isPremium = user.hasActiveSubscription;
              publicStatusResolved = true;
              break;
            }
          }
        } catch (_) {
          // Fall through to the authenticated subscription endpoint.
        }
      }

      if (!isPremium && !publicStatusResolved) {
        isPremium = await SubscriptionService.instance.fetchPremiumStatus(id);
      }
      _premiumCache[id] = isPremium;
      _premiumCacheTime[id] = DateTime.now();
      return isPremium;
    }();

    _premiumInflight[id] = request;
    request.whenComplete(() => _premiumInflight.remove(id));
    return request;
  }
}
