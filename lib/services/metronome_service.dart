import 'package:audioplayers/audioplayers.dart';
import 'settings_service.dart';

class MetronomeService {
  AudioPlayer? _strongPlayer;
  AudioPlayer? _weakPlayer;

  int _tickIndex = 0;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    _strongPlayer = AudioPlayer();
    await _strongPlayer!.setSource(AssetSource('sounds/click_strong.wav'));
    await _strongPlayer!.setReleaseMode(ReleaseMode.stop);

    _weakPlayer = AudioPlayer();
    await _weakPlayer!.setSource(AssetSource('sounds/click_weak.wav'));
    await _weakPlayer!.setReleaseMode(ReleaseMode.stop);

    _initialized = true;
  }

  void play() {
    if (!_initialized) return;

    final volume = SettingsService().metronomeVolume;
    if (_tickIndex == 0) {
      _strongPlayer!.setVolume(volume);
      _strongPlayer!.seek(Duration.zero);
      _strongPlayer!.resume();
    } else {
      _weakPlayer!.setVolume(volume);
      _weakPlayer!.seek(Duration.zero);
      _weakPlayer!.resume();
    }

    _tickIndex = (_tickIndex + 1) % 4;
  }

  void reset() {
    _tickIndex = 0;
  }

  void dispose() {
    _strongPlayer?.dispose();
    _weakPlayer?.dispose();
    _initialized = false;
  }
}
