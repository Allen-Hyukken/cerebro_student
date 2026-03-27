import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/providers/auth_provider.dart';
import 'package:quiz_app/screens/signup_screen.dart';
import 'package:quiz_app/screens/home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final success = await ref.read(authProvider.notifier).login(
      _emailController.text,
      _passwordController.text,
    );
    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const SizedBox(height: 40),
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2.5),
                color: TC.surface(context),
                boxShadow: [BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 12, offset: const Offset(0, 4),
                )],
              ),
              child: ClipOval(child: Image.asset(
                'assets/icons/logo.png', fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.psychology, size: 64, color: AppColors.primary),
              )),
            ),
            const SizedBox(height: 32),
            Text(
              'Log in to your\nAccount',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold,
                color: TC.text(context), height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text("Don't have an account? ",
                  style: TextStyle(fontSize: 13, color: TC.subText(context))),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                ),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(
                    fontSize: 13, color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 32),

            // ── Error banner ───────────────────────────────────────────────
            if (authState.error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.wrong.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.wrong, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    authState.error!,
                    style: const TextStyle(color: AppColors.wrong, fontSize: 13),
                  )),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── Email ──────────────────────────────────────────────────────
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: TC.text(context)),
              onChanged: (_) => ref.read(authProvider.notifier).clearError(),
              decoration: InputDecoration(
                hintText: 'Email',
                hintStyle: TextStyle(color: TC.subText(context)),
                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                filled: true, fillColor: TC.input(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Password ───────────────────────────────────────────────────
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: TC.text(context)),
              onChanged: (_) => ref.read(authProvider.notifier).clearError(),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: TextStyle(color: TC.subText(context)),
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: TC.subText(context),
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true, fillColor: TC.input(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Submit ─────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: authState.isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: authState.isLoading
                    ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Log In',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}