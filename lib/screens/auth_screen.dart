// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';

import '../services/app_localization.dart';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (_isSignUp) {
        final response = await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          emailRedirectTo: kIsWeb
              ? Uri.base.origin
              : 'fitplan://login-callback/',
        );
        if (!mounted) return;
        if (response.session == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: LocalizedText('Kiểm tra email để xác nhận tài khoản.'),
            ),
          );
        }
      } else {
        await auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: LocalizedText(_friendlyMessage(error.message))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login')) {
      return 'Email hoặc mật khẩu chưa đúng.';
    }
    if (lower.contains('already registered'))
      return 'Email này đã được đăng ký.';
    if (lower.contains('password')) return 'Mật khẩu cần có ít nhất 6 ký tự.';
    return message;
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        size: 34,
                        color: AppColors.textInverse,
                      ),
                    ),
                    SizedBox(height: 28),
                    LocalizedText(
                      _isSignUp ? 'Tạo tài khoản FitPlan' : 'Chào mừng trở lại',
                      style: AppTextTheme.displayMedium,
                    ),
                    SizedBox(height: 8),
                    LocalizedText(
                      _isSignUp
                          ? 'Lưu lịch tập và tiến độ an toàn trên mọi thiết bị.'
                          : 'Đăng nhập để tiếp tục kế hoạch tập luyện của bạn.',
                      style: AppTextTheme.bodySmall,
                    ),
                    SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: tr('Email'),
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (!email.contains('@') || !email.contains('.')) {
                          return 'Nhập một địa chỉ email hợp lệ';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: tr('Mật khẩu'),
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) < 6
                          ? 'Mật khẩu cần có ít nhất 6 ký tự'
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    SizedBox(height: 22),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: Size.fromHeight(56),
                      ),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : LocalizedText(
                              _isSignUp ? 'Tạo tài khoản' : 'Đăng nhập',
                            ),
                    ),
                    SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() => _isSignUp = !_isSignUp),
                      child: LocalizedText(
                        _isSignUp
                            ? 'Đã có tài khoản? Đăng nhập'
                            : 'Chưa có tài khoản? Đăng ký',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
