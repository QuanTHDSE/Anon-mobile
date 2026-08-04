import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';
import '../state/auth_state.dart';
import 'premium_screen.dart';

class UserSubscriptionScreen extends StatefulWidget {
  const UserSubscriptionScreen({super.key});

  @override
  State<UserSubscriptionScreen> createState() => _UserSubscriptionScreenState();
}

class _UserSubscriptionScreenState extends State<UserSubscriptionScreen> {
  List<UserSubscription> _subscriptions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthState>();
    final userId = auth.user?.id ?? '';
    if (userId.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final subs = await SubscriptionService.instance.getUserSubscriptions(userId, pageSize: 50);
      if (mounted) {
        setState(() => _subscriptions = subs);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('dd/MM/yyyy', 'vi').format(dt.toLocal());
  }

  int _calculateDaysRemaining(DateTime? expiresAt) {
    if (expiresAt == null) return 0;
    final diff = expiresAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final activeSub = _subscriptions.firstWhere(
      (s) => s.status == 0 && s.expiresAt != null && s.expiresAt!.isAfter(now),
      orElse: () => UserSubscription(id: '', status: -1),
    );
    final hasActive = activeSub.id.isNotEmpty;
    final history = _subscriptions.where((s) => s.id != activeSub.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gói cước của tôi'),
      ),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.brand)),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              )
            else ...[
              // Active Subscription Section
              const Text(
                'Gói hiện tại',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),

              if (hasActive)
                _buildActiveCard(activeSub)
              else
                _buildEmptyCard(),

              const SizedBox(height: 24),

              // Benefits
              if (hasActive) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quyền lợi của bạn',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      _buildBenefitItem(Icons.style, 'Đăng bài ẩn danh không giới hạn'),
                      _buildBenefitItem(Icons.file_present, 'Đính kèm tệp văn bản vào bài viết'),
                      _buildBenefitItem(Icons.verified, 'Avatar ẩn danh 👑 độc quyền'),
                      _buildBenefitItem(Icons.star, 'Bài viết ưu tiên hiển thị'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // History Section
              if (history.isNotEmpty) ...[
                Row(
                  children: const [
                    Icon(Icons.history, size: 18, color: AppColors.textMuted),
                    SizedBox(width: 6),
                    Text(
                      'Lịch sử đăng ký',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final sub in history)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.orange50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.workspace_premium,
                              color: AppColors.brand, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sub.planName ?? 'Premium',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_formatDate(sub.startedAt)} → ${_formatDate(sub.expiresAt)}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(sub),
                      ],
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCard(UserSubscription sub) {
    final daysLeft = _calculateDaysRemaining(sub.expiresAt);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF15B29), Color(0xFFD94A1D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.workspace_premium,
                      color: Colors.amber, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'GÓI ĐANG HOẠT ĐỘNG',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Còn $daysLeft ngày',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sub.planName ?? 'Gói Premium',
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Hết hạn ngày ${_formatDate(sub.expiresAt)}',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bắt đầu: ${_formatDate(sub.startedAt)}',
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.brand,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Gia hạn',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppColors.orange50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium,
                size: 32, color: AppColors.brand),
          ),
          const SizedBox(height: 12),
          const Text(
            'Chưa có gói Premium',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nâng cấp để mở khóa tính năng đăng bài ẩn danh không giới hạn và nhiều đặc quyền hấp dẫn.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PremiumScreen()),
            ),
            child: const Text('Xem các gói cước'),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(UserSubscription sub) {
    final now = DateTime.now();
    final isActive = sub.status == 0 &&
        sub.expiresAt != null &&
        sub.expiresAt!.isAfter(now);
    final isExpired = sub.expiresAt != null && sub.expiresAt!.isBefore(now);

    String text = 'Đã hủy';
    Color color = AppColors.danger;
    Color bg = const Color(0xFFFEF2F2);

    if (isActive) {
      text = 'Hoạt động';
      color = AppColors.success;
      bg = const Color(0xFFECFDF5);
    } else if (isExpired) {
      text = 'Hết hạn';
      color = AppColors.textMuted;
      bg = const Color(0xFFF3F4F6);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
