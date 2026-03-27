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
  SoundState build() => SoundState(
    enabled: SoundService().isBgEnabled,
    track:   SoundService().currentTrack,
  );

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

final soundProvider = NotifierProvider<SoundNotifier, SoundState>(SoundNotifier.new);

/// Direct access to [SoundService] singleton for one-shot SFX calls.
final soundServiceProvider = Provider<SoundService>((_) => SoundService());