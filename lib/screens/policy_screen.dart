import 'package:flutter/material.dart';

import '../core/theme.dart';

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Điều khoản dịch vụ')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            Text(
              'Điều khoản dịch vụ AnonWork',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 8),
            Text(
              'Cập nhật lần cuối: 01/01/2026',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            Divider(height: 24),
            _PolicySection(
              title: '1. Quy định chung',
              content:
                  'Chào mừng bạn đến với AnonWork. Khi truy cập và sử dụng dịch vụ của chúng tôi, bạn đồng ý tuân thủ các quy định và điều khoản được nêu tại đây.',
            ),
            _PolicySection(
              title: '2. Quyền riêng tư & Tính năng Ẩn danh',
              content:
                  'AnonWork tôn trọng quyền ẩn danh của bạn khi chia sẻ bài viết và bình luận. Bạn chịu trách nhiệm cá nhân đối với mọi nội dung được xuất bản dưới tư cách tài khoản của mình.',
            ),
            _PolicySection(
              title: '3. Hành vi bị cấm',
              content:
                  'Nghiêm cấm đăng tải nội dung xúc phạm, thù hận, vi phạm pháp luật, lộ thông tin cá nhân của người khác hoặc phát tán phần mềm độc hại. Các tài khoản vi phạm sẽ bị khóa mà không cần báo trước.',
            ),
            _PolicySection(
              title: '4. Gói dịch vụ Premium',
              content:
                  'Các gói Premium được cung cấp với nhiều tính năng nâng cao. Việc thanh toán được xử lý qua cổng thanh toán bảo mật. Phí đăng ký sẽ không được hoàn trả ngoại trừ trường hợp lỗi kỹ thuật từ hệ thống.',
            ),
            _PolicySection(
              title: '5. Sửa đổi điều khoản',
              content:
                  'AnonWork có quyền cập nhật điều khoản bất cứ lúc nào. Việc bạn tiếp tục sử dụng dịch vụ sau khi điều khoản được cập nhật đồng nghĩa với việc bạn chấp nhận các thay đổi đó.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
                fontSize: 14, height: 1.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
