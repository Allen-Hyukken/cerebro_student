import 'package:flutter/material.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/screens/login_screen.dart';
import 'package:quiz_app/screens/home_screen.dart';
import 'package:quiz_app/services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.baseUrl;
  // Restore session from SQLite → skip login if already logged in
  final loggedIn = await ApiService.restoreSession();
  runApp(QuizApp(startLoggedIn: loggedIn));
}

class QuizApp extends StatelessWidget {
  final bool startLoggedIn;
  const QuizApp({super.key, this.startLoggedIn = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cerebro Metron',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: startLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}