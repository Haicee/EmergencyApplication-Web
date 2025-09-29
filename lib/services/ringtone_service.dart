import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io' show Platform;

class RingtoneService {
  RingtoneService._();

  // Single shared player instance for ringtones
  static final AudioPlayer _player = AudioPlayer();
  static bool _isPlaying = false;

  // Defaults to your provided file path (supports spaces in filename)
  static String _assetPath = 'assets/audio/Telephone Ringtone.mp3';
  static double _incomingVolume = 1.0;
  static double _outgoingVolume = 0.9;

  // Optional setters if you want to change at runtime
  static void setCustomAsset(String path) {
    _assetPath = path;
  }
  static void setVolumes({double? incoming, double? outgoing}) {
    if (incoming != null) _incomingVolume = incoming.clamp(0.0, 1.0);
    if (outgoing != null) _outgoingVolume = outgoing.clamp(0.0, 1.0);
  }

  static Future<void> _playLooped(String assetPath, double volume) async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(volume);
      // AssetSource expects a path relative to the assets/ root; we strip the leading 'assets/' if present
      final relative = assetPath.startsWith('assets/')
          ? assetPath.substring('assets/'.length)
          : assetPath;
      await _player.play(AssetSource(relative));
      _isPlaying = true;
    } catch (e) {
      if (kDebugMode) {
        print('RingtoneService: failed to play asset "$assetPath": $e');
      }
      _isPlaying = false;
    }
  }

  static Future<void> playIncoming() async {
    if (!_isSupported) return;
    await _playLooped(_assetPath, _incomingVolume);
  }

  static Future<void> playOutgoing() async {
    if (!_isSupported) return;
    await _playLooped(_assetPath, _outgoingVolume);
  }

  static Future<void> stop() async {
    if (!_isSupported) return;
    if (_isPlaying) {
      await _player.stop();
      _isPlaying = false;
    }
  }
}

bool get _isSupported {
  // audioplayers works on Android/iOS/Web; in this app we mainly need Android/iOS
  if (kIsWeb) return true;
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}
