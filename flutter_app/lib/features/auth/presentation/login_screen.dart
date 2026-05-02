import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/auth_service.dart';
import '../../../ui_kit/layout/responsive_builder.dart';
import '../../../ui_kit/theme/typography.dart';
import '../../../ui_kit/theme/app_colors.dart';
import '../../../ui_kit/components/buttons/app_buttons.dart';
import '../../../ui_kit/components/inputs/app_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) context.go('/');
    } on DioException catch (e) {
      String msg;
      final data = e.response?.data;
      if (data is Map) {
        msg = (data['error'] ?? data['message'] ?? 'Login failed').toString();
      } else if (data is String && data.trim().isNotEmpty) {
        msg = data;
      } else if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.unknown) {
        msg =
            'Cannot reach server. Is the backend running on port 4000?\n\nStart it with: node src/server.js';
      } else {
        final raw = e.message ?? e.error?.toString() ?? '';
        msg =
            raw.isNotEmpty
                ? raw
                : 'Login failed (status ${e.response?.statusCode})';
      }
      debugPrint(
        'LOGIN ERROR | type=${e.type} | msg=$msg | data=$data | err=${e.error}',
      );
      if (mounted) _showError(msg);
    } catch (e) {
      debugPrint('LOGIN CATCH | $e');
      if (mounted) _showError('Unexpected error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
                SizedBox(width: 8),
                Text(
                  'Login Failed',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            content: Text(
              msg,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: MaxWidthContainer(
            maxWidth: 400,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.blur_on_rounded,
                      size: 48,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Welcome back',
                      style: AppTypography.h1,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Sign in to your account to continue',
                      style: AppTypography.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    AppTextField(
                      controller: _emailController,
                      labelText: 'Email',
                      hintText: 'name@example.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _passwordController,
                      labelText: 'Password',
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                      onSubmitted: (_) => _handleLogin(),
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      onPressed: _handleLogin,
                      label: 'Sign In',
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    GhostButton(
                      onPressed: () => context.go('/register'),
                      label: "Don't have an account? Sign up",
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
