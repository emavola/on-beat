import 'package:audioplayers/audioplayers.dart';

class MetronomeService {
  final AudioPlayer _strongPlayer = AudioPlayer();
  final AudioPlayer _weakPlayer = AudioPlayer();

  int _beatCounter = 0; // 0..3
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await _strongPlayer.setSource(AssetSource('sounds/click_strong.wav'));
    await _weakPlayer.setSource(AssetSource('sounds/click_weak.wav'));

    _initialized = true;
  }

  void reset() {
    _beatCounter = 0;
  }

  /// Chiamare ad OGNI quarter deciso dal clock
  void play() {
    if (!_initialized) return;

    if (_beatCounter == 0) {
      _strongPlayer.stop();
      _strongPlayer.resume();
    } else {
      _weakPlayer.stop();
      _weakPlayer.resume();
    }

    _beatCounter = (_beatCounter + 1) % 4;
  }

  void dispose() {
    _strongPlayer.dispose();
    _weakPlayer.dispose();
  }
}
