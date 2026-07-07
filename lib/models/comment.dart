import '../core/config.dart';

String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;

class CommentAuthor {
  CommentAuthor({required this.id, required this.name, this.avatar});

  final String id;
  final String name;
  final String? avatar;
}

/// Comment — port of web commentService's normalizeComment/normalizeAuthor.
class Comment {
  Comment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.content,
    required this.isAnonymous,
    this.author,
    required this.likesCount,
    required this.createdAt,
    this.updatedAt,
    List<Comment>? replies,
  }) : replies = replies ?? [];

  final String id;
  final String postId;
  final String? parentId;
  final String content;
  final bool isAnonymous;
  final CommentAuthor? author;
  int likesCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<Comment> replies;

  factory Comment.fromJson(Map<String, dynamic> json) {
    final isAnon = json['isAnonymous'] == true;
    return Comment(
      id: _str(json['id']) ?? '',
      postId: _str(json['postId']) ?? '',
      parentId: _str(json['parentId']),
      content: _str(json['content']) ?? '',
      isAnonymous: isAnon,
      author: _authorFrom(json, isAnon),
      likesCount: (json['likesCount'] ?? json['upvotes'] ?? 0) is num
          ? ((json['likesCount'] ?? json['upvotes'] ?? 0) as num).toInt()
          : 0,
      createdAt:
          DateTime.tryParse(_str(json['createdAt']) ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(_str(json['updatedAt']) ?? ''),
    );
  }

  static CommentAuthor? _authorFrom(Map<String, dynamic> json, bool isAnon) {
    final nested = json['author'];
    final n = nested is Map<String, dynamic> ? nested : const <String, dynamic>{};
    final id = _str(n['id']) ?? _str(json['authorId']) ?? '';
    final anonAlias = _str(n['anonAlias']) ?? _str(json['authorAnonAlias']);
    final username =
        _str(n['username']) ?? _str(n['name']) ?? _str(json['authorName']);
    // Anonymous comments must show the anon alias, never the real username.
    final name = isAnon ? (anonAlias ?? 'Ẩn danh') : (username ?? '');
    final rawAvatar = _str(n['avatarUrl']) ?? _str(n['avatar']);
    // Never expose the real avatar on anonymous comments.
    final avatar = isAnon ? null : toAbsoluteMediaUrl(rawAvatar);
    if (id.isEmpty && name.isEmpty) return null;
    return CommentAuthor(id: id, name: name, avatar: avatar);
  }
}
