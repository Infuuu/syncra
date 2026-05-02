import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/auth_service.dart';
import '../../../ui_kit/layout/responsive_builder.dart';
import '../../../ui_kit/theme/typography.dart';
import '../../../ui_kit/theme/app_colors.dart';
import '../../../ui_kit/components/buttons/app_buttons.dart';
import '../../../ui_kit/components/inputs/app_text_field.dart';
import '../../../ui_kit/components/layout/ambient_background.dart';
import '../../../ui_kit/components/surfaces/glass_panel.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );
      if (mounted) context.go('/');
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['error'] as String? ?? 'Registration failed.';
      setState(() => _errorMessage = msg);
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: MaxWidthContainer(
              maxWidth: 420,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 32),
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
                        Text('Create an account', style: Theme.of(context).textTheme.displayMedium),
                        const SizedBox(height: 6),
                        Text('Get started with Syncra', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 36),
                        AppTextField(
                          controller: _nameController, labelText: 'Display Name', hintText: 'John Doe',
                          validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 16),
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
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Password is required';
                            if (v.length < 6) return 'At least 6 characters';
                            return null;
                          },
                          onSubmitted: (_) => _handleRegister(),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: c.errorSoft, borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: c.error.withValues(alpha: 0.3)),
                            ),
                            child: Text(_errorMessage!, style: AppTypography.bodySmall.copyWith(color: c.error),
                                textAlign: TextAlign.center),
                          ),
                        ],
                        const SizedBox(height: 28),
                        PrimaryButton(onPressed: _handleRegister, label: 'Create Account', isLoading: _isLoading),
                        const SizedBox(height: 16),
                        GhostButton(onPressed: () => context.go('/login'), label: 'Already have an account? Sign in'),
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
