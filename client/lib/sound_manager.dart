// 音效管理器：audioplayers 播放合成的 WAV 音效
import 'package:audioplayers/audioplayers.dart';

/// 音效名称：discard / draw / peng / gang / hu / win
class SoundManager {
  SoundManager._();
  static bool enabled = true;

  static final Map<String, AudioPlayer> _pool = {};

  /// 供 UI 访问（静音时停掉所有播放）
  static Map<String, AudioPlayer> get pool => _pool;

  static AudioPlayer _playerFor(String name) {
    return _pool.putIfAbsent(
        name, () => AudioPlayer()..setReleaseMode(ReleaseMode.stop));
  }

  static Future<void> play(String name, {double volume = 1}) async {
    if (!enabled) return;
    try {
      final p = _playerFor(name);
      await p.setVolume(volume);
      await p.play(AssetSource('sounds/$name.wav'));
    } catch (_) {
      // 音频失败不影响游戏
    }
  }

  static void discard() => play('discard', volume: 0.7);
  static void drawSound() => play('draw', volume: 0.5);
  static void peng() => play('peng');
  static void gang() => play('gang');
  static void hu() => play('hu');
  static void win() => play('win');
}
