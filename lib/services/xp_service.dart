import 'package:shared_preferences/shared_preferences.dart';

class XpService {
  static final XpService _instance = XpService._();
  factory XpService() => _instance;
  XpService._();

  static const String _xpKey     = 'user_xp_';
  static const String _avatarKey  = 'user_avatar_';

  // XP required per level (cumulative)
  static const List<int> _levelThresholds = [
    0, 100, 250, 450, 700, 1000, 1350, 1750, 2200, 2700, 3300,
    4000, 4800, 5700, 6700, 7800, 9000, 10300, 11700, 13200, 15000,
  ];

  static const List<String> _levelNames = [
    'Beginner', 'Novice', 'Apprentice', 'Student', 'Scholar',
    'Thinker', 'Analyst', 'Expert', 'Master', 'Sage', 'Genius',
    'Prodigy', 'Virtuoso', 'Legend', 'Champion', 'Elite',
    'Grandmaster', 'Titan', 'Mythic', 'Divine', 'Cerebro'
  ];

  // ── XP ────────────────────────────────────────────────────────────────────

  Future<int> getXp(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_xpKey$userId') ?? 0;
  }

  Future<void> addXp(int userId, int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('$_xpKey$userId') ?? 0;
    await prefs.setInt('$_xpKey$userId', current + amount);
  }

  Future<void> setXp(int userId, int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_xpKey$userId', amount);
  }

  // ── Level ─────────────────────────────────────────────────────────────────

  int getLevelFromXp(int xp) {
    for (int i = _levelThresholds.length - 1; i >= 0; i--) {
      if (xp >= _levelThresholds[i]) return i + 1;
    }
    return 1;
  }

  String getLevelName(int level) {
    final idx = (level - 1).clamp(0, _levelNames.length - 1);
    return _levelNames[idx];
  }

  int xpForLevel(int level) {
    final idx = (level - 1).clamp(0, _levelThresholds.length - 1);
    return _levelThresholds[idx];
  }

  int xpForNextLevel(int level) {
    final idx = level.clamp(0, _levelThresholds.length - 1);
    return _levelThresholds[idx];
  }

  double levelProgress(int xp) {
    final level     = getLevelFromXp(xp);
    final current   = xpForLevel(level);
    final next      = xpForNextLevel(level);
    if (next == current) return 1.0;
    return ((xp - current) / (next - current)).clamp(0.0, 1.0);
  }

  // XP earned per quiz based on score %
  int calculateQuizXp(double score, double totalPoints) {
    if (totalPoints <= 0) return 10;
    final percent = score / totalPoints;
    if (percent >= 0.9) return 100;
    if (percent >= 0.75) return 75;
    if (percent >= 0.5) return 50;
    if (percent >= 0.25) return 25;
    return 10; // participation XP
  }

  // ── Avatar ────────────────────────────────────────────────────────────────

  Future<int> getAvatarIndex(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_avatarKey$userId') ?? 0;
  }

  Future<void> setAvatarIndex(int userId, int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_avatarKey$userId', index);
  }

  // Available avatar options (emoji)
  static const List<String> avatarEmojis = [
    '🧑‍🎓', '👨‍🎓', '👩‍🎓', '🧑‍💻', '👨‍💻', '👩‍💻',
    '🦊', '🐼', '🐨', '🦁', '🐯', '🐸',
    '🚀', '⚡', '🔥', '🌟', '💎', '🎯',
    '🧠', '📚', '🏆', '🎮', '🎨', '🎵',
  ];
}