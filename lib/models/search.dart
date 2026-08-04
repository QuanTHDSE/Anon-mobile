import '../core/config.dart';
import 'post.dart';

String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;
int _int(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

class SearchUserItem {
  SearchUserItem({
    required this.id,
    required this.username,
    this.email,
    this.avatarUrl,
    this.bio,
    required this.anonAlias,
    required this.followerCount,
    required this.followingCount,
    required this.hasActiveSubscription,
    this.createdAt,
  });

  final String id;
  final String username;
  final String? email;
  final String? avatarUrl;
  final String? bio;
  final String anonAlias;
  final int followerCount;
  final int followingCount;
  final bool hasActiveSubscription;
  final DateTime? createdAt;

  factory SearchUserItem.fromJson(Map<String, dynamic> json) => SearchUserItem(
        id: _str(json['id']) ?? '',
        username: _str(json['username']) ?? '',
        email: _str(json['email']),
        avatarUrl: toAbsoluteMediaUrl(_str(json['avatarUrl']) ?? _str(json['avatarKey'])),
        bio: _str(json['bio']),
        anonAlias: _str(json['anonAlias']) ?? '',
        followerCount: _int(json['followerCount']),
        followingCount: _int(json['followingCount']),
        hasActiveSubscription: json['hasActiveSubscription'] == true,
        createdAt: DateTime.tryParse(_str(json['createdAt']) ?? ''),
      );
}

class SearchAllResult {
  SearchAllResult({
    required this.posts,
    required this.users,
    required this.query,
  });

  final List<FeedPost> posts;
  final List<SearchUserItem> users;
  final String query;
}

class SearchPostsResult {
  SearchPostsResult({
    required this.posts,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<FeedPost> posts;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
}

class SearchUsersResult {
  SearchUsersResult({
    required this.users,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<SearchUserItem> users;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
}
