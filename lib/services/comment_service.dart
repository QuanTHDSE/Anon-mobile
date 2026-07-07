import '../core/api_client.dart';
import '../models/comment.dart';

class PaginatedComments {
  PaginatedComments({required this.comments, required this.total});

  final List<Comment> comments;
  final int total;
}

/// Port of src/services/commentService.ts.
class CommentService {
  CommentService._();

  static final CommentService instance = CommentService._();

  ApiClient get _api => ApiClient.instance;

  Future<PaginatedComments> getComments(String postId,
      {int page = 1, int pageSize = 50}) async {
    final res = await _api
        .get('/api/v1/comments/post/$postId?page=$page&pageSize=$pageSize');
    List raw;
    int total;
    if (res is List) {
      raw = res;
      total = res.length;
    } else if (res is Map<String, dynamic>) {
      raw = (res['comments'] ?? res['items'] ?? res['data'] ?? []) as List;
      total = (res['total'] as num?)?.toInt() ??
          (res['totalCount'] as num?)?.toInt() ??
          raw.length;
    } else {
      raw = const [];
      total = 0;
    }
    final comments = raw
        .whereType<Map<String, dynamic>>()
        .map(Comment.fromJson)
        .toList();
    return PaginatedComments(comments: _buildTree(comments), total: total);
  }

  /// Build one-level reply tree from parentId links.
  List<Comment> _buildTree(List<Comment> flat) {
    final byId = {for (final c in flat) c.id: c};
    final roots = <Comment>[];
    for (final c in flat) {
      final parent = c.parentId != null ? byId[c.parentId] : null;
      if (parent != null) {
        parent.replies.add(c);
      } else {
        roots.add(c);
      }
    }
    return roots;
  }

  Future<Comment> createComment({
    required String postId,
    required String content,
    bool isAnonymous = false,
    String? parentId,
  }) async {
    final res = await _api.post('/api/v1/comments', {
      'postId': postId,
      'content': content,
      'isAnonymous': isAnonymous,
      if (parentId != null) 'parentId': parentId,
    });
    return Comment.fromJson(
        res is Map<String, dynamic> ? res : const <String, dynamic>{});
  }

  Future<void> deleteComment(String commentId) async {
    await _api.delete('/api/v1/comments/$commentId');
  }

  Future<void> upvoteComment(String commentId) async {
    await _api.post('/api/v1/comments/$commentId/upvote');
  }
}
