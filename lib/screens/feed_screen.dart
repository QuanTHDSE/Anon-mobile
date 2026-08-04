import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/post.dart';
import '../models/search.dart';
import '../services/bookmark_service.dart';
import '../services/post_service.dart';
import '../services/search_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/author_avatar.dart';
import '../widgets/post_card.dart';
import 'following_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  final List<FeedPost> _posts = [];
  final List<SearchUserItem> _searchUsers = [];
  Set<String> _bookmarkedIds = {};

  String _search = '';
  String _searchTab = 'all'; // 'all' | 'posts' | 'users'
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >
            _scroll.position.maxScrollExtent - 400 &&
        !_loadingMore &&
        !_loading &&
        _search.isEmpty &&
        _page < _totalPages) {
      _loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final trimmed = value.trim();
      if (_search != trimmed) {
        setState(() {
          _search = trimmed;
          _searchTab = 'all';
        });
        _load(reset: true);
      }
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _search = '';
      _searchTab = 'all';
      _searchUsers.clear();
    });
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _posts.clear();
        _searchUsers.clear();
      }
    });

    try {
      if (_search.isNotEmpty) {
        // Search mode — fetch both posts and matching users via SearchService
        final results = await Future.wait([
          SearchService.instance.searchAll(_search, limit: 20),
          BookmarkService.instance.getBookmarkedPostIds(),
        ]);
        final searchRes = results[0] as SearchAllResult;
        final ids = results[1] as Set<String>;

        if (mounted) {
          setState(() {
            _posts
              ..clear()
              ..addAll(searchRes.posts);
            _searchUsers
              ..clear()
              ..addAll(searchRes.users);
            _bookmarkedIds = ids;
            _page = 1;
            _totalPages = 1;
          });
        }
      } else {
        // Normal feed mode
        final results = await Future.wait([
          PostService.instance.getPosts(search: '', page: 1, pageSize: 10),
          BookmarkService.instance.getBookmarkedPostIds(),
        ]);
        final res = results[0] as PaginatedPosts;
        final ids = results[1] as Set<String>;

        if (mounted) {
          setState(() {
            _posts
              ..clear()
              ..addAll(res.posts);
            _totalPages = res.totalPages;
            _page = 1;
            _bookmarkedIds = ids;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_search.isNotEmpty || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await PostService.instance
          .getPosts(search: '', page: _page + 1, pageSize: 10);
      if (mounted) {
        setState(() {
          _page += 1;
          _posts.addAll(res.posts);
          _totalPages = res.totalPages;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openDetail(FeedPost post) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: post.id)));
  }

  void _openUserProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppLogoWithText(logoSize: 28, fontSize: 19),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Cộng đồng & Kết nối',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FollowingScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              onSubmitted: (v) {
                final trimmed = v.trim();
                if (_search != trimmed) {
                  setState(() {
                    _search = trimmed;
                    _searchTab = 'all';
                  });
                  _load(reset: true);
                }
              },
              decoration: InputDecoration(
                hintText: 'Tìm kiếm bài viết, tác giả...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: _clearSearch,
                      )
                    : null,
              ),
            ),
          ),

          // Main Feed / Search Content
          Expanded(
            child: RefreshIndicator(
              color: AppColors.brand,
              onRefresh: () => _load(reset: true),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _posts.isEmpty && _searchUsers.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }

    if (_error != null && _posts.isEmpty && _searchUsers.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.wifi_off, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Search Results Header & Filter Bar (Matching Web FE UI)
        if (_search.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Kết quả cho "$_search"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _clearSearch,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Xóa tìm kiếm ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Icon(Icons.close, size: 12, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tìm thấy ${_posts.length} bài viết và ${_searchUsers.length} tác giả',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filter Chips: All (Tất cả), Posts (Bài viết), Users (Tác giả)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'Tất cả (${_posts.length + _searchUsers.length})'),
                const SizedBox(width: 6),
                _buildFilterChip('posts', 'Bài viết (${_posts.length})'),
                const SizedBox(width: 6),
                _buildFilterChip('users', 'Tác giả (${_searchUsers.length})'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 1: Matching Users / Authors
          if ((_searchTab == 'all' || _searchTab == 'users') && _searchUsers.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.people_outline, size: 16, color: AppColors.brand),
                const SizedBox(width: 6),
                Text(
                  'TÁC GIẢ / NGƯỜI DÙNG (${_searchUsers.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final u in _searchUsers)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  onTap: () => _openUserProfile(u.id),
                  leading: AuthorAvatar(
                    imageUrl: u.avatarUrl,
                    name: u.username,
                    size: 44,
                  ),
                  title: Text(
                    u.username,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '@${u.anonAlias.isNotEmpty ? u.anonAlias : u.username} · ${u.followerCount} người theo dõi',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ],

        // Section 2: Posts List
        if (_search.isNotEmpty &&
            (_searchTab == 'all' || _searchTab == 'posts') &&
            _posts.isNotEmpty) ...[
          if (_searchUsers.isNotEmpty && _searchTab == 'all') ...[
            Row(
              children: const [
                Icon(Icons.article_outlined, size: 16, color: AppColors.brand),
                SizedBox(width: 6),
                Text(
                  'BÀI VIẾT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],

        if (_search.isNotEmpty &&
            ((_searchTab == 'posts' && _posts.isEmpty) ||
                (_searchTab == 'users' && _searchUsers.isEmpty) ||
                (_searchTab == 'all' && _posts.isEmpty && _searchUsers.isEmpty)))
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'Không tìm thấy kết quả phù hợp.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          )
        else if (_search.isEmpty && _posts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(
              child: Text(
                'Chưa có bài viết nào.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          )
        else if (_search.isEmpty || _searchTab == 'all' || _searchTab == 'posts')
          for (final post in _posts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PostCard(
                key: ValueKey(post.id),
                post: post,
                isBookmarked: _bookmarkedIds.contains(post.id),
                onTap: () => _openDetail(post),
              ),
            ),

        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final active = _searchTab == key;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _searchTab = key),
      selectedColor: AppColors.brand,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: active ? Colors.white : AppColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: active ? AppColors.brand : AppColors.border,
        ),
      ),
    );
  }
}
