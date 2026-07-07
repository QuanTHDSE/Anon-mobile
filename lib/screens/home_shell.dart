import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'bookmarks_screen.dart';
import 'create_post_screen.dart';
import 'feed_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';

/// Bottom-nav shell: Feed / Leaderboard / Create / Bookmarks / Profile.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (created == true && mounted) {
      setState(() => _index = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const FeedScreen(),
      const LeaderboardScreen(),
      const BookmarksScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.orange50,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.brand),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events, color: AppColors.brand),
            label: 'Bảng xếp hạng',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark, color: AppColors.brand),
            label: 'Đã lưu',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.brand),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}
