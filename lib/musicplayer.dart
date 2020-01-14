import 'package:audioplayer/audioplayer.dart';
import 'package:player/database.dart';

import 'song.dart';
import 'files.dart';

class MusicPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Function> _onPlaySongListeners = List<Function>();
  double _progress;
  bool _playing = true;
  Song _currentSong;
  bool locked = false;

  MusicPlayer() {
    _audioPlayer.onAudioPositionChanged.listen((Duration progress) {
      _progress = progress.inMilliseconds / 1000.0;
    });

    _audioPlayer.onPlayerStateChanged.listen((AudioPlayerState state) {
      switch (state) {
        case AudioPlayerState.COMPLETED:
          play(currentSong);
          _playing = true;
          break;
        case AudioPlayerState.PLAYING:
          _playing = true;
          break;
        case AudioPlayerState.STOPPED:
        case AudioPlayerState.PAUSED:
          _playing = false;
          break;
      }
    });
  }

  Future<void> _playRemote(String url) async {
    await _audioPlayer.play(url);
  }

  Future<void> _playLocal(String path) async {
    await _audioPlayer.play((await Files.getAbsoluteFilePath(path)), isLocal: true);
  }

  Future<bool> prepareToPlay(Song song) async {
    if (locked)
      return false;
    locked = true;
    _currentSong = song;
    await _audioPlayer.stop();
    return true;
  }

  Future<void> play(Song song) async {
    locked = false;
    print('playing song: ' + song.name);
    await _playLocal(song.audioFilePath);
    for (Function listener in _onPlaySongListeners) {
      listener(song);
    }
  }

  Future<void> resume() async {
    await _audioPlayer.play((await Files.getAbsoluteFilePath(_currentSong.audioFilePath)), isLocal: true);
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  Future<void> _seekPosition(double seconds) async {
    await _audioPlayer.seek(seconds);
  }

  Future<void> seekPercentage(double percentage) async {
    percentage = percentage < 0 ? 0 : percentage > 100 ? 100 : percentage;
    double position = _currentSong.duration * (percentage / 100);
    await _seekPosition(position);
    print('seeked position ' + position.toString());
  }

  Stream<AudioPlayerState> onPlayerStateChanged() {
    return _audioPlayer.onPlayerStateChanged;
  }

  void addOnPlaySongListener(Function listener) {
    this._onPlaySongListeners.add(listener);
  }

  void removeOnPlaySongListener(Function listener) {
    this._onPlaySongListeners.remove(listener);
  }

  Song get currentSong {
    return _currentSong;
  }

  double get progress {
    return _progress;
  }

  bool get playing {
    return _playing;
  }
}
