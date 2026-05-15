import 'package:just_audio/just_audio.dart';

import '../domain/adhan_model.dart';

class AdhanService {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> playAdhan({
    required Muezzin muezzin,
    required bool isFajr,
  }) async {
    try {
      if (_isPlaying) await stop();
      await _player.setAsset(muezzin.assetPath(isFajr: isFajr));
      await _player.play();
      _isPlaying = true;
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
        }
      });
    } catch (_) {
      // Asset may not exist yet — fail silently.
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
  }

  void dispose() {
    _player.dispose();
  }
}
