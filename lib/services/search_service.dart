import '../core/api_client.dart';
import '../models/post.dart';
import '../models/search.dart';

/// Port of src/services/searchService.ts.
class SearchService {
  SearchService._();

  static final SearchService instance = SearchService._();

  ApiClient get _api => ApiClient.instance;

  /// Search both posts and users in a single request — GET /api/v1/search?q=...&limit=...
  Future<SearchAllResult> searchAll(String query, {int limit = 5}) async {
    final q = query.trim();
    if (q.isEmpty) {
      return SearchAllResult(posts: const [], users: const [], query: '');
    }

    final res = await _api.get(
      '/api/v1/search?q=${Uri.encodeComponent(q)}&limit=$limit',
    );

    if (res is! Map<String, dynamic>) {
      return SearchAllResult(posts: const [], users: const [], query: q);
    }

    final postsMap = res['posts'] is Map<String, dynamic>
        ? res['posts'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawPosts = (postsMap['posts'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where(FeedPost.notRemoved)
        .map(FeedPost.fromJson)
        .toList();

    final usersMap = res['users'] is Map<String, dynamic>
        ? res['users'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawUsers = (usersMap['users'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SearchUserItem.fromJson)
        .toList();

    return SearchAllResult(
      posts: rawPosts,
      users: rawUsers,
      query: (res['query'] ?? q).toString(),
    );
  }

  /// Search posts with filters and pagination — GET /api/v1/search/posts?q=...
  Future<SearchPostsResult> searchPosts(
    String query, {
    String? subjectId,
    String? tag,
    String? sortBy,
    int page = 1,
    int pageSize = 10,
  }) async {
    final queryParams = <String, String>{
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (subjectId != null && subjectId.isNotEmpty) 'subjectId': subjectId,
      if (tag != null && tag.isNotEmpty) 'tag': tag,
      if (sortBy != null && sortBy.isNotEmpty) 'sortBy': sortBy,
      'page': '$page',
      'pageSize': '$pageSize',
    };

    final qs = Uri(queryParameters: queryParams).query;
    final res = await _api.get('/api/v1/search/posts?$qs');

    if (res is! Map<String, dynamic>) {
      return SearchPostsResult(
        posts: const [],
        total: 0,
        page: page,
        pageSize: pageSize,
        totalPages: 1,
      );
    }

    final rawPosts = (res['posts'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where(FeedPost.notRemoved)
        .map(FeedPost.fromJson)
        .toList();

    return SearchPostsResult(
      posts: rawPosts,
      total: (res['total'] as num?)?.toInt() ?? rawPosts.length,
      page: (res['page'] as num?)?.toInt() ?? page,
      pageSize: (res['pageSize'] as num?)?.toInt() ?? pageSize,
      totalPages: (res['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  /// Search users with pagination — GET /api/v1/search/users?q=...
  Future<SearchUsersResult> searchUsers(
    String query, {
    int page = 1,
    int pageSize = 10,
  }) async {
    final q = query.trim();
    final queryParams = <String, String>{
      if (q.isNotEmpty) 'q': q,
      'page': '$page',
      'pageSize': '$pageSize',
    };

    final qs = Uri(queryParameters: queryParams).query;
    final res = await _api.get('/api/v1/search/users?$qs');

    if (res is! Map<String, dynamic>) {
      return SearchUsersResult(
        users: const [],
        total: 0,
        page: page,
        pageSize: pageSize,
        totalPages: 1,
      );
    }

    final rawUsers = (res['users'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SearchUserItem.fromJson)
        .toList();

    return SearchUsersResult(
      users: rawUsers,
      total: (res['total'] as num?)?.toInt() ?? rawUsers.length,
      page: (res['page'] as num?)?.toInt() ?? page,
      pageSize: (res['pageSize'] as num?)?.toInt() ?? pageSize,
      totalPages: (res['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}
