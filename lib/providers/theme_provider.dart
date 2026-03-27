import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/services/theme_service.dart';

// ── Notifier ──────────────────────────────────────────────────────────────────

class ThemeNotifier extends Notifier<bool> {
  @override
  bool build() => ThemeService().isDark; // ThemeService already init'd in main()

  Future<void> toggle() async {
    await ThemeService().toggle();
    state = ThemeService().isDark;
  }

  Future<void> setDark(bool value) async {
    await ThemeService().setDark(value);
    state = value;
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final themeProvider = NotifierProvider<ThemeNotifier, bool>(ThemeNotifier.new);

/// Derived [ThemeMode] — watch this in [MaterialApp].
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeProvider) ? ThemeMode.dark : ThemeMode.light;
});