import '../core/config.dart';

String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;
int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);

class Subject {
  Subject({
    required this.id,
    required this.name,
    this.slug = '',
    this.iconEmoji = '',
  });

  final String id;
  final String name;
  final String slug;
  final String iconEmoji;

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: _str(json['id']) ?? '',
        name: _str(json['name']) ?? '',
        slug: _str(json['slug']) ?? '',
        iconEmoji: _str(json['iconEmoji']) ?? '',
      );
}

class PostMedia {
  PostMedia({
    required this.id,
    required this.url,
    this.contentType,
    this.fileName,
    this.fileSize,
    this.displayOrder,
    required this.isImage,
  });

  final String id;
  final String url;
  final String? contentType;
  final String? fileName;
  final int? fileSize;
  final int? displayOrder;
  final bool isImage;

  static PostMedia? fromJson(Map<String, dynamic> json) {
    final url = _str(json['fileUrl']) ?? _str(json['url']);
    if (url == null) return null;
    final mediaType = (_str(json['mediaType']) ?? '').toLowerCase();
    return PostMedia(
      id: _str(json['id']) ?? '',
      url: toAbsoluteMediaUrl(url)!,
      contentType: _str(json['contentType']),
      fileName: _str(json['originalFileName']) ?? _str(json['fileName']),
      fileSize: json['fileSize'] is num ? (json['fileSize'] as num).toInt() : null,
      displayOrder:
          json['displayOrder'] is num ? (json['displayOrder'] as num).toInt() : null,
      isImage: mediaType != 'file',
    );
  }
}

class PostAuthor {
  PostAuthor({required this.id, required this.name, this.avatar});

  final String id;
  final String name;
  final String? avatar;
}

/// Feed post — port of web `FeedPostItem` + `mapPost` (src/services/postService.ts).
class FeedPost {
  FeedPost({
    required this.id,
    required this.title,
    required this.content,
    required this.isAnonymous,
    required this.images,
    required this.media,
    required this.tags,
    this.subject,
    required this.authorId,
    required this.author,
    required this.createdAt,
    required this.likesCount,
    this.hasUpvoted,
    required this.commentsCount,
  });

  final String id;
  final String title;
  final String content;
  final bool isAnonymous;
  final List<String> images;
  final List<PostMedia> media;
  final List<String> tags;
  final Subject? subject;
  final String authorId;
  final PostAuthor author;
  final DateTime createdAt;
  int likesCount;
  bool? hasUpvoted;
  int commentsCount;

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    final isAnon = json['isAnonymous'] == true;

    final media = <PostMedia>[];
    if (json['media'] is List) {
      for (final m in json['media'] as List) {
        if (m is Map<String, dynamic>) {
          final parsed = PostMedia.fromJson(m);
          if (parsed != null) media.add(parsed);
        }
      }
      media.sort(
          (a, b) => (a.displayOrder ?? 0).compareTo(b.displayOrder ?? 0));
    }

    List<String> images;
    if (media.isNotEmpty) {
      images = media.where((m) => m.isImage).map((m) => m.url).toList();
    } else if (json['imageUrls'] is List) {
      images = (json['imageUrls'] as List)
          .whereType<String>()
          .map((u) => toAbsoluteMediaUrl(u)!)
          .toList();
    } else {
      images = const [];
    }

    // For anonymous posts the API returns the anon alias in `authorUsername`.
    final anonName = _str(json['authorAnonAlias']) ??
        _str(json['authorUsername']) ??
        'Ẩn danh';
    final realName = _str(json['authorUsername']) ?? 'Người dùng';
    // `authorAvatarUrl` is the anon-image URL for anonymous posts and the real
    // avatar URL otherwise (may arrive as a raw key — absolutize).
    final avatar = toAbsoluteMediaUrl(_str(json['authorAvatarUrl']));

    return FeedPost(
      id: _str(json['id']) ?? '',
      title: _str(json['title']) ?? '',
      content: _str(json['content']) ?? '',
      isAnonymous: isAnon,
      images: images,
      media: media,
      tags: json['tags'] is List
          ? (json['tags'] as List).whereType<String>().toList()
          : const [],
      subject: json['subjectId'] != null && json['subjectName'] != null
          ? Subject(
              id: _str(json['subjectId']) ?? '',
              name: _str(json['subjectName']) ?? '')
          : null,
      authorId: _str(json['authorId']) ?? '',
      author: isAnon
          ? PostAuthor(id: '', name: anonName, avatar: avatar)
          : PostAuthor(
              id: _str(json['authorId']) ?? '',
              name: realName,
              avatar: avatar),
      createdAt:
          DateTime.tryParse(_str(json['createdAt']) ?? '') ?? DateTime.now(),
      likesCount: _int(json['upvotes'] ?? json['likesCount'] ?? json['upvoteCount']),
      hasUpvoted: (json['isUpvotedByMe'] ??
          json['hasUpvoted'] ??
          json['isUpvoted']) as bool?,
      commentsCount: _int(json['commentsCount'] ??
          json['commentCount'] ??
          json['totalComments']),
    );
  }

  static bool notRemoved(Map<String, dynamic> json) =>
      (_str(json['status']) ?? '').toLowerCase() != 'removed';
}

class PaginatedPosts {
  PaginatedPosts({
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
