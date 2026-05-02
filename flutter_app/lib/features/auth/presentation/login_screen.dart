import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


import '../../../core/api/auth_service.dart';
import '../../../ui_kit/layout/responsive_builder.dart';
import '../../../ui_kit/theme/typography.dart';
import '../../../ui_kit/components/buttons/app_buttons.dart';
import '../../../ui_kit/components/inputs/app_text_field.dart';
import '../../../ui_kit/components/layout/ambient_background.dart';
import '../../../ui_kit/components/surfaces/glass_panel.dart';

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
      await authService.login(email: _emailController.text.trim(), password: _passwordController.text);
      if (mounted) context.go('/');
    } on DioException catch (e) {
      String msg;
      final data = e.response?.data;
      if (data is Map) {
        msg = (data['error'] ?? data['message'] ?? 'Login failed').toString();
      } else if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        msg = 'Cannot reach server. Is the backend running?';
      } else {
        msg = e.message ?? 'Login failed';
      }
      if (mounted) _showError(msg);
    } catch (e) {
      if (mounted) _showError('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
        const SizedBox(width: 8),
        Text('Login Failed', style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontSize: 18)),
      ]),
      content: Text(msg, style: Theme.of(ctx).textTheme.bodyMedium),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
    ));
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
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: MaxWidthContainer(
              maxWidth: 420,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: GlassPanel(
                  padding: const EdgeInsets.all(36),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFF6366F1)]),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 24),
                        Text('Welcome back', style: Theme.of(context).textTheme.displayMedium),
                        const SizedBox(height: 6),
                        Text('Sign in to continue to Syncra', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 36),
                        AppTextField(
                          controller: _emailController, labelText: 'Email', hintText: 'name@example.com',
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Email is required';
                            if (!v.contains('@')) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _passwordController, labelText: 'Password', obscureText: true,
                          validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
                          onSubmitted: (_) => _handleLogin(),
                        ),
                        const SizedBox(height: 28),
                        PrimaryButton(onPressed: _handleLogin, label: 'Sign In', isLoading: _isLoading),
                        const SizedBox(height: 16),
                        GhostButton(onPressed: () => context.go('/register'), label: "Don't have an account? Sign up"),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
