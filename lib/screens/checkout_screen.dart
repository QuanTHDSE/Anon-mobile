import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';
import '../state/auth_state.dart';

/// SePay bank-transfer checkout: create order → show QR + bank info →
/// poll payment status.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.plan});

  final SubscriptionPlan plan;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  OrderInfo? _order;
  ParsedBankInfo? _bank;
  bool _loading = true;
  bool _paid = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _createOrder();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _createOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order =
          await SubscriptionService.instance.createOrder(widget.plan.id);
      final qr = order.qrUrl;
      setState(() {
        _order = order;
        _bank = qr != null ? parseSepayQrUrl(qr) : null;
      });
      _startPolling();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _checkPaid());
  }

  Future<void> _checkPaid() async {
    final id = _order?.orderId ?? '';
    if (id.isEmpty || _paid) return;
    try {
      final latest = await SubscriptionService.instance.getOrder(id);
      if (latest.isPaid && mounted) {
        _pollTimer?.cancel();
        setState(() => _paid = true);
        await context.read<AuthState>().refreshProfile();
      }
    } catch (_) {}
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Đã sao chép $label')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: _createOrder,
                            child: const Text('Thử lại')),
                      ],
                    ),
                  ),
                )
              : _paid
                  ? _buildSuccess()
                  : _buildPayment(),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle,
                size: 72, color: AppColors.success),
            const SizedBox(height: 16),
            const Text('Thanh toán thành công!',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              'Gói ${widget.plan.name} đã được kích hoạt cho tài khoản của bạn.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Hoàn tất'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayment() {
    final amount = _order?.amountOr(widget.plan.price) ?? widget.plan.price;
    final qrUrl = _order?.qrUrl;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text('Gói ${widget.plan.name}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                SubscriptionService.formatPrice(amount),
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.brand),
              ),
              const SizedBox(height: 12),
              if (qrUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    qrUrl,
                    width: 240,
                    height: 240,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Không tải được mã QR',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Không có mã QR — chuyển khoản thủ công bên dưới',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              const SizedBox(height: 8),
              const Text(
                'Quét mã QR bằng app ngân hàng để thanh toán',
                style:
                    TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (_bank != null) ...[
          const SizedBox(height: 14),
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
                const Text('Thông tin chuyển khoản',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                _InfoRow(
                    label: 'Ngân hàng',
                    value: _bank!.bankName,
                    onCopy: () => _copy(_bank!.bankName, 'tên ngân hàng')),
                _InfoRow(
                    label: 'Số tài khoản',
                    value: _bank!.accountNumber,
                    onCopy: () =>
                        _copy(_bank!.accountNumber, 'số tài khoản')),
                _InfoRow(
                    label: 'Nội dung',
                    value: _bank!.transferContent,
                    onCopy: () =>
                        _copy(_bank!.transferContent, 'nội dung')),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.brand),
            ),
            const SizedBox(width: 8),
            const Text('Đang chờ thanh toán...',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _checkPaid,
          child: const Text('Kiểm tra thanh toán ngay',
              style: TextStyle(
                  color: AppColors.brand, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.label, required this.value, required this.onCopy});

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 15, color: AppColors.brand),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
