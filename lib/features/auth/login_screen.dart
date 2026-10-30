import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:site_pulse/core/theme/app_theme.dart';

import 'auth_controller.dart';
import 'auth_failure.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authController = ref.read(authControllerProvider);
      await authController.signIn(
        _emailController.text,
        _passwordController.text,
      );
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.userMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Something went wrong. Try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // ── Background: Deep Zinc-950 slate canvas
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF09090B), // Zinc-950
                  Color(0xFF140F22), // Deep violet-black
                  Color(0xFF09090B), // Zinc-950
                ],
              ),
            ),
          ),

          // ── Ambient Glow Orb: Violet highlight (top-right of form)
          Positioned(
            top: 100,
            right: -40,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.35),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ── Ambient Glow Orb: Electric Indigo highlight (bottom-left of form)
          Positioned(
            bottom: 80,
            left: -50,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.28),
                    const Color(0xFF6366F1).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ── Center Ambient Orb directly behind card to power glass refraction
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryLight.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Foreground Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Brand Header
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColors.primaryLight.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.monitor_heart_outlined,
                          size: 40,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Site Pulse',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Field Operations & Offline Sync',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Glassmorphic Form Card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.12),
                                  Colors.white.withValues(alpha: 0.04),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 30,
                                  offset: const Offset(0, 16),
                                ),
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.18),
                                  blurRadius: 24,
                                  spreadRadius: -4,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Welcome back',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Enter your credentials to continue',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.65),
                                    ),
                                  ),
                                  const SizedBox(height: 22),

                                  // Inline Error Message
                                  if (_errorMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.critical.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppColors.critical.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: AppColors.critical,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  // Email Field with Frosted Styling
                                  TextFormField(
                                    key: const Key('email_field'),
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    autocorrect: false,
                                    enabled: !_isLoading,
                                    style: const TextStyle(color: Colors.white, fontSize: 15),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.07),
                                      labelText: 'Email',
                                      labelStyle: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.75),
                                      ),
                                      hintText: 'user@sitepulse.test',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.35),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.email_outlined,
                                        color: Colors.white.withValues(alpha: 0.75),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.16),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                          color: AppColors.primaryLight,
                                          width: 1.8,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                          color: AppColors.critical,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                          color: AppColors.critical,
                                          width: 1.8,
                                        ),
                                      ),
                                    ),
                                    validator: _validateEmail,
                                  ),
                                  const SizedBox(height: 16),

                                  // Password Field with Frosted Styling
                                  TextFormField(
                                    key: const Key('password_field'),
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    enabled: !_isLoading,
                                    style: const TextStyle(color: Colors.white, fontSize: 15),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.07),
                                      labelText: 'Password',
                                      labelStyle: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.75),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.lock_outline,
                                        color: Colors.white.withValues(alpha: 0.75),
                                      ),
                                      suffixIcon: IconButton(
                                        key: const Key('password_visibility_button'),
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: Colors.white.withValues(alpha: 0.75),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                        tooltip: _obscurePassword
                                            ? 'Show password'
                                            : 'Hide password',
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.16),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                          color: AppColors.primaryLight,
                                          width: 1.8,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                          color: AppColors.critical,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                          color: AppColors.critical,
                                          width: 1.8,
                                        ),
                                      ),
                                    ),
                                    validator: _validatePassword,
                                  ),
                                  const SizedBox(height: 24),

                                  // Sign In Button
                                  SizedBox(
                                    height: 52,
                                    child: FilledButton(
                                      key: const Key('sign_in_button'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        elevation: 4,
                                        shadowColor: AppColors.primary.withValues(alpha: 0.5),
                                      ),
                                      onPressed: _isLoading ? null : _handleSignIn,
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'Sign in',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Text(
                        'Site Pulse © 2025',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
