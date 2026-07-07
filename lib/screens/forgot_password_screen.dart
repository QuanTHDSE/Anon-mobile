import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';

/// Two-step flow like the web: request reset email, then enter token +
/// new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _newPassword = TextEditingController();
  bool _sent = false;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Vui lòng nhập email.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.forgotPassword(email);
      setState(() {
        _sent = true;
        _info =
            'Đã gửi mã đặt lại mật khẩu tới $email. Kiểm tra hộp thư của bạn.';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    final token = _token.text.trim();
    final password = _newPassword.text;
    if (token.isEmpty || password.isEmpty) {
      setState(() => _error = 'Vui lòng nhập mã và mật khẩu mới.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.resetPassword(email, token, password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đặt lại mật khẩu thành công! Hãy đăng nhập lại.')));
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
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
                const SizedBox(height: 16),
              ],
              if (_info != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Text(_info!,
                      style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _email,
                enabled: !_sent,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Email đã đăng ký',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              if (_sent) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _token,
                  decoration: const InputDecoration(
                    hintText: 'Mã xác nhận (trong email)',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Mật khẩu mới',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed:
                    _loading ? null : (_sent ? _resetPassword : _sendEmail),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_sent ? 'Đặt lại mật khẩu' : 'Gửi mã xác nhận'),
              ),
              if (_sent)
                TextButton(
                  onPressed: _loading ? null : _sendEmail,
                  child: const Text(
                    'Gửi lại mã',
                    style: TextStyle(
                        color: AppColors.brand, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
