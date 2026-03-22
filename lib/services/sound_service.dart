import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;

  bool get isEnabled => _enabled;
  void setEnabled(bool val) => _enabled = val;

  // Play a short tap sound when selecting an answer
  Future<void> playSelect() async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/select.wav'), volume: 0.6);
    } catch (_) {}
  }

  // Play when moving to next question
  Future<void> playNext() async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/next.wav'), volume: 0.5);
    } catch (_) {}
  }

  // Play when timer is running low (< 10s)
  Future<void> playWarning() async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/warning.wav'), volume: 0.7);
    } catch (_) {}
  }

  // Play when quiz is submitted
  Future<void> playSubmit() async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/submit.wav'), volume: 0.8);
    } catch (_) {}
  }

  void dispose() => _player.dispose();
}