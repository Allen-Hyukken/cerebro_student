import 'package:flutter/material.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/screens/login_screen.dart';
import 'package:quiz_app/screens/home_screen.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.baseUrl;
  await ThemeService().init(); // load saved theme preference
  final loggedIn = await ApiService.restoreSession();
  runApp(QuizApp(startLoggedIn: loggedIn));
}

class QuizApp extends StatefulWidget {
  final bool startLoggedIn;
  const QuizApp({super.key, this.startLoggedIn = false});

  @override
  State<QuizApp> createState() => _QuizAppState();
}

class _QuizAppState extends State<QuizApp> {
  final _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cerebro Metron',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeService.themeMode,
      home: widget.startLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}