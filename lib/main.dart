import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/screens/connection_check_screen.dart';
import 'package:quiz_app/screens/home_screen.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/services/sound_service.dart';
import 'package:quiz_app/services/theme_service.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await ApiService.baseUrl;
  await ThemeService().init();
  final loggedIn = await ApiService.restoreSession();

  FlutterNativeSplash.remove();

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SoundService().init();
      await SoundService().playBackground();
    });
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => SoundService().playClick(),
      behavior: HitTestBehavior.translucent,
      child: MaterialApp(
        title: 'Cerebro Metron',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: _themeService.themeMode,
        // Fade transition between screens
        onGenerateRoute: (settings) => PageRouteBuilder(
          settings: settings,
          pageBuilder: (_, __, ___) => switch (settings.name) {
            '/home' => const HomeScreen(),
            _ => widget.startLoggedIn
                ? const HomeScreen()
                : const ConnectionCheckScreen(),
          },
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      ),
    );
  }
}