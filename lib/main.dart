import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/screens/connection_check_screen.dart';
import 'package:quiz_app/screens/home_screen.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/services/sound_service.dart';
import 'package:quiz_app/services/theme_service.dart';
import 'package:quiz_app/providers/theme_provider.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // These must finish before ProviderScope is built so that
  // ThemeNotifier.build() and AuthNotifier.build() read correct initial values.
  await ApiService.baseUrl;
  await ThemeService().init();
  final loggedIn = await ApiService.restoreSession();

  FlutterNativeSplash.remove();

  runApp(
    ProviderScope(
      child: QuizApp(startLoggedIn: loggedIn),
    ),
  );
}

// ── App root ──────────────────────────────────────────────────────────────────

class QuizApp extends ConsumerStatefulWidget {
  final bool startLoggedIn;
  const QuizApp({super.key, this.startLoggedIn = false});

  @override
  ConsumerState<QuizApp> createState() => _QuizAppState();
}

class _QuizAppState extends ConsumerState<QuizApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SoundService().init();
      await SoundService().playBackground();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Riverpod drives theme rebuilds — no manual ChangeNotifier listener needed.
    final themeMode = ref.watch(themeModeProvider);

    return GestureDetector(
      onTapDown: (_) => SoundService().playClick(),
      behavior: HitTestBehavior.translucent,
      child: MaterialApp(
        title: 'Cerebro Metron',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        onGenerateRoute: (settings) => PageRouteBuilder(
          settings: settings,
          pageBuilder: (_, __, ___) => switch (settings.name) {
            '/home' => const HomeScreen(),
            _       => widget.startLoggedIn
                ? const HomeScreen()
                : const ConnectionCheckScreen(),
          },
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      ),
    );
  }
}