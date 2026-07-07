import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../widgets/author_avatar.dart';
import 'post_detail_screen.dart';

/// Top posts (GET /api/v1/posts/top) — port of the web LeaderboardPage.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<FeedPost> _posts = [];
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
      final posts = await PostService.instance
          .getTopPosts(range: '30d', sort: 'hot', pageSize: 30);
      setState(() => _posts = posts);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _rankColor(int rank) => switch (rank) {
        1 => const Color(0xFFF59E0B),
        2 => const Color(0xFF9CA3AF),
        3 => const Color(0xFFB45309),
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bảng xếp hạng')),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.brand))
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: 120),
                    Center(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.textSecondary))),
                  ])
                : _posts.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 120),
                        Icon(Icons.emoji_events_outlined,
                            size: 40, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Center(
                            child: Text('Chưa có dữ liệu xếp hạng.',
                                style: TextStyle(
                                    color: AppColors.textSecondary))),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _posts.length,
                        itemBuilder: (context, i) {
                          final post = _posts[i];
                          final rank = i + 1;
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
                                    builder: (_) => PostDetailScreen(
                                        postId: post.id)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 36,
                                      child: rank <= 3
                                          ? Icon(Icons.emoji_events,
                                              color: _rankColor(rank))
                                          : Text(
                                              '#$rank',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: _rankColor(rank),
                                              ),
                                            ),
                                    ),
                                    if (post.images.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            right: 10),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.network(
                                            post.images.first,
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                    width: 56,
                                                    height: 56,
                                                    color: const Color(
                                                        0xFFF3F4F6)),
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(post.title,
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w800)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              AuthorAvatar(
                                                imageUrl:
                                                    post.author.avatar,
                                                name: post.author.name,
                                                isAnonymous:
                                                    post.isAnonymous,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 5),
                                              Flexible(
                                                child: Text(
                                                  post.author.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow
                                                      .ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .textSecondary),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        const Icon(Icons.favorite,
                                            size: 15,
                                            color: Color(0xFFF43F5E)),
                                        Text('${post.likesCount}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13)),
                                      ],
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
