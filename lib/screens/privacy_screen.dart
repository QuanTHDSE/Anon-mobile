import 'package:flutter/material.dart';

import '../core/theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chính sách bảo mật')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            Text(
              'Chính sách bảo mật thông tin',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 8),
            Text(
              'Cập nhật lần cuối: 01/01/2026',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            Divider(height: 24),
            _PrivacySection(
              title: '1. Thu thập thông tin',
              content:
                  'Chúng tôi chỉ thu thập các thông tin tối thiểu cần thiết để vận hành dịch vụ như Email, Tên tài khoản và Tên ẩn danh (Alias).',
            ),
            _PrivacySection(
              title: '2. Bảo mật bài đăng ẩn danh',
              content:
                  'Khi bạn chọn chế độ Đăng bài ẩn danh, danh tính thật (Tên & Avatar thật) của bạn sẽ được mã hóa và hoàn toàn ẩn giấu đối với những người dùng khác.',
            ),
            _PrivacySection(
              title: '3. Lưu trữ & Bảo vệ dữ liệu',
              content:
                  'Dữ liệu của bạn được bảo lưu trên hạ tầng máy chủ an toàn với giao thức mã hóa SSL/TLS. Chúng tôi cam kết không bán hoặc chia sẻ thông tin cá nhân của bạn cho bên thứ ba vì mục đích quảng cáo.',
            ),
            _PrivacySection(
              title: '4. Quyền của người dùng',
              content:
                  'Bạn có quyền chỉnh sửa thông tin cá nhân, thay đổi tên ẩn danh, hoặc yêu cầu xóa tài khoản và toàn bộ dữ liệu liên quan bất kỳ lúc nào.',
            ),
            _PrivacySection(
              title: '5. Liên hệ hỗ trợ',
              content:
                  'Nếu có bất kỳ thắc mắc nào về chính sách bảo mật, vui lòng liên hệ đội ngũ quản trị qua email support@anonwork.com.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.title, required this.content});

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
