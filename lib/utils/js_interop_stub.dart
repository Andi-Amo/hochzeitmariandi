import 'package:audioplayers/audioplayers.dart';

// On Android/iOS/desktop there's no `dart:js`, so we mirror the same sound
// effects the web build triggers via JS (see js_interop_web.dart) using the
// audioplayers package instead. Asset paths are relative to the pubspec
// `assets/` folder (audioplayers adds that prefix itself), so no double
// "assets/" prefix is needed here (unlike the raw web URLs in index.html).
final AudioPlayer _homeMusicPlayer = AudioPlayer();
final AudioPlayer _countdownPlayer = AudioPlayer()
  ..setReleaseMode(ReleaseMode.loop);

Future<void> _restartAndPlay(AudioPlayer player, AssetSource source) async {
  try {
    await player.stop();
    await player.play(source);
  } catch (e) {
    // Ignore playback errors (e.g., missing audio focus, file not found).
  }
}

void callJsMethod(String method, [List<dynamic> args = const []]) {
  switch (method) {
    case 'playAudio':
      _restartAndPlay(_homeMusicPlayer, AssetSource('audio/take_me_home.mp3'));
      break;
    case 'stopAudio':
      _homeMusicPlayer.stop();
      break;
    case 'playCountdownSoundLoop':
      if (_countdownPlayer.state != PlayerState.playing) {
        _countdownPlayer
            .play(
              AssetSource(
                'audio/audioatlant-dominator-action-countdown-trailer-short-1-554634.mp3',
              ),
            )
            .catchError((_) {});
      }
      break;
    case 'stopCountdownSound':
      _countdownPlayer.stop();
      break;
  }
}
