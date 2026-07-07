import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../services/comment_service.dart';
import '../services/post_service.dart';
import '../state/auth_state.dart';
import '../widgets/author_avatar.dart';
import '../widgets/post_card.dart' show formatRelativeTime;

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  FeedPost? _post;
  List<Comment> _comments = [];
  bool _loading = true;
  String? _error;

  final _commentCtrl = TextEditingController();
  bool _commentAnonymous = false;
  bool _sending = false;
  Comment? _replyTo;

  bool _upvoted = false;
  int _likes = 0;
  bool _busyVote = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        PostService.instance.getPostById(widget.postId),
        CommentService.instance.getComments(widget.postId),
      ]);
      final post = results[0] as FeedPost;
      final comments = results[1] as PaginatedComments;
      setState(() {
        _post = post;
        _comments = comments.comments;
        _upvoted = post.hasUpvoted ?? false;
        _likes = post.likesCount;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleUpvote() async {
    if (_busyVote || _post == null) return;
    setState(() {
      _busyVote = true;
      _upvoted = !_upvoted;
      _likes += _upvoted ? 1 : -1;
    });
    try {
      await PostService.instance.upvotePost(_post!.id);
    } catch (_) {
      setState(() {
        _upvoted = !_upvoted;
        _likes += _upvoted ? 1 : -1;
      });
    } finally {
      if (mounted) setState(() => _busyVote = false);
    }
  }

  Future<void> _sendComment() async {
    final content = _commentCtrl.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await CommentService.instance.createComment(
        postId: widget.postId,
        content: content,
        isAnonymous: _commentAnonymous,
        parentId: _replyTo?.id,
      );
      _commentCtrl.clear();
      setState(() => _replyTo = null);
      final refreshed =
          await CommentService.instance.getComments(widget.postId);
      setState(() => _comments = refreshed.comments);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bài viết')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              : Column(
                  children: [
                    Expanded(child: _buildContent()),
                    _buildCommentInput(),
                  ],
                ),
    );
  }

  Widget _buildContent() {
    final post = _post!;
    final dateStr =
        DateFormat('dd MMMM yyyy, HH:mm', 'vi').format(post.createdAt.toLocal());
    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Author
          Row(
            children: [
              AuthorAvatar(
                imageUrl: post.author.avatar,
                name: post.author.name,
                isAnonymous: post.isAnonymous,
                size: 44,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.author.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(dateStr,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (post.subject != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.orange50,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    post.subject!.name,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(post.title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(post.content,
              style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.textSecondary)),
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: post.tags
                  .map((t) => Text('#$t',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand)))
                  .toList(),
            ),
          ],
          // Images
          for (final img in post.images) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(img,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                        height: 160,
                        color: const Color(0xFFF3F4F6),
                        child: const Icon(Icons.broken_image_outlined,
                            color: AppColors.textMuted),
                      )),
            ),
          ],
          // File attachments
          for (final m in post.media.where((m) => !m.isImage)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined,
                      size: 20, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(m.fileName ?? 'Tệp đính kèm',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: _toggleUpvote,
                icon: Icon(
                  _upvoted ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: _upvoted ? AppColors.danger : AppColors.textMuted,
                ),
                label: Text('$_likes',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _upvoted
                            ? AppColors.danger
                            : AppColors.textMuted)),
              ),
              const SizedBox(width: 8),
              Icon(Icons.mode_comment_outlined,
                  size: 18, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('${_comments.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted)),
            ],
          ),
          const Divider(height: 24),
          const Text('Bình luận',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Chưa có bình luận nào. Hãy là người đầu tiên!',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            ),
          for (final c in _comments) _CommentTile(
            comment: c,
            onReply: (c) => setState(() => _replyTo = c),
            onChanged: _load,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    final isLoggedIn = context.watch<AuthState>().isLoggedIn;
    if (!isLoggedIn) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyTo != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Đang trả lời ${_replyTo!.author?.name ?? "bình luận"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _replyTo = null),
                  ),
                ],
              ),
            Row(
              children: [
                // Anonymous toggle
                Tooltip(
                  message: 'Bình luận ẩn danh',
                  child: GestureDetector(
                    onTap: () => setState(
                        () => _commentAnonymous = !_commentAnonymous),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _commentAnonymous
                            ? AppColors.orange50
                            : const Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.visibility_off_outlined,
                        size: 18,
                        color: _commentAnonymous
                            ? AppColors.brand
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Viết bình luận...',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _sendComment,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.brand))
                      : const Icon(Icons.send, color: AppColors.brand),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onReply,
    required this.onChanged,
    this.depth = 0,
  });

  final Comment comment;
  final void Function(Comment) onReply;
  final Future<void> Function() onChanged;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthState>();
    final isOwner = !comment.isAnonymous &&
        comment.author?.id.isNotEmpty == true &&
        comment.author?.id == auth.user?.id;

    return Padding(
      padding: EdgeInsets.only(left: depth * 24.0, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthorAvatar(
            imageUrl: comment.author?.avatar,
            name: comment.author?.name,
            isAnonymous: comment.isAnonymous,
            size: 32,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.author?.name ??
                            (comment.isAnonymous ? 'Ẩn danh' : 'Người dùng'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: comment.isAnonymous
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      formatRelativeTime(comment.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.content,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary)),
                Row(
                  children: [
                    if (depth == 0)
                      TextButton(
                        onPressed: () => onReply(comment),
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(40, 28)),
                        child: const Text('Trả lời',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted)),
                      ),
                    if (isOwner)
                      TextButton(
                        onPressed: () async {
                          try {
                            await CommentService.instance
                                .deleteComment(comment.id);
                            await onChanged();
                          } catch (_) {}
                        },
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(40, 28)),
                        child: const Text('Xóa',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.danger)),
                      ),
                  ],
                ),
                for (final reply in comment.replies)
                  _CommentTile(
                    comment: reply,
                    onReply: onReply,
                    onChanged: onChanged,
                    depth: depth + 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
