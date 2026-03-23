import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  final AudioPlayer _bgPlayer      = AudioPlayer(playerId: 'bg');
  final AudioPlayer _clickPlayer   = AudioPlayer(playerId: 'click');
  final AudioPlayer _warningPlayer = AudioPlayer(playerId: 'warning');
  final AudioPlayer _finishPlayer  = AudioPlayer(playerId: 'finish');

  bool _bgEnabled = true;
  bool get isBgEnabled => _bgEnabled;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ));
    } catch (_) {}
  }

  // ── Background music ──────────────────────────────────────────────────────
  Future<void> playBackground() async {
    if (!_bgEnabled) return;
    try {
      await _bgPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ));
      await _bgPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgPlayer.setVolume(3.0);
      await _bgPlayer.play(AssetSource('sounds/background.mp3'));
    } catch (_) {}
  }

  Future<void> stopBackground() async {
    try { await _bgPlayer.stop(); } catch (_) {}
  }

  Future<void> toggleBackground() async {
    _bgEnabled = !_bgEnabled;
    if (_bgEnabled) await playBackground();
    else await stopBackground();
  }

  // ── Click ─────────────────────────────────────────────────────────────────
  Future<void> playClick() async {
    try {
      await _clickPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ));
      await _clickPlayer.stop();
      await _clickPlayer.setVolume(0.8);
      await _clickPlayer.play(AssetSource('sounds/click.mp3'));
    } catch (_) {}
  }

  // ── Warning ───────────────────────────────────────────────────────────────
  Future<void> playWarning() async {
    try {
      await _warningPlayer.stop();
      await _warningPlayer.setVolume(0.9);
      await _warningPlayer.play(AssetSource('sounds/warning.mp3'));
    } catch (_) {}
  }

  // ── Finish ────────────────────────────────────────────────────────────────
  Future<void> playFinish() async {
    try {
      await _finishPlayer.stop();
      await _finishPlayer.setVolume(1.0);
      await _finishPlayer.play(AssetSource('sounds/finish.mp3'));
    } catch (_) {}
  }

  Future<void> playSelect() => playClick();
  Future<void> playNext()   => playClick();
  Future<void> playSubmit() => playFinish();

  void dispose() {
    _bgPlayer.dispose();
    _clickPlayer.dispose();
    _warningPlayer.dispose();
    _finishPlayer.dispose();
  }
}