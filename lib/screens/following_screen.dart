import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/follow_service.dart';
import '../state/auth_state.dart';
import '../widgets/author_avatar.dart';

/// Following / Followers tabs for the current user.
class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 2, vsync: this, initialIndex: widget.initialTab);

  List<FollowUserItem> _following = [];
  List<FollowUserItem> _followers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = context.read<AuthState>().user?.id ?? '';
    if (userId.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        FollowService.instance.getFollowing(userId),
        FollowService.instance.getFollowers(userId),
      ]);
      setState(() {
        _following = results[0];
        _followers = results[1];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unfollow(FollowUserItem user) async {
    try {
      await FollowService.instance.unfollow(user.id);
      setState(() => _following.removeWhere((u) => u.id == user.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết nối'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.brand,
          indicatorColor: AppColors.brand,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          tabs: const [
            Tab(text: 'Đang theo dõi'),
            Tab(text: 'Người theo dõi'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style:
                          const TextStyle(color: AppColors.textSecondary)))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildList(_following, canUnfollow: true),
                    _buildList(_followers, canUnfollow: false),
                  ],
                ),
    );
  }

  Widget _buildList(List<FollowUserItem> users, {required bool canUnfollow}) {
    if (users.isEmpty) {
      return const Center(
        child: Text('Chưa có ai ở đây.',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (context, i) {
          final user = users[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              leading: AuthorAvatar(
                  imageUrl: user.avatarUrl, name: user.username, size: 44),
              title: Text(user.username,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
              trailing: canUnfollow
                  ? TextButton(
                      onPressed: () => _unfollow(user),
                      child: const Text('Bỏ theo dõi',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger)),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
