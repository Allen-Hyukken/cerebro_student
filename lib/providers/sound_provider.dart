import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/services/sound_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class SoundState {
  final bool       enabled;
  final MusicTrack track;

  const SoundState({required this.enabled, required this.track});

  SoundState copyWith({bool? enabled, MusicTrack? track}) =>
      SoundState(enabled: enabled ?? this.enabled, track: track ?? this.track);
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class SoundNotifier extends Notifier<SoundState> {
  @override
  SoundState build() {
    // ✅ BUG FIX:
    // Previously, SoundService().init() loaded prefs AFTER this build()
    // ran, so currentTrack was still the enum default (background) even
    // when LOCK-IN was saved. The result: music plays LOCK-IN but the
    // label shows "Default".
    //
    // Fix: main.dart now awaits SoundService().init() BEFORE ProviderScope
    // is created. So by the time build() runs here, _currentTrack is already
    // correctly set from prefs — no race condition.
    return SoundState(
      enabled: SoundService().isBgEnabled,
      track:   SoundService().currentTrack,  // ← now always correct
    );
  }

  Future<void> toggle() async {
    await SoundService().toggleBackground();
    state = state.copyWith(enabled: SoundService().isBgEnabled);
  }

  Future<void> setEnabled(bool value) async {
    await SoundService().setEnabled(value);
    state = state.copyWith(enabled: value);
  }

  Future<void> setTrack(MusicTrack track) async {
    await SoundService().setTrack(track);
    state = state.copyWith(track: track);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final soundProvider =
NotifierProvider<SoundNotifier, SoundState>(SoundNotifier.new);

final soundServiceProvider =
Provider<SoundService>((_) => SoundService());