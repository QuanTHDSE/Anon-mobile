import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../models/anon_image.dart';
import '../models/post.dart';
import '../services/anon_image_service.dart';
import '../services/follow_service.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../state/auth_state.dart';
import '../widgets/author_avatar.dart';
import 'following_screen.dart';
import 'post_detail_screen.dart';
import 'premium_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<FeedPost> _posts = [];
  FollowStats? _stats;
  bool _loadingPosts = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthState>();
    await auth.refreshProfile();
    final id = auth.user?.id ?? auth.profile?.id ?? '';
    if (id.isEmpty) return;
    setState(() => _loadingPosts = true);
    try {
      final results = await Future.wait([
        PostService.instance.getPosts(authorId: id, pageSize: 50),
        FollowService.instance.getStats(id),
      ]);
      final posts = results[0] as PaginatedPosts;
      if (mounted) {
        setState(() {
          _posts =
              posts.posts.where((p) => p.authorId == id).toList();
          _stats = results[1] as FollowStats;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _deletePost(FeedPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bài viết'),
        content: const Text(
            'Bạn có chắc muốn xóa bài viết này? Hành động không thể hoàn tác.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PostService.instance.deletePost(post.id);
      setState(() => _posts.removeWhere((p) => p.id == post.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final profile = auth.profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: profile == null
                ? null
                : () async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                          builder: (_) => const EditProfileScreen()),
                    );
                    if (changed == true) _load();
                  },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthState>().logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Row(
              children: [
                AuthorAvatar(
                  imageUrl: profile?.avatarUrl,
                  name: profile?.username ?? auth.user?.name,
                  size: 72,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile?.username ?? auth.user?.name ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (auth.isPremium) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified,
                                size: 20, color: Color(0xFF3B82F6)),
                          ],
                        ],
                      ),
                      Text(profile?.email ?? auth.user?.email ?? '',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textMuted)),
                      if (profile?.anonAlias.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.visibility_off_outlined,
                                  size: 13, color: AppColors.brand),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  profile!.anonAlias,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brand),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (profile?.bio?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(profile!.bio!,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 16),

            // Stats row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  _Stat(label: 'Bài viết', value: '${_posts.length}'),
                  _StatDivider(),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const FollowingScreen(
                                initialTab: 1)),
                      ),
                      child: _StatContent(
                          label: 'Người theo dõi',
                          value: '${_stats?.followerCount ?? 0}'),
                    ),
                  ),
                  _StatDivider(),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const FollowingScreen(
                                initialTab: 0)),
                      ),
                      child: _StatContent(
                          label: 'Đang theo dõi',
                          value: '${_stats?.followingCount ?? 0}'),
                    ),
                  ),
                ],
              ),
            ),

            // Premium CTA
            if (!auth.isPremium) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PremiumScreen())),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFF15B29)]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.workspace_premium, color: Colors.white),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nâng cấp Premium — mở khoá toàn bộ tính năng',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
            const Text('Bài viết của tôi',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (_loadingPosts)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.brand)),
              )
            else if (_posts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Bạn chưa có bài viết nào.',
                      style: TextStyle(color: AppColors.textMuted)),
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
                          builder: (_) =>
                              PostDetailScreen(postId: post.id)),
                    ),
                    leading: post.images.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(post.images.first,
                                width: 52, height: 52, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox(width: 52, height: 52)),
                          )
                        : Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.orange50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.article_outlined,
                                color: AppColors.brand),
                          ),
                    title: Text(post.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Row(
                      children: [
                        if (post.isAnonymous)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.visibility_off_outlined,
                                size: 13, color: AppColors.textMuted),
                          ),
                        Text('${post.likesCount} ♥ · ${post.commentsCount} 💬',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: AppColors.textMuted),
                      onPressed: () => _deletePost(post),
                    ),
                  ),
                ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) =>
      Expanded(child: _StatContent(label: label, value: value));
}

class _StatContent extends StatelessWidget {
  const _StatContent({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: AppColors.border);
}

// ─── Edit profile ────────────────────────────────────────────────────────────

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _username = TextEditingController();
  final _bio = TextEditingController();
  final _anonAlias = TextEditingController();
  final _picker = ImagePicker();

  XFile? _avatarFile;
  bool _isAnonDefault = false;

  List<AnonImage> _anonImages = [];
  bool _loadingAnonImages = true;
  String? _selectedAnonImageId;
  String? _initialAnonImageId;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthState>().profile;
    _username.text = profile?.username ?? '';
    _bio.text = profile?.bio ?? '';
    _anonAlias.text = profile?.anonAlias ?? '';
    _isAnonDefault = profile?.isAnonDefault ?? false;
    _loadAnonImages();
  }

  @override
  void dispose() {
    _username.dispose();
    _bio.dispose();
    _anonAlias.dispose();
    super.dispose();
  }

  Future<void> _loadAnonImages() async {
    // Read profile before awaiting so we don't touch context across the gap.
    final profile = context.read<AuthState>().profile;
    try {
      final imgs = await AnonImageService.instance.getAnonImages();
      // Match the currently assigned image (getMe returns `anonImageUrl` as a
      // full URL or a raw key), same logic as the web ProfilePage.
      final key = profile?.anonImageUrl;
      String? selected = profile?.anonImageId;
      if (selected == null && key != null && key.isNotEmpty) {
        final target = toAbsoluteMediaUrl(key);
        for (final img in imgs) {
          if (img.fileKey == key ||
              img.imageUrl == key ||
              (target != null && img.imageUrl == target)) {
            selected = img.id;
            break;
          }
        }
      }
      if (mounted) {
        setState(() {
          _anonImages = imgs;
          _selectedAnonImageId = selected;
          _initialAnonImageId = selected;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingAnonImages = false);
    }
  }

  Future<void> _pickAvatar() async {
    final img = await _picker.pickImage(source: ImageSource.gallery);
    if (img != null) setState(() => _avatarFile = img);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final errors = <String>[];
    final auth = context.read<AuthState>();
    try {
      http.MultipartFile? avatar;
      if (_avatarFile != null) {
        avatar = await http.MultipartFile.fromPath(
            'Avatar', _avatarFile!.path,
            filename: _avatarFile!.name);
      }
      await UserService.instance.updateMe(
        username: _username.text.trim(),
        bio: _bio.text.trim(),
        anonAlias: _anonAlias.text.trim(),
        avatarFile: avatar,
      );
      // /users/me/anon is a toggle — call only when the value changed.
      if (_isAnonDefault != (auth.profile?.isAnonDefault ?? false)) {
        await UserService.instance.toggleAnonDefault();
      }
    } catch (e) {
      errors.add(e.toString());
    }
    // Assign anon image separately so a failure doesn't lose other edits.
    if (_selectedAnonImageId != null &&
        _selectedAnonImageId != _initialAnonImageId) {
      try {
        await AnonImageService.instance
            .setMyAnonImage(_selectedAnonImageId!);
      } catch (e) {
        errors.add('Ảnh ẩn danh: $e');
      }
    }
    await auth.refreshProfile();
    if (!mounted) return;
    setState(() => _saving = false);
    if (errors.isEmpty) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = errors.join('\n'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final isPremium = auth.isPremium;
    final profile = auth.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa hồ sơ')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(_error!,
                    style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600)),
              ),

            // Avatar
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    _avatarFile != null
                        ? ClipOval(
                            child: Image.file(File(_avatarFile!.path),
                                width: 88, height: 88, fit: BoxFit.cover))
                        : AuthorAvatar(
                            imageUrl: profile?.avatarUrl,
                            name: profile?.username,
                            size: 88),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: AppColors.brand, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Tên hiển thị',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            TextField(controller: _username),
            const SizedBox(height: 14),
            const Text('Giới thiệu',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            TextField(controller: _bio, minLines: 2, maxLines: 4),
            const SizedBox(height: 14),
            const Text('Tên ẩn danh',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            TextField(
              controller: _anonAlias,
              decoration: const InputDecoration(
                  hintText: 'Tên hiển thị khi đăng ẩn danh'),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              value: _isAnonDefault,
              onChanged: (v) => setState(() => _isAnonDefault = v),
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.brand,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              tileColor: const Color(0xFFF9FAFB),
              title: const Text('Ẩn danh mặc định',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Mọi bài đăng sẽ mặc định ẩn danh.',
                  style: TextStyle(fontSize: 12)),
            ),

            const SizedBox(height: 20),
            const Text('Ảnh đại diện ẩn danh',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (profile?.anonImageUrl != null &&
                profile!.anonImageUrl!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.orange50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: Row(
                  children: [
                    ClipOval(
                      child: Image.network(
                        toAbsoluteMediaUrl(profile.anonImageUrl)!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox(width: 44, height: 44),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đang dùng',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brand)),
                          Text(
                            'Ảnh hiển thị khi bạn đăng bài/bình luận ẩn danh',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (_loadingAnonImages)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.brand)),
              )
            else if (_anonImages.isEmpty)
              const Text('Chưa có ảnh ẩn danh nào trong thư viện.',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textMuted))
            else
              GridView.count(
                crossAxisCount: 5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: _anonImages.map((img) {
                  final selected = img.id == _selectedAnonImageId;
                  // Exclusive images are premium-only; lock for free users.
                  final locked = img.isExclusive && !isPremium;
                  return GestureDetector(
                    onTap: locked
                        ? null
                        : () => setState(() => _selectedAnonImageId =
                            selected ? null : img.id),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Opacity(
                            opacity: locked ? 0.4 : 1,
                            child: Image.network(img.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFFF3F4F6))),
                          ),
                        ),
                        if (selected && !locked)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColors.brand, width: 2.5),
                              color: AppColors.brand.withValues(alpha: 0.15),
                            ),
                            child: const Icon(Icons.check_circle,
                                color: AppColors.brand, size: 22),
                          ),
                        if (img.isExclusive)
                          const Positioned(
                            top: 4,
                            left: 4,
                            child: CircleAvatar(
                              radius: 8,
                              backgroundColor: AppColors.amber,
                              child: Icon(Icons.workspace_premium,
                                  size: 10, color: Colors.white),
                            ),
                          ),
                        if (locked)
                          const Center(
                              child: Icon(Icons.lock,
                                  size: 18, color: Color(0xFF374151))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            if (!isPremium)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Ảnh 👑 chỉ dành cho Premium.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Lưu thay đổi'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
