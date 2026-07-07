import '../core/api_client.dart';
import '../core/config.dart';

String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;

class FollowStats {
  FollowStats({
    required this.followerCount,
    required this.followingCount,
    required this.isFollowing,
  });

  final int followerCount;
  final int followingCount;
  final bool isFollowing;

  factory FollowStats.fromJson(Map<String, dynamic> json) => FollowStats(
        followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
        followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
        isFollowing: json['isFollowing'] == true,
      );
}

class FollowUserItem {
  FollowUserItem({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String email;
  final String? avatarUrl;

  factory FollowUserItem.fromJson(Map<String, dynamic> json) => FollowUserItem(
        id: _str(json['id']) ?? '',
        username: _str(json['username']) ?? '',
        email: _str(json['email']) ?? '',
        // The follows API may return the avatar as a raw R2 key — absolutize.
        avatarUrl: toAbsoluteMediaUrl(_str(json['avatarUrl'])),
      );
}

/// Port of src/services/followService.ts.
class FollowService {
  FollowService._();

  static final FollowService instance = FollowService._();

  ApiClient get _api => ApiClient.instance;

  Future<void> follow(String followingId) async {
    await _api.post('/api/v1/follows', {'followingId': followingId});
  }

  Future<void> unfollow(String followingId) async {
    await _api.delete('/api/v1/follows/$followingId');
  }

  Future<FollowStats> getStats(String userId) async {
    final res =
        await _api.get('/api/v1/follows/stats/$userId') as Map<String, dynamic>;
    return FollowStats.fromJson(res);
  }

  Future<List<FollowUserItem>> getFollowers(String userId,
      {int page = 1, int pageSize = 50}) async {
    final res = await _api.get(
            '/api/v1/follows/followers/$userId?page=$page&pageSize=$pageSize')
        as Map<String, dynamic>;
    return _extractUsers(res, 'follower');
  }

  Future<List<FollowUserItem>> getFollowing(String userId,
      {int page = 1, int pageSize = 50}) async {
    final res = await _api.get(
            '/api/v1/follows/following/$userId?page=$page&pageSize=$pageSize')
        as Map<String, dynamic>;
    return _extractUsers(res, 'following');
  }

  List<FollowUserItem> _extractUsers(Map<String, dynamic> res, String key) {
    return (res['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((rel) => rel[key])
        .whereType<Map<String, dynamic>>()
        .map(FollowUserItem.fromJson)
        .toList();
  }
}
