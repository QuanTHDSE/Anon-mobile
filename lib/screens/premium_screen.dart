import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';
import '../state/auth_state.dart';
import 'checkout_screen.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  List<SubscriptionPlan> _plans = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plans = await SubscriptionService.instance.getPlans();
      setState(() => _plans = plans.where((p) => p.isActive).toList());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDuration(int days) {
    if (days % 365 == 0) return '${days ~/ 365} năm';
    if (days % 30 == 0) return '${days ~/ 30} tháng';
    return '$days ngày';
  }

  List<String> _featuresOf(SubscriptionPlan plan) {
    final feats = <String>[];
    if (plan.maxPostsPerDay != null) {
      feats.add(plan.maxPostsPerDay! <= 0
          ? 'Đăng bài không giới hạn'
          : 'Tối đa ${plan.maxPostsPerDay} bài/ngày');
    }
    if (plan.maxPostImageCount != null) {
      feats.add(plan.maxPostImageCount! <= 0
          ? 'Không giới hạn ảnh mỗi bài'
          : '${plan.maxPostImageCount} ảnh mỗi bài');
    }
    if (plan.canUploadPostFiles == true) feats.add('Đính kèm tệp vào bài viết');
    if (plan.canUseExclusiveAnonImages == true) {
      feats.add('Ảnh ẩn danh độc quyền');
    }
    if (plan.canUsePremiumFeatures == true) feats.add('Huy hiệu Premium');
    if (feats.isEmpty && plan.description != null) feats.add(plan.description!);
    return feats;
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AuthState>().isPremium;
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.brand))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (isPremium)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified, color: AppColors.success),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bạn đang là thành viên Premium!',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_error != null)
                    Center(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.textSecondary))),
                  if (!_loading && _plans.isEmpty && _error == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Center(
                        child: Text('Hiện chưa có gói nào được mở bán.',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                  for (final plan in _plans)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: const Color(0xFFFFEDD5), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.workspace_premium,
                                  color: AppColors.amber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(plan.name,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                SubscriptionService.formatPrice(plan.price),
                                style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.brand),
                              ),
                              const SizedBox(width: 6),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '/ ${_formatDuration(plan.durationDays)}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (final f in _featuresOf(plan))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      size: 16, color: AppColors.success),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(f,
                                          style: const TextStyle(
                                              fontSize: 13.5))),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        CheckoutScreen(plan: plan)),
                              ),
                              child: Text('Mua ${plan.name}'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
