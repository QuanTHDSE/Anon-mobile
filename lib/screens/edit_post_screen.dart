import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../state/auth_state.dart';

class EditPostScreen extends StatefulWidget {
  const EditPostScreen({super.key, required this.post});

  final FeedPost post;

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  late List<String> _tags;
  late List<PostMedia> _existingMedia;
  final List<String> _removeFileIds = [];
  final List<XFile> _newImages = [];
  final _picker = ImagePicker();

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.post.title;
    _contentCtrl.text = widget.post.content;
    _tags = List<String>.from(widget.post.tags);
    _existingMedia = List<PostMedia>.from(widget.post.media);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  void _addTag() {
    final t = _tagCtrl.text.trim().replaceAll(RegExp(r'^#'), '');
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() => _tags.add(t));
      _tagCtrl.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  void _markRemoveMedia(PostMedia media) {
    setState(() {
      _removeFileIds.add(media.id);
      _existingMedia.removeWhere((m) => m.id == media.id);
    });
  }

  Future<void> _pickNewImage() async {
    final auth = context.read<AuthState>();
    final maxImages = auth.isPremium ? 10 : 1;
    final currentImages =
        _existingMedia.where((m) => m.isImage).length + _newImages.length;
    if (currentImages >= maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.isPremium
              ? 'Tối đa $maxImages ảnh.'
              : 'Tài khoản miễn phí chỉ được tải 1 ảnh. Nâng cấp Premium để thêm nhiều ảnh hơn.'),
        ),
      );
      return;
    }
    final img = await _picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() => _newImages.add(img));
    }
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty || content.isEmpty) {
      setState(() => _error = 'Vui lòng nhập đầy đủ tiêu đề và nội dung.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final multipartFiles = <http.MultipartFile>[];
      for (final img in _newImages) {
        multipartFiles.add(
          await http.MultipartFile.fromPath('NewImages', img.path,
              filename: img.name),
        );
      }

      await PostService.instance.updatePost(
        widget.post.id,
        title: title,
        content: content,
        tags: _tags,
        newImages: multipartFiles,
        removeFileIds: _removeFileIds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật bài viết thành công!')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingImages = _existingMedia.where((m) => m.isImage).toList();
    final existingFiles = _existingMedia.where((m) => !m.isImage).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa bài viết'),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.brand),
                  )
                : const Icon(Icons.check, color: AppColors.brand),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                      color: AppColors.danger, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Title
            const Text('Tiêu đề *',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: 'Nhập tiêu đề bài viết...',
              ),
            ),
            const SizedBox(height: 16),

            // Content
            const Text('Nội dung *',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            TextField(
              controller: _contentCtrl,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Viết nội dung bài viết...',
              ),
            ),
            const SizedBox(height: 16),

            // Tags
            const Text('Tags', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final tag in _tags)
                  Chip(
                    label: Text('#$tag',
                        style: const TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w700)),
                    backgroundColor: AppColors.orange50,
                    deleteIcon:
                        const Icon(Icons.close, size: 16, color: AppColors.brand),
                    onDeleted: () => _removeTag(tag),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Thêm tag (ví dụ: cong-viec)',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.brand),
                  onPressed: _addTag,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Existing & New Images
            const Text('Hình ảnh bài viết',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                // Existing Images
                for (final media in existingImages)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          media.url,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 80,
                            height: 80,
                            color: const Color(0xFFF3F4F6),
                            child: const Icon(Icons.image,
                                color: AppColors.textMuted),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _markRemoveMedia(media),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                // New Local Images
                for (var i = 0; i < _newImages.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_newImages[i].path),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removeNewImage(i),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                // Add Image Button
                GestureDetector(
                  onTap: _pickNewImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.orange50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: const Icon(Icons.add_a_photo,
                        color: AppColors.brand, size: 28),
                  ),
                ),
              ],
            ),

            if (existingFiles.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Tệp đính kèm hiện tại',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final f in existingFiles)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined,
                          size: 18, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f.fileName ?? 'Tệp đính kèm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.danger),
                        onPressed: () => _markRemoveMedia(f),
                      ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }
}
