import 'dart:convert';

String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;

/// Lightweight signed-in identity persisted locally (port of web `User`).
class AppUser {
  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  final String id;
  final String email;
  final String name;
  final String role; // "user" | "admin"

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: _str(json['id']) ?? '',
        email: _str(json['email']) ?? '',
        name: _str(json['name']) ?? 'User',
        role: _str(json['role']) ?? 'user',
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'email': email, 'name': name, 'role': role};

  String encode() => jsonEncode(toJson());

  static AppUser? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

/// Full profile from GET /api/v1/users/me (port of web `UserProfile`).
class UserProfile {
  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.bio,
    required this.anonAlias,
    this.anonImageId,
    this.anonImageUrl,
    this.role = 'user',
    this.createdAt,
    this.isPremium,
    this.isAnonDefault,
  });

  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? bio;
  final String anonAlias;
  final String? anonImageId;
  final String? anonImageUrl;
  final String role;
  final DateTime? createdAt;
  final bool? isPremium;
  final bool? isAnonDefault;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: _str(json['id']) ?? '',
        username: _str(json['username']) ?? '',
        email: _str(json['email']) ?? '',
        avatarUrl: _str(json['avatarUrl']),
        bio: _str(json['bio']),
        anonAlias: _str(json['anonAlias']) ?? '',
        anonImageId: _str(json['anonImageId']),
        anonImageUrl: _str(json['anonImageUrl']),
        role: _str(json['role']) ?? 'user',
        createdAt: DateTime.tryParse(_str(json['createdAt']) ?? ''),
        isPremium: json['isPremium'] is bool ? json['isPremium'] as bool : null,
        isAnonDefault:
            json['isAnonDefault'] is bool ? json['isAnonDefault'] as bool : null,
      );
}

/// Top Contributor model from GET /api/v1/users/top-contributors.
class TopContributor {
  TopContributor({
    required this.rank,
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.isAnonymous,
    required this.postsCount,
    required this.commentsCount,
    required this.upvotesReceived,
    required this.averageRating,
    required this.contributionScore,
  });

  final int rank;
  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isAnonymous;
  final int postsCount;
  final int commentsCount;
  final int upvotesReceived;
  final double averageRating;
  final int contributionScore;

  factory TopContributor.fromJson(Map<String, dynamic> json) => TopContributor(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        userId: _str(json['userId']) ?? '',
        username: _str(json['username']) ?? '',
        displayName: _str(json['displayName']) ?? _str(json['username']) ?? 'User',
        avatarUrl: _str(json['avatarUrl']),
        isAnonymous: json['isAnonymous'] as bool? ?? false,
        postsCount: (json['postsCount'] as num?)?.toInt() ?? 0,
        commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
        upvotesReceived: (json['upvotesReceived'] as num?)?.toInt() ?? 0,
        averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
        contributionScore: (json['contributionScore'] as num?)?.toInt() ?? 0,
      );
}
