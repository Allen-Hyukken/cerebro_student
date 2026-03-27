import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/providers/auth_provider.dart';
import 'package:quiz_app/screens/login_screen.dart';
import 'package:quiz_app/screens/home_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final success = await ref.read(authProvider.notifier).register(
      _nameController.text,
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
              'Sign up to your\nAccount',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold,
                color: TC.text(context), height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Already have an account? ',
                  style: TextStyle(fontSize: 13, color: TC.subText(context))),
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text(
                  'Log In',
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

            _label('Full Name', context),
            const SizedBox(height: 6),
            _field(_nameController, 'Your full name', context,
                onChanged: (_) => ref.read(authProvider.notifier).clearError()),
            const SizedBox(height: 16),
            _label('Email', context),
            const SizedBox(height: 6),
            _field(_emailController, 'Email address', context,
                type: TextInputType.emailAddress,
                onChanged: (_) => ref.read(authProvider.notifier).clearError()),
            const SizedBox(height: 16),
            _label('Password', context),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: TC.text(context)),
              onChanged: (_) => ref.read(authProvider.notifier).clearError(),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: TextStyle(color: TC.subText(context)),
                filled: true, fillColor: TC.input(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14,
                ),
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
              ),
            ),
            const SizedBox(height: 28),

            // ── Submit ─────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: authState.isLoading ? null : _register,
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
                  'Create Account',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _label(String text, BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13, color: TC.subText(context),
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  Widget _field(
      TextEditingController ctrl,
      String hint,
      BuildContext context, {
        TextInputType? type,
        ValueChanged<String>? onChanged,
      }) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: TextStyle(color: TC.text(context)),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: TC.subText(context)),
          filled: true, fillColor: TC.input(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14,
          ),
        ),
      );
}