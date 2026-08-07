import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/bookmark_service.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../widgets/author_avatar.dart';
import '../widgets/post_card.dart' show formatRelativeTime;
import '../widgets/premium_user_name.dart';
import 'post_detail_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<BookmarkPost> _items = [];
  Map<String, String?> _resolvedAuthorAvatars = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await BookmarkService.instance.getBookmarks();
      final profileAvatarRequests = <String, Future<String?>>{};

      Future<String?> avatarForUser(String userId) {
        return profileAvatarRequests.putIfAbsent(userId, () async {
          final profile = await UserService.instance.fetchUserCached(userId);
          return profile?.avatarUrl;
        });
      }

      final avatarEntries = await Future.wait(
        items.map((item) => _resolveAuthorAvatar(item, avatarForUser)),
      );

      if (!mounted) return;
      setState(() {
        _items = items;
        _resolvedAuthorAvatars = Map.fromEntries(avatarEntries);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<MapEntry<String, String?>> _resolveAuthorAvatar(
    BookmarkPost item,
    Future<String?> Function(String userId) avatarForUser,
  ) async {
    if (item.isAnonymous || item.authorAvatar != null) {
      return MapEntry(item.postId, item.authorAvatar);
    }

    try {
      var authorId = item.authorId;
      String? avatarUrl;

      // Some bookmark responses omit the embedded author entirely. Resolve
      // the public post first so we can still identify its real author.
      if (authorId.isEmpty && item.postId.isNotEmpty) {
        final post = await PostService.instance.getPostById(item.postId);
        authorId = post.author.id;
        avatarUrl = post.author.avatar;
      }

      if (avatarUrl == null && authorId.isNotEmpty) {
        avatarUrl = await avatarForUser(authorId);
      }

      return MapEntry(item.postId, avatarUrl);
    } catch (_) {
      return MapEntry(item.postId, item.authorAvatar);
    }
  }

  Future<void> _remove(BookmarkPost item) async {
    try {
      await BookmarkService.instance.removeBookmark(item.postId);
      setState(() => _items.removeWhere((b) => b.postId == item.postId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đã lưu')),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.brand),
              )
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          _error!,
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Icon(
                            Icons.bookmark_border,
                            size: 40,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(height: 12),
                          Center(
                            child: Text(
                              'Chưa có bài viết nào được lưu.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final item = _items[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PostDetailScreen(postId: item.postId),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.images.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 12),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: Image.network(
                                            item.images.first,
                                            width: 72,
                                            height: 72,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              width: 72,
                                              height: 72,
                                              color: const Color(0xFFF3F4F6),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title ?? '(Không có tiêu đề)',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              AuthorAvatar(
                                                imageUrl: item.authorAvatar ??
                                                    _resolvedAuthorAvatars[
                                                        item.postId],
                                                name: item.authorName,
                                                isAnonymous: item.isAnonymous,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: PremiumUserName(
                                                  userId: item.authorId,
                                                  name: item.authorName,
                                                  isAnonymous: item.isAnonymous,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                formatRelativeTime(
                                                    item.createdAt),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.bookmark,
                                        size: 20,
                                        color: AppColors.brand,
                                      ),
                                      onPressed: () => _remove(item),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
