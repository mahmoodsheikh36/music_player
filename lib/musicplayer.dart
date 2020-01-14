import 'dart:collection';

import 'package:audioplayer/audioplayer.dart';
import 'package:player/database.dart';

import 'song.dart';
import 'files.dart';

class MusicPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Function> _onPlaySongListeners = List<Function>();
  double _progress;
  bool _playing = true;
  Queue<Song> _queue = Queue();

  MusicPlayer() {
    _audioPlayer.onAudioPositionChanged.listen((Duration progress) {
      _progress = progress.inMilliseconds / 1000.0;
    });

    _audioPlayer.onPlayerStateChanged.listen((AudioPlayerState state) {
      switch (state) {
        case AudioPlayerState.COMPLETED:
          _onSongComplete();
          _playing = false;
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

  Future<void> addToQueue(Song song) async {
    _queue.add(song);
  }

  Future<void> skip() async {
    await _audioPlayer.stop();
    _queue.removeFirst();
    if (_queue.isNotEmpty) {
      _playLocal(_queue.first.audioFilePath);
      _notifyPlaySongListeners(_queue.first);
    }
  }

  Future<void> play(Song song) async {
    print('playing song: ' + song.name);
    await _audioPlayer.stop();
    _queue.addFirst(song);
    await _playLocal(song.audioFilePath);
    _notifyPlaySongListeners(song);
  }

  Future<void> resume() async {
    Song songToResume = _queue.first;
    await _playLocal(songToResume.audioFilePath);
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  Future<void> _seekPosition(double seconds) async {
    print('seeked position ' + seconds.toString());
    await _audioPlayer.seek(seconds);
  }

  Future<void> seekPercentage(double percentage) async {
    percentage = percentage < 0 ? 0 : percentage > 100 ? 100 : percentage;
    double position = _queue.first.duration * (percentage / 100);
    await _seekPosition(position);
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

  void _onSongComplete() {
    _queue.removeFirst();
    if (_queue.isNotEmpty) {
      _playLocal(_queue.first.audioFilePath);
      _notifyPlaySongListeners(_queue.first);
    }
    else
      print('queue empty, no more songs');
  }

  void _notifyPlaySongListeners(Song song) {
    for (Function listener in _onPlaySongListeners) {
      listener(song);
    }
  }

  Song get currentSong {
    if (_queue.isEmpty)
      return null;
    return _queue.first;
  }

  double get progress {
    return _progress;
  }

  bool get playing {
    return _playing;
  }
}
