import 'package:flutter/material.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/screens/login_screen.dart';
import 'package:quiz_app/screens/home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading       = false;
  String? _error;

  Future<void> _register() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiService.register(
          _nameController.text.trim(), _emailController.text.trim(), _passwordController.text, role: 'STUDENT');
      if (data.containsKey('error')) {
        setState(() => _error = data['error']);
      } else {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      setState(() => _error = 'Connection failed. Check your server.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: ClipOval(child: Image.asset('assets/icons/logo.png', fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.psychology, size: 64, color: AppColors.primary))),
            ),
            const SizedBox(height: 32),
            Text('Sign up to your\nAccount',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: TC.text(context), height: 1.3)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Already have an account? ', style: TextStyle(fontSize: 13, color: TC.subText(context))),
              GestureDetector(
                  onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: const Text('Log In', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 32),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.wrong.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.wrong, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.wrong, fontSize: 13))),
                ]),
              ),
              const SizedBox(height: 16),
            ],
            _label('Full Name', context),
            const SizedBox(height: 6),
            _field(_nameController, 'Your full name', context),
            const SizedBox(height: 16),
            _label('Email', context),
            const SizedBox(height: 6),
            _field(_emailController, 'Email address', context, type: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _label('Password', context),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: TC.text(context)),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: TextStyle(color: TC.subText(context)),
                filled: true, fillColor: TC.input(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: TC.subText(context)),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _label(String text, BuildContext context) => Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: TextStyle(fontSize: 13, color: TC.subText(context), fontWeight: FontWeight.w500)));

  Widget _field(TextEditingController ctrl, String hint, BuildContext context, {TextInputType? type}) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: TextStyle(color: TC.text(context)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: TC.subText(context)),
          filled: true, fillColor: TC.input(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}