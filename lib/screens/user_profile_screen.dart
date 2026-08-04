import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/follow_service.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../widgets/author_avatar.dart';
import 'post_detail_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserProfile? _profile;
  FollowStats? _stats;
  List<FeedPost> _posts = [];
  bool _loading = true;
  String? _error;
  bool _isFollowing = false;
  bool _busyFollow = false;

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
      final results = await Future.wait([
        UserService.instance.getUserById(widget.userId),
        FollowService.instance.getStats(widget.userId),
        PostService.instance.getPosts(authorId: widget.userId, pageSize: 50),
      ]);

      final profile = results[0] as UserProfile;
      final stats = results[1] as FollowStats;
      final postsResult = results[2] as PaginatedPosts;

      if (mounted) {
        setState(() {
          _profile = profile;
          _stats = stats;
          _isFollowing = stats.isFollowing;
          _posts = postsResult.posts.where((p) => p.authorId == widget.userId).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_busyFollow) return;
    setState(() => _busyFollow = true);
    final nextFollowing = !_isFollowing;

    try {
      if (_isFollowing) {
        await FollowService.instance.unfollow(widget.userId);
      } else {
        await FollowService.instance.follow(widget.userId);
      }
      setState(() => _isFollowing = nextFollowing);
      final newStats = await FollowService.instance.getStats(widget.userId);
      if (mounted) setState(() => _stats = newStats);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busyFollow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile?.username ?? 'Hồ sơ người dùng'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.brand,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header
                      Row(
                        children: [
                          AuthorAvatar(
                            imageUrl: _profile?.avatarUrl,
                            name: _profile?.username,
                            size: 72,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profile?.username ?? 'Người dùng',
                                  style: const TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${_profile?.anonAlias ?? _profile?.username}',
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.textMuted),
                                ),
                                if (_profile?.bio != null && _profile!.bio!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _profile!.bio!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Follow Action Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing
                              ? const Color(0xFFF3F4F6)
                              : AppColors.brand,
                          foregroundColor: _isFollowing
                              ? AppColors.textSecondary
                              : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _busyFollow ? null : _toggleFollow,
                        icon: _busyFollow
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.brand),
                              )
                            : Icon(_isFollowing
                                ? Icons.person_remove_outlined
                                : Icons.person_add_outlined),
                        label: Text(
                          _isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats Row
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem('Bài viết', '${_posts.length}'),
                            Container(width: 1, height: 28, color: AppColors.border),
                            _buildStatItem(
                                'Người theo dõi', '${_stats?.followerCount ?? 0}'),
                            Container(width: 1, height: 28, color: AppColors.border),
                            _buildStatItem(
                                'Đang theo dõi', '${_stats?.followingCount ?? 0}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Posts Section
                      const Text(
                        'Bài viết đã đăng',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),

                      if (_posts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Người dùng chưa có bài viết công khai nào.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        )
                      else
                        for (final post in _posts)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ListTile(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => PostDetailScreen(postId: post.id)),
                              ),
                              title: Text(
                                post.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                '${post.likesCount} ♥ · ${post.commentsCount} 💬',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right,
                                  color: AppColors.textMuted),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}
