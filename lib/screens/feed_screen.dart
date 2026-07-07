import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/post.dart';
import '../services/bookmark_service.dart';
import '../services/post_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';

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
  Set<String> _bookmarkedIds = {};
  String _search = '';
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
        _page < _totalPages) {
      _loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search = value.trim();
      _load(reset: true);
    });
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _posts.clear();
      }
    });
    try {
      final results = await Future.wait([
        PostService.instance
            .getPosts(search: _search, page: 1, pageSize: 10),
        BookmarkService.instance.getBookmarkedPostIds(),
      ]);
      final res = results[0] as PaginatedPosts;
      final ids = results[1] as Set<String>;
      setState(() {
        _posts
          ..clear()
          ..addAll(res.posts);
        _totalPages = res.totalPages;
        _page = 1;
        _bookmarkedIds = ids;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final res = await PostService.instance
          .getPosts(search: _search, page: _page + 1, pageSize: 10);
      setState(() {
        _page += 1;
        _posts.addAll(res.posts);
        _totalPages = res.totalPages;
      });
    } catch (_) {
      // silent — user can scroll again to retry
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openDetail(FeedPost post) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: post.id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppLogoWithText(logoSize: 28, fontSize: 19),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm bài viết...',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
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
    if (_loading && _posts.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.brand));
    }
    if (_error != null && _posts.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.wifi_off, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Center(
            child: Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      );
    }
    if (_posts.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.article_outlined, size: 40, color: AppColors.textMuted),
          SizedBox(height: 12),
          Center(
            child: Text('Chưa có bài viết nào.',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _posts.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _posts.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.brand)),
          );
        }
        final post = _posts[i];
        return PostCard(
          key: ValueKey(post.id),
          post: post,
          isBookmarked: _bookmarkedIds.contains(post.id),
          onTap: () => _openDetail(post),
        );
      },
    );
  }
}
