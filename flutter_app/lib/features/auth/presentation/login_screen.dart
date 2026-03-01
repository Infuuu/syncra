import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // TODO: Wire to Riverpod AuthController Provider
    await Future.delayed(const Duration(seconds: 1)); 

    setState(() => _isLoading = false);
    
    // On success
    if (mounted) {
      context.go('/');
    }
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
            maxWidth: 400, // Narrowest form wrapper for auth
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo or Header
                    const Icon(
                      Icons.blur_on_rounded, 
                      size: 48, 
                      color: AppColors.textPrimary
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
                        if (value == null || value.isEmpty) return 'Email is required';
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
                        if (value == null || value.isEmpty) return 'Password is required';
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
