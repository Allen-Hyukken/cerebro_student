import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Music track catalogue ──────────────────────────────────────────────────────

enum MusicTrack { background, batidaoFunk }

extension MusicTrackX on MusicTrack {
  String get label {
    switch (this) {
      case MusicTrack.background:  return 'Default';
      case MusicTrack.batidaoFunk: return 'LOCK-IN';
    }
  }

  String get emoji {
    switch (this) {
      case MusicTrack.background:  return '🎵';
      case MusicTrack.batidaoFunk: return '🎶';
    }
  }

  String get asset {
    switch (this) {
      case MusicTrack.background:  return 'sounds/background.mp3';
      case MusicTrack.batidaoFunk: return 'sounds/batidao_funk.mp3';
    }
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  static const _prefEnabled = 'bg_music_enabled';
  static const _prefTrack   = 'bg_music_track';

  final _bgPlayer      = AudioPlayer(playerId: 'bg');
  final _clickPlayer   = AudioPlayer(playerId: 'click');
  final _warningPlayer = AudioPlayer(playerId: 'warning');
  final _finishPlayer  = AudioPlayer(playerId: 'finish');

  bool       _bgEnabled    = true;
  MusicTrack _currentTrack = MusicTrack.background;

  bool       get isBgEnabled   => _bgEnabled;
  MusicTrack get currentTrack  => _currentTrack;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _bgEnabled    = prefs.getBool(_prefEnabled) ?? true;
    _currentTrack = MusicTrack.values[prefs.getInt(_prefTrack) ?? 0];

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
      await _bgPlayer.setVolume(0.6);
      await _bgPlayer.play(AssetSource(_currentTrack.asset));
    } catch (_) {}
  }

  Future<void> stopBackground() async {
    try { await _bgPlayer.stop(); } catch (_) {}
  }

  Future<void> toggleBackground() async {
    _bgEnabled = !_bgEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, _bgEnabled);
    _bgEnabled ? await playBackground() : await stopBackground();
  }

  Future<void> setEnabled(bool value) async {
    _bgEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, value);
    value ? await playBackground() : await stopBackground();
  }

  /// Switch to a different track (restarts playback if currently playing).
  Future<void> setTrack(MusicTrack track) async {
    _currentTrack = track;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefTrack, track.index);
    if (_bgEnabled) {
      await stopBackground();
      await playBackground();
    }
  }

  // ── SFX ───────────────────────────────────────────────────────────────────

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

  Future<void> playWarning() async {
    try {
      await _warningPlayer.stop();
      await _warningPlayer.setVolume(0.9);
      await _warningPlayer.play(AssetSource('sounds/warning.mp3'));
    } catch (_) {}
  }

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