import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/user.dart';
import '../services/follow_service.dart';
import '../services/user_service.dart';
import '../state/auth_state.dart';
import '../widgets/author_avatar.dart';
import '../widgets/premium_user_name.dart';
import 'sign_in_screen.dart';

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  List<TopContributor> _contributors = [];
  List<FollowUserItem> _following = [];
  List<FollowUserItem> _followers = [];
  Set<String> _followingIds = {};

  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  String? _actionUserId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthState>();
    final userId = auth.user?.id ?? '';

    try {
      final contributorsFuture = UserService.instance.getTopContributors(
        limit: 50,
      );
      final followingFuture = userId.isNotEmpty
          ? FollowService.instance.getFollowing(userId)
          : Future.value(<FollowUserItem>[]);
      final followersFuture = userId.isNotEmpty
          ? FollowService.instance.getFollowers(userId)
          : Future.value(<FollowUserItem>[]);

      final results = await Future.wait([
        contributorsFuture,
        followingFuture,
        followersFuture,
      ]);

      final contribs = results[0] as List<TopContributor>;
      final followingList = results[1] as List<FollowUserItem>;
      final followersList = results[2] as List<FollowUserItem>;

      if (mounted) {
        setState(() {
          _contributors = contribs;
          _following = followingList;
          _followers = followersList;
          _followingIds = followingList.map((u) => u.id).toSet();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow(String targetUserId) async {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SignInScreen()));
      return;
    }

    setState(() => _actionUserId = targetUserId);
    final isCurrentlyFollowing = _followingIds.contains(targetUserId);

    try {
      if (isCurrentlyFollowing) {
        await FollowService.instance.unfollow(targetUserId);
        if (mounted) {
          setState(() {
            _followingIds.remove(targetUserId);
            _following.removeWhere((u) => u.id == targetUserId);
          });
        }
      } else {
        await FollowService.instance.follow(targetUserId);
        if (mounted) {
          setState(() {
            _followingIds.add(targetUserId);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _actionUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final isLoggedIn = auth.isLoggedIn;

    final filteredContributors = _contributors.where((c) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.displayName.toLowerCase().contains(q) ||
          c.username.toLowerCase().contains(q);
    }).toList();

    final filteredFollowing = _following.where((u) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return u.username.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();

    final filteredFollowers = _followers.where((u) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return u.username.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Cộng đồng & Kết nối'), elevation: 0),
      body: Column(
        children: [
          // Subtitle Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            color: Colors.white,
            child: Text(
              isLoggedIn
                  ? 'Khám phá các thành viên tích cực và danh sách theo dõi của bạn'
                  : 'Khám phá danh sách thành viên tích cực đóng góp hàng đầu',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.brand,
              ),
            ),
          ),

          // Custom TabBar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.brand,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.brand,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('Top Contributors (${_contributors.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_add_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('Đang theo dõi (${_following.length})'),
                      if (!isLoggedIn) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.group_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('Người theo dõi (${_followers.length})'),
                      if (!isLoggedIn) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFFAFAFA),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên contributor...',
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                fillColor: Colors.white,
                filled: true,
              ),
            ),
          ),

          // Main Content
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _buildTopContributorsTab(filteredContributors),
                          _buildFollowingTab(filteredFollowing, isLoggedIn),
                          _buildFollowersTab(filteredFollowers, isLoggedIn),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // 🏆 Tab 1: Top Contributors
  Widget _buildTopContributorsTab(List<TopContributor> list) {
    if (list.isEmpty) {
      return RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.orange50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_outlined,
                      size: 48,
                      color: AppColors.amber,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Không tìm thấy đóng góp nào'
                        : 'Chưa có danh sách đóng góp',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final item = list[index];
          final currentUserId = context.watch<AuthState>().user?.id;
          final isOwn = currentUserId == item.userId;
          final isFollowing = _followingIds.contains(item.userId);
          final isProcessing = _actionUserId == item.userId;

          String rankBadgeText = '#${item.rank}';
          Color rankBg = const Color(0xFFF3F4F6);
          Color rankTextColor = AppColors.textSecondary;

          if (item.rank == 1) {
            rankBadgeText = '🥇 Top 1';
            rankBg = const Color(0xFFFEF3C7);
            rankTextColor = const Color(0xFFB45309);
          } else if (item.rank == 2) {
            rankBadgeText = '🥈 Top 2';
            rankBg = const Color(0xFFF1F5F9);
            rankTextColor = const Color(0xFF475569);
          } else if (item.rank == 3) {
            rankBadgeText = '🥉 Top 3';
            rankBg = const Color(0xFFFFEDD5);
            rankTextColor = const Color(0xFFC2410C);
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AuthorAvatar(
                      imageUrl: item.avatarUrl,
                      name: item.displayName,
                      size: 52,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: PremiumUserName(
                                  userId: item.userId,
                                  name: item.displayName,
                                  isAnonymous: item.isAnonymous,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: rankBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  rankBadgeText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: rankTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.orange50,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${item.contributionScore} điểm',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ),
                              if (item.averageRating > 0) ...[
                                const SizedBox(width: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      size: 14,
                                      color: AppColors.amber,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      item.averageRating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.amber,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '${item.postsCount} bài viết · ${item.upvotesReceived} upvotes',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    if (!isOwn)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? const Color(0xFFF3F4F6)
                              : AppColors.brand,
                          foregroundColor: isFollowing
                              ? AppColors.textSecondary
                              : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isProcessing
                            ? null
                            : () => _toggleFollow(item.userId),
                        icon: isProcessing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.brand,
                                ),
                              )
                            : Icon(
                                isFollowing
                                    ? Icons.person_remove_outlined
                                    : Icons.person_add_outlined,
                                size: 16,
                              ),
                        label: Text(
                          isFollowing ? 'Hủy' : 'Theo dõi',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 👥 Tab 2: Following List
  Widget _buildFollowingTab(List<FollowUserItem> list, bool isLoggedIn) {
    if (!isLoggedIn) {
      return _buildLoginRequiredCard();
    }
    if (list.isEmpty) {
      return _buildEmptyTab(
        icon: Icons.people_outline,
        message: _searchQuery.isNotEmpty
            ? 'Không tìm thấy người dùng'
            : 'Bạn chưa theo dõi ai',
        subMessage: 'Khám phá và theo dõi những thành viên khác!',
      );
    }
    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final user = list[i];
          final isProcessing = _actionUserId == user.id;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              leading: AuthorAvatar(
                imageUrl: user.avatarUrl,
                name: user.username,
                size: 44,
              ),
              title: PremiumUserName(
                userId: user.id,
                name: user.username,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: TextButton.icon(
                onPressed: isProcessing ? null : () => _toggleFollow(user.id),
                icon: isProcessing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.danger,
                        ),
                      )
                    : const Icon(
                        Icons.person_remove_outlined,
                        size: 16,
                        color: AppColors.danger,
                      ),
                label: const Text(
                  'Hủy theo dõi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 👥 Tab 3: Followers List
  Widget _buildFollowersTab(List<FollowUserItem> list, bool isLoggedIn) {
    if (!isLoggedIn) {
      return _buildLoginRequiredCard();
    }
    if (list.isEmpty) {
      return _buildEmptyTab(
        icon: Icons.group_outlined,
        message: _searchQuery.isNotEmpty
            ? 'Không tìm thấy người theo dõi'
            : 'Chưa có ai theo dõi bạn',
      );
    }
    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final user = list[i];
          final isFollowing = _followingIds.contains(user.id);
          final isProcessing = _actionUserId == user.id;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              leading: AuthorAvatar(
                imageUrl: user.avatarUrl,
                name: user.username,
                size: 44,
              ),
              title: PremiumUserName(
                userId: user.id,
                name: user.username,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: TextButton.icon(
                onPressed: isProcessing ? null : () => _toggleFollow(user.id),
                icon: isProcessing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brand,
                        ),
                      )
                    : Icon(
                        isFollowing
                            ? Icons.person_remove_outlined
                            : Icons.person_add_outlined,
                        size: 16,
                        color: isFollowing ? AppColors.danger : AppColors.brand,
                      ),
                label: Text(
                  isFollowing ? 'Hủy' : 'Theo dõi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isFollowing ? AppColors.danger : AppColors.brand,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoginRequiredCard() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.orange50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 36,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Đăng nhập để xem danh sách',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đăng nhập hoặc đăng ký tài khoản để theo dõi các tác giả yêu thích và xem ai đang theo dõi bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SignInScreen())),
              child: const Text('Đăng nhập ngay'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTab({
    required IconData icon,
    required String message,
    String? subMessage,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          if (subMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              subMessage,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
