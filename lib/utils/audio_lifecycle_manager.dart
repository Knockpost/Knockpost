import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

/// Global singleton that automatically pauses ALL registered audio players
/// when the app is minimised / goes to background.
class AudioLifecycleManager with WidgetsBindingObserver {
  // ── Singleton ──────────────────────────────────────────────
  AudioLifecycleManager._();
  static final AudioLifecycleManager _instance = AudioLifecycleManager._();
  static AudioLifecycleManager get instance => _instance;

  bool _initialized = false;
  final Set<AudioPlayer> _players = {};

  /// Call once from main() after WidgetsFlutterBinding.ensureInitialized()
  void init() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Register a player so it is paused on background.
  void register(AudioPlayer player) => _players.add(player);

  /// Unregister a player (call in dispose, before player.dispose()).
  void unregister(AudioPlayer player) => _players.remove(player);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pauseAll();
    }
  }

  void _pauseAll() {
    for (final p in _players) {
      try {
        if (p.playing) p.pause();
      } catch (_) {}
    }
  }

  /// Ensures that ONLY 'player' plays, pausing all other active registered players.
  Future<void> playExclusive(AudioPlayer player) async {
    for (final p in _players) {
      if (p != player) {
        try {
          if (p.playing) await p.pause();
        } catch (_) {}
      }
    }
    
    try {
      await player.play();
    } catch (_) {}
  }
}
