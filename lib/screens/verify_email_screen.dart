import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _error;
  String? _successMsg;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 6) {
      setState(() => _error = 'Vui lòng nhập mã xác minh 6 chữ số.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _successMsg = null;
    });

    try {
      await AuthService.instance.verifyEmail(widget.email, otp);
      if (mounted) {
        setState(() {
          _successMsg = 'Xác minh Email thành công! Bạn có thể đăng nhập ngay.';
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _resending = true;
      _error = null;
      _successMsg = null;
    });

    try {
      // Re-register call triggers sending verification email again
      await AuthService.instance.register(
        username: '',
        email: widget.email,
        password: '',
        anonAlias: '',
      );
      if (mounted) {
        setState(() {
          _successMsg = 'Mã xác minh đã được gửi lại tới ${widget.email}.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _successMsg = 'Đã yêu cầu gửi lại mã xác minh tới ${widget.email}.';
        });
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xác minh Email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.orange50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_outlined,
                    size: 36, color: AppColors.brand),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nhập mã xác minh',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Chúng tôi đã gửi mã xác minh 6 chữ số tới:',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 24),

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
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_successMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    _successMsg!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.success, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w900),
                decoration: const InputDecoration(
                  hintText: '000000',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Xác minh Email'),
              ),
              const SizedBox(height: 16),

              TextButton.icon(
                onPressed: _resending ? null : _resendCode,
                icon: _resending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.brand),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('Gửi lại mã xác minh'),
              ),

              if (_successMsg != null) ...[
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Quay lại Đăng nhập'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
