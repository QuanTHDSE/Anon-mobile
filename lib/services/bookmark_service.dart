import '../core/api_client.dart';
import '../core/config.dart';

String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;

/// A bookmarked post row — tolerant of both wrapper and flat shapes,
/// port of src/services/bookmarkService.ts extractPost.
class BookmarkPost {
  BookmarkPost({
    required this.id,
    required this.postId,
    required this.createdAt,
    this.title,
    this.content,
    required this.isAnonymous,
    required this.images,
    required this.tags,
    this.subjectName,
    required this.authorName,
    this.authorAvatar,
    this.authorId = '',
    required this.likesCount,
    required this.commentsCount,
  });

  final String id;
  final String postId;
  final DateTime createdAt;
  final String? title;
  final String? content;
  final bool isAnonymous;
  final List<String> images;
  final List<String> tags;
  final String? subjectName;
  final String authorName;
  final String? authorAvatar;
  final String authorId;
  final int likesCount;
  final int commentsCount;

  factory BookmarkPost.fromJson(Map<String, dynamic> raw) {
    final embedded = raw['post'];
    final source =
        embedded is Map<String, dynamic> ? embedded : raw;
    final isAnon = source['isAnonymous'] == true;

    final authorRaw = source['author'];
    final a = authorRaw is Map<String, dynamic>
        ? authorRaw
        : const <String, dynamic>{};
    // For anon posts only trust the post-level `authorAvatarUrl` (the anon
    // image); never fall back to the nested real avatar.
    final postAvatarUrl = _str(source['authorAvatarUrl']);
    final rawAvatar = isAnon
        ? postAvatarUrl
        : (postAvatarUrl ?? _str(a['avatar']) ?? _str(a['avatarUrl']));

    final name = isAnon
        ? (_str(source['authorAnonAlias']) ??
            _str(source['authorUsername']) ??
            _str(a['name']) ??
            'Ẩn danh')
        : (_str(a['name']) ??
            _str(a['username']) ??
            _str(source['authorUsername']) ??
            'Người dùng');

    return BookmarkPost(
      id: _str(raw['id']) ?? '',
      postId: _str(raw['postId']) ?? _str(source['id']) ?? '',
      createdAt:
          DateTime.tryParse(_str(raw['createdAt']) ?? '') ?? DateTime.now(),
      title: _str(source['title']),
      content: _str(source['content']),
      isAnonymous: isAnon,
      images: _extractImages(source),
      tags: source['tags'] is List
          ? (source['tags'] as List).whereType<String>().toList()
          : const [],
      subjectName: _str(source['subjectName']) ??
          (source['subject'] is Map
              ? _str((source['subject'] as Map)['name'])
              : null),
      authorName: name,
      authorAvatar: toAbsoluteMediaUrl(rawAvatar),
      authorId: _str(a['id']) ?? _str(source['authorId']) ?? '',
      likesCount: ((source['likesCount'] ??
              source['upvotes'] ??
              source['upvoteCount'] ??
              0) as num)
          .toInt(),
      commentsCount:
          ((source['commentsCount'] ?? source['commentCount'] ?? 0) as num)
              .toInt(),
    );
  }

  static List<String> _extractImages(Map<String, dynamic> source) {
    final media = source['media'];
    if (media is List) {
      final urls = media
          .whereType<Map<String, dynamic>>()
          .where((m) =>
              (m['mediaType']?.toString().toLowerCase() ?? '') != 'file')
          .map((m) =>
              _str(m['fileUrl']) ?? _str(m['url']) ?? _str(m['fileKey']))
          .whereType<String>()
          .map((u) => toAbsoluteMediaUrl(u)!)
          .toList();
      if (urls.isNotEmpty) return urls;
    }
    final legacy = source['imageUrls'] ?? source['images'];
    if (legacy is List) {
      return legacy
          .whereType<String>()
          .map((u) => toAbsoluteMediaUrl(u)!)
          .toList();
    }
    return const [];
  }
}

/// Port of src/services/bookmarkService.ts.
class BookmarkService {
  BookmarkService._();

  static final BookmarkService instance = BookmarkService._();

  ApiClient get _api => ApiClient.instance;

  Future<List<BookmarkPost>> getBookmarks(
      {String? search, int page = 1, int pageSize = 50}) async {
    final q = <String, String>{
      if (search != null && search.isNotEmpty) 'search': search,
      'page': '$page',
      'pageSize': '$pageSize',
    };
    final res =
        await _api.get('/api/v1/bookmarks?${Uri(queryParameters: q).query}');
    List raw;
    if (res is List) {
      raw = res;
    } else if (res is Map<String, dynamic>) {
      raw = (res['items'] ??
          res['bookmarks'] ??
          res['data'] ??
          res['results'] ??
          []) as List;
    } else {
      raw = const [];
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(BookmarkPost.fromJson)
        .toList();
  }

  /// Set of bookmarked post ids — used to light up bookmark buttons in feeds.
  Future<Set<String>> getBookmarkedPostIds() async {
    try {
      final items = await getBookmarks(pageSize: 100);
      return items.map((b) => b.postId).where((id) => id.isNotEmpty).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> addBookmark(String postId) async {
    await _api.post('/api/v1/bookmarks', {'postId': postId});
  }

  Future<void> removeBookmark(String postId) async {
    await _api.delete('/api/v1/bookmarks/$postId');
  }
}
