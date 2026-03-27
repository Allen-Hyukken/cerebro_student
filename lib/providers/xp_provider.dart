import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/services/xp_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class XpState {
  final int xp;
  final int avatarIndex;
  final bool loading;

  const XpState({this.xp = 0, this.avatarIndex = 0, this.loading = true});

  XpState copyWith({int? xp, int? avatarIndex, bool? loading}) => XpState(
    xp:          xp          ?? this.xp,
    avatarIndex: avatarIndex ?? this.avatarIndex,
    loading:     loading     ?? this.loading,
  );

  // ── Computed helpers (delegate to XpService) ───────────────────────────────
  int    get level        => XpService().getLevelFromXp(xp);
  String get levelName    => XpService().getLevelName(level);
  double get levelProgress => XpService().levelProgress(xp);
  int    get xpForLevel   => XpService().xpForLevel(level);
  int    get xpForNext    => XpService().xpForNextLevel(level);
  String get emoji        => XpService.avatarEmojis[avatarIndex];
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class XpNotifier extends Notifier<XpState> {
  @override
  XpState build() {
    _load(); // fire-and-forget; state starts with loading: true
    return const XpState();
  }

  int get _uid => ApiService.userId ?? 0;

  Future<void> _load() async {
    final xp = await XpService().getXp(_uid);
    final av = await XpService().getAvatarIndex(_uid);
    state = XpState(xp: xp, avatarIndex: av, loading: false);
  }

  /// Force a full reload (call after returning from ProfileScreen, etc.).
  Future<void> reload() => _load();

  /// Award XP after a quiz and update state.
  Future<int> addXp(int amount) async {
    await XpService().addXp(_uid, amount);
    final xp = await XpService().getXp(_uid);
    state = state.copyWith(xp: xp, loading: false);
    return xp;
  }

  Future<void> setAvatarIndex(int index) async {
    await XpService().setAvatarIndex(_uid, index);
    state = state.copyWith(avatarIndex: index);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final xpProvider = NotifierProvider<XpNotifier, XpState>(XpNotifier.new);

/// Per-player avatar index — used by leaderboard rows.
/// Auto-disposes when the widget is no longer listening.
final playerAvatarProvider = FutureProvider.autoDispose.family<int, int>(
      (ref, userId) => XpService().getAvatarIndex(userId),
);