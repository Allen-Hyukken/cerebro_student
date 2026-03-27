import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/services/sound_service.dart';

// ── Notifier (bg-music enabled/disabled) ─────────────────────────────────────

class SoundNotifier extends Notifier<bool> {
  @override
  bool build() => SoundService().isBgEnabled;

  Future<void> toggle() async {
    await SoundService().toggleBackground();
    state = SoundService().isBgEnabled;
  }

  Future<void> setEnabled(bool value) async {
    if (value) {
      await SoundService().playBackground();
    } else {
      await SoundService().stopBackground();
    }
    state = value;
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Background-music on/off state.
final soundProvider = NotifierProvider<SoundNotifier, bool>(SoundNotifier.new);

/// Direct access to [SoundService] singleton for one-shot SFX calls.
final soundServiceProvider = Provider<SoundService>((_) => SoundService());