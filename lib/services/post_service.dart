import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../models/post.dart';

/// Port of src/services/postService.ts.
class PostService {
  PostService._();

  static final PostService instance = PostService._();

  ApiClient get _api => ApiClient.instance;

  Future<PaginatedPosts> getPosts({
    String? search,
    int page = 1,
    int pageSize = 10,
    String? authorId,
  }) async {
    final query = <String, String>{
      if (search != null && search.isNotEmpty) 'search': search,
      'page': '$page',
      'pageSize': '$pageSize',
      if (authorId != null) 'authorId': authorId,
    };
    final qs = Uri(queryParameters: query).query;
    final res = await _api.get('/api/v1/posts?$qs') as Map<String, dynamic>;
    final rawPosts = (res['posts'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where(FeedPost.notRemoved)
        .map(FeedPost.fromJson)
        .toList();
    return PaginatedPosts(
      posts: rawPosts,
      total: (res['total'] as num?)?.toInt() ?? rawPosts.length,
      page: (res['page'] as num?)?.toInt() ?? page,
      pageSize: (res['pageSize'] as num?)?.toInt() ?? pageSize,
      totalPages: (res['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  /// Top / trending posts — GET /api/v1/posts/top.
  Future<List<FeedPost>> getTopPosts({
    String range = '30d',
    String sort = 'hot',
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _api.get(
            '/api/v1/posts/top?range=$range&sort=$sort&page=$page&pageSize=$pageSize')
        as Map<String, dynamic>;
    return (res['posts'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where(FeedPost.notRemoved)
        .map(FeedPost.fromJson)
        .toList();
  }

  Future<FeedPost> getPostById(String id) async {
    final res = await _api.get('/api/v1/posts/$id') as Map<String, dynamic>;
    return FeedPost.fromJson(res);
  }

  Future<List<Subject>> getSubjects({int pageSize = 100}) async {
    final res = await _api.get('/api/v1/subjects?pageSize=$pageSize')
        as Map<String, dynamic>;
    return (res['subjects'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Subject.fromJson)
        .toList();
  }

  Future<void> createPost({
    required String title,
    required String content,
    required String subjectId,
    List<String> tags = const [],
    bool isAnonymous = false,
    List<http.MultipartFile> images = const [],
  }) async {
    final fields = <String, String>{
      'Title': title,
      'Content': content,
      'SubjectId': subjectId,
      'IsAnonymous': '$isAnonymous',
    };
    // ASP.NET Core binds indexed keys to List<string> Tags.
    for (var i = 0; i < tags.length; i++) {
      fields['Tags[$i]'] = tags[i];
    }
    await _api.multipart('POST', '/api/v1/posts',
        fields: fields, files: images);
  }

  Future<void> updatePost(
    String id, {
    String? title,
    String? content,
    List<String> tags = const [],
    List<http.MultipartFile> newImages = const [],
    List<String> removeFileIds = const [],
  }) async {
    final fields = <String, String>{
      if (title != null) 'Title': title,
      if (content != null) 'Content': content,
    };
    for (var i = 0; i < tags.length; i++) {
      fields['Tags[$i]'] = tags[i];
    }
    for (var i = 0; i < removeFileIds.length; i++) {
      fields['RemoveFileId[$i]'] = removeFileIds[i];
    }
    await _api.multipart('PUT', '/api/v1/posts/$id',
        fields: fields, files: newImages);
  }

  Future<void> deletePost(String id) async {
    await _api.delete('/api/v1/posts/$id');
  }

  Future<void> upvotePost(String id) async {
    await _api.post('/api/v1/posts/$id/upvote');
  }
}
