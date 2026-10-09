import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

abstract final class GameAudio {
  static final AudioPlayer _sfxPlayer = AudioPlayer();
  static final AudioPlayer _musicPlayer = AudioPlayer();
  static final Map<String, Future<Uint8List>> _assetCache =
      <String, Future<Uint8List>>{};
  static bool _musicPlaying = false;

  static Future<Uint8List> _loadAsset(String asset) {
    return _assetCache.putIfAbsent(asset, () async {
      final ByteData data = await rootBundle.load(asset);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    });
  }

  static Future<void> _play(String asset, {required double volume}) async {
    try {
      await _sfxPlayer.stop();
      final Uint8List bytes = await _loadAsset(asset);
      await _sfxPlayer.play(
        BytesSource(bytes, mimeType: 'audio/mpeg'),
        volume: volume,
      );
    } catch (_) {
      // Audio is a polish layer; the game must remain fully usable if a
      // browser blocks autoplay or the platform audio backend is unavailable.
    }
  }

  static Future<void> tap() =>
      _play('game_tien_len/audio/ui_click.mp3', volume: 0.28);

  static Future<void> playCard() =>
      _play('game_tien_len/audio/card_place.mp3', volume: 0.34);

  static Future<void> enterRoom() =>
      _play('game_tien_len/audio/room_enter.mp3', volume: 0.32);

  static Future<void> startLobbyMusic() async {
    if (_musicPlaying) return;

    try {
      _musicPlaying = true;
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.play(
        AssetSource('game_tien_len/audio/lottery_game_loop.wav'),
        volume: 0.16,
      );
    } catch (_) {
      _musicPlaying = false;
      // Background music is optional polish; never block game play.
    }
  }

  static Future<void> stopLobbyMusic() async {
    try {
      _musicPlaying = false;
      await _musicPlayer.stop();
    } catch (_) {
      // Ignore audio backend shutdown errors.
    }
  }
}
