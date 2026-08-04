import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/post.dart';
import '../services/bookmark_service.dart';
import '../services/post_service.dart';
import '../state/auth_state.dart';
import 'author_avatar.dart';

String formatRelativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${(diff.inDays / 7).floor()}w';
}

/// Feed post card — port of the web HomePage's PostCard.
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.isBookmarked,
    this.onTap,
  });

  final FeedPost post;
  final bool isBookmarked;
  final VoidCallback? onTap;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _bookmarked = widget.isBookmarked;
  late bool _upvoted = widget.post.hasUpvoted ?? false;
  late int _likes = widget.post.likesCount;
  bool _busyVote = false;
  bool _busyBookmark = false;

  late double _avgRating = widget.post.averageRating;
  late int _ratingsCount = widget.post.ratingsCount;
  late int? _userRating = widget.post.userRating;
  bool _busyRating = false;

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isBookmarked != widget.isBookmarked) {
      _bookmarked = widget.isBookmarked;
    }
    _avgRating = widget.post.averageRating;
    _ratingsCount = widget.post.ratingsCount;
    _userRating = widget.post.userRating;
  }

  Future<void> _toggleUpvote() async {
    if (_busyVote) return;
    setState(() {
      _busyVote = true;
      _upvoted = !_upvoted;
      _likes += _upvoted ? 1 : -1;
    });
    try {
      await PostService.instance.upvotePost(widget.post.id);
    } catch (_) {
      setState(() {
        _upvoted = !_upvoted;
        _likes += _upvoted ? 1 : -1;
      });
    } finally {
      if (mounted) setState(() => _busyVote = false);
    }
  }

  Future<void> _toggleBookmark() async {
    if (_busyBookmark) return;
    final next = !_bookmarked;
    setState(() {
      _busyBookmark = true;
      _bookmarked = next;
    });
    try {
      if (next) {
        await BookmarkService.instance.addBookmark(widget.post.id);
      } else {
        await BookmarkService.instance.removeBookmark(widget.post.id);
      }
    } catch (_) {
      setState(() => _bookmarked = !next);
    } finally {
      if (mounted) setState(() => _busyBookmark = false);
    }
  }

  Future<void> _openRatingDialog() async {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Vui lòng đăng nhập để đánh giá bài viết')),
      );
      return;
    }

    int selectedStars = _userRating ?? 5;

    final result = await showDialog<int?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Đánh giá bài viết',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Chọn số sao bạn muốn dành cho bài viết này:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      return IconButton(
                        iconSize: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        icon: Icon(
                          star <= selectedStars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedStars = star;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$selectedStars / 5 sao',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
              actions: [
                if (_userRating != null)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(-1),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger),
                    child: const Text('Xóa đánh giá'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(selectedStars),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Gửi'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() => _busyRating = true);
    try {
      if (result == -1) {
        final res =
            await PostService.instance.deletePostRating(widget.post.id);
        setState(() {
          _userRating = null;
          if (res['averageRating'] is num) {
            _avgRating = (res['averageRating'] as num).toDouble();
            widget.post.averageRating = _avgRating;
          }
          if (res['ratingsCount'] is num) {
            _ratingsCount = (res['ratingsCount'] as num).toInt();
            widget.post.ratingsCount = _ratingsCount;
          }
          widget.post.userRating = null;
        });
      } else {
        final res = await PostService.instance
            .ratePost(widget.post.id, result);
        setState(() {
          _userRating = result;
          if (res['averageRating'] is num) {
            _avgRating = (res['averageRating'] as num).toDouble();
            widget.post.averageRating = _avgRating;
          }
          if (res['ratingsCount'] is num) {
            _ratingsCount = (res['ratingsCount'] as num).toInt();
            widget.post.ratingsCount = _ratingsCount;
          }
          widget.post.userRating = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi đánh giá: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyRating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
              child: Row(
                children: [
                  AuthorAvatar(
                    imageUrl: post.author.avatar,
                    name: post.author.name,
                    isAnonymous: post.isAnonymous,
                    size: 40,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          formatRelativeTime(post.createdAt),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (post.subject != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.orange50,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFFFEDD5)),
                      ),
                      child: Text(
                        post.subject!.name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: _toggleBookmark,
                    icon: Icon(
                      _bookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      size: 20,
                      color: _bookmarked
                          ? AppColors.brand
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            // Image
            if (post.images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      post.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF3F4F6),
                        child: const Icon(Icons.broken_image_outlined,
                            color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ),
              ),

            // Title + content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, color: AppColors.textSecondary),
                  ),
                  if (post.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: post.tags
                          .take(4)
                          .map((t) => Text('#$t',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brand,
                              )))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _toggleUpvote,
                    icon: Icon(
                      _upvoted ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color:
                          _upvoted ? AppColors.danger : AppColors.textMuted,
                    ),
                    label: Text(
                      '$_likes',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color:
                            _upvoted ? AppColors.danger : AppColors.textMuted,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onTap,
                    icon: const Icon(Icons.mode_comment_outlined,
                        size: 17, color: AppColors.textMuted),
                    label: Text(
                      '${post.commentsCount}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _busyRating ? null : _openRatingDialog,
                    icon: Icon(
                      _userRating != null
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 18,
                      color: Colors.amber,
                    ),
                    label: Text(
                      _ratingsCount > 0
                          ? '${_avgRating.toStringAsFixed(1)} ($_ratingsCount)'
                          : (_userRating != null
                              ? '$_userRating ★'
                              : 'Đánh giá'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _userRating != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
