import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui_kit/layout/responsive_builder.dart';
import '../../../ui_kit/theme/typography.dart';
import '../../../ui_kit/theme/app_colors.dart';
import '../../../ui_kit/components/buttons/app_buttons.dart';
import '../../../ui_kit/components/inputs/app_text_field.dart';

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

  void _handleRegister() async {
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
    _nameController.dispose();
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
                    Text(
                      'Create an account',
                      style: AppTypography.h1,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Enter your details to get started',
                      style: AppTypography.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    AppTextField(
                      controller: _nameController,
                      labelText: 'Display Name',
                      hintText: 'John Doe',
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

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
                        if (value.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                      onSubmitted: (_) => _handleRegister(),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    PrimaryButton(
                      onPressed: _handleRegister,
                      label: 'Create Account',
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    GhostButton(
                      onPressed: () => context.go('/login'),
                      label: "Already have an account? Sign in",
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
