import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../state/auth_state.dart';
import 'premium_screen.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _tagInput = TextEditingController();
  final _picker = ImagePicker();

  List<Subject> _subjects = [];
  String? _subjectId;
  final List<String> _tags = [];
  bool _isAnonymous = false;
  final List<XFile> _images = [];

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    PostService.instance.getSubjects().then((subs) {
      if (mounted) setState(() => _subjects = subs);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  /// Free-tier limit (server-enforced): at most 1 image per post.
  int get _maxImages =>
      context.read<AuthState>().isPremium ? 100 : 1;

  Future<void> _pickImages() async {
    final isPremium = context.read<AuthState>().isPremium;
    final files = await _picker.pickMultiImage();
    if (files.isEmpty) return;
    final room = _maxImages - _images.length;
    final accepted = files.take(room > 0 ? room : 0).toList();
    setState(() {
      _images.addAll(accepted);
      if (accepted.length < files.length && !isPremium) {
        _error =
            'Người dùng miễn phí chỉ được đăng 1 ảnh mỗi bài. Nâng cấp Premium để thêm nhiều ảnh.';
      }
    });
  }

  void _addTag() {
    final t = _tagInput.text.trim().replaceFirst(RegExp(r'^#'), '');
    if (t.isNotEmpty && !_tags.contains(t) && _tags.length < 5) {
      setState(() => _tags.add(t));
    }
    _tagInput.clear();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.length < 5 || content.length < 10 || _subjectId == null) {
      setState(() => _error =
          'Tiêu đề tối thiểu 5 ký tự, nội dung tối thiểu 10 ký tự và phải chọn chuyên ngành.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final isPremium = context.read<AuthState>().isPremium;
      // Mirror server-side free-tier limits: at most 1 image.
      final selected = isPremium ? _images : _images.take(1).toList();
      final files = <http.MultipartFile>[];
      for (final img in selected) {
        files.add(await http.MultipartFile.fromPath('Images', img.path,
            filename: img.name));
      }
      await PostService.instance.createPost(
        title: title,
        content: content,
        subjectId: _subjectId!,
        tags: _tags,
        isAnonymous: _isAnonymous,
        images: files,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng bài thành công!')));
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AuthState>().isPremium;
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo bài viết mới')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Free-tier notice
            if (!isPremium)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amber50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.workspace_premium,
                        size: 20, color: AppColors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tài khoản miễn phí',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB45309))),
                          const SizedBox(height: 2),
                          const Text(
                            'Đăng 1 bài/ngày · tối đa 1 ảnh · không đính kèm tệp.',
                            style: TextStyle(
                                fontSize: 12.5, color: Color(0xFFB45309)),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const PremiumScreen()),
                            ),
                            child: const Text(
                              'Nâng cấp Premium →',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.amber,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

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

            // Images
            if (_images.isNotEmpty)
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(File(_images[i].path),
                            width: 96, height: 96, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            if (_images.length < _maxImages)
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFE5E7EB), width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image_outlined,
                          size: 28, color: AppColors.textMuted),
                      const SizedBox(height: 6),
                      Text(
                        isPremium
                            ? 'Thêm hình ảnh (nhiều ảnh)'
                            : 'Thêm hình ảnh (tối đa 1 ảnh - Free)',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else if (!isPremium)
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PremiumScreen())),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.amber50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium,
                          size: 16, color: AppColors.amber),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Đã đạt giới hạn 1 ảnh. Nâng cấp Premium để thêm nhiều ảnh.',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                  hintText: 'Tiêu đề bài viết (tối thiểu 5 ký tự)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                  hintText: 'Nội dung (tối thiểu 10 ký tự)...'),
            ),

            const SizedBox(height: 16),
            const Text('Chuyên ngành *',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _subjects
                  .map((s) => ChoiceChip(
                        label: Text(
                            '${s.iconEmoji.isNotEmpty ? "${s.iconEmoji} " : ""}${s.name}'),
                        selected: _subjectId == s.id,
                        selectedColor: AppColors.brand,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _subjectId == s.id
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                        onSelected: (_) =>
                            setState(() => _subjectId = s.id),
                      ))
                  .toList(),
            ),

            const SizedBox(height: 16),
            const Text('Tags (tuỳ chọn)',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (_tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _tags
                    .map((t) => Chip(
                          label: Text('#$t'),
                          labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand),
                          backgroundColor: AppColors.orange50,
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () =>
                              setState(() => _tags.remove(t)),
                        ))
                    .toList(),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagInput,
                    onSubmitted: (_) => _addTag(),
                    decoration:
                        const InputDecoration(hintText: 'Thêm tag...'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add, color: AppColors.brand),
                ),
              ],
            ),

            const SizedBox(height: 16),
            SwitchListTile(
              value: _isAnonymous,
              onChanged: (v) => setState(() => _isAnonymous = v),
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.brand,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              tileColor: const Color(0xFFF9FAFB),
              title: const Text('Đăng ẩn danh',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text(
                  'Người khác sẽ không thấy tên bạn trên bài viết này.',
                  style: TextStyle(fontSize: 12)),
            ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, size: 18),
              label: Text(_loading ? 'Đang đăng...' : 'Đăng bài'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
