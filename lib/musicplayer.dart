import 'dart:collection';

import 'package:audioplayer/audioplayer.dart';
import 'package:player/database.dart';

import 'song.dart';
import 'files.dart';

class MusicPlayer {
  // typedef Listener = void Function(double previous, double current, bool seekedPosition);
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Function> _onPlaySongListeners = List<Function>();
  final List<Function> _onProgressListeners = List<Function>();
  final List<Function> _onPauseListeners = List<Function>();
  final List<Function> _onResumeListeners = List<Function>();
  final Queue<Song> _queue = Queue();
  double _progress = 0;
  bool _playing = false;

  MusicPlayer() {
    _audioPlayer.onAudioPositionChanged.listen((Duration progress) {
      double newProgress = progress.inMilliseconds / 1000.0;
      _notifyOnProgressListeners(_progress, newProgress, false);
      _progress = newProgress;
    });

    _audioPlayer.onPlayerStateChanged.listen((AudioPlayerState state) {
      print(state);
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

  void addToQueue(Song song) {
    bool emptyQueue = _queue.isEmpty;
    _queue.addLast(song);
    if (emptyQueue) {
      _playLocal(song.audioFilePath).then((whatever) {
          _playing = true;
          this._notifyPlaySongListeners(null, song);
      });
    }
  }

  Future<void> skip() async {
    await _audioPlayer.stop();
    _progress = 0;
    Song skippedSong = _queue.removeFirst();
    if (_queue.isEmpty) {
      _queue.addFirst(skippedSong);
    }
    await _playLocal(_queue.first.audioFilePath);
    _notifyPlaySongListeners(skippedSong, _queue.first);
  }

  Future<void> play(Song song) async {
    await _audioPlayer.stop();
    _progress = 0;
    Song skippedSong;
    if (!_queue.isEmpty)
      skippedSong = _queue.removeFirst();
    _queue.addFirst(song);
    await _playLocal(song.audioFilePath);
    _notifyPlaySongListeners(skippedSong, song);
  }

  Future<void> resume() async {
    Song songToResume = _queue.first;
    await _playLocal(songToResume.audioFilePath);
    _playing = true;
    _notifyOnResumeListeners();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _playing = false;
    _notifyOnPauseListeners();
  }

  Future<void> _seekPosition(double seconds) async {
    print('seeked position ' + seconds.toString());
    await _audioPlayer.seek(seconds);
    _notifyOnProgressListeners(_progress, seconds, true);
    _progress = seconds;
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
  void _notifyPlaySongListeners(Song oldSong, Song newSong) {
    for (Function listener in _onPlaySongListeners) {
      listener(oldSong, newSong);
    }
  }

  void addOnProgressListener(Function listener) {
    this._onProgressListeners.add(listener);
  }
  void removeOnProgressListener(Function listener) {
    this._onProgressListeners.remove(listener);
  }
  void _notifyOnProgressListeners(double previousProgress,
                                  double currentProgress,
                                  bool   seekedPosition) {
    for (Function listener in _onProgressListeners) {
      listener(previousProgress, currentProgress, seekedPosition);
    }
  }

  void addOnPauseListener(Function listener) {
    this._onPauseListeners.add(listener);
  }
  void removeOnPauseListener(Function listener) {
    this._onPauseListeners.remove(listener);
  }
  void _notifyOnPauseListeners() {
    for (Function listener in _onPauseListeners) {
      listener();
    }
  }

  void addOnResumeListener(Function listener) {
    this._onResumeListeners.add(listener);
  }
  void removeOnResumeListener(Function listener) {
    this._onPauseListeners.remove(listener);
  }
  void _notifyOnResumeListeners() {
    print('notifying resume...');
    for (Function listener in _onResumeListeners) {
      listener();
    }
  }

  Future<void> _onSongComplete() async {
    await _audioPlayer.stop();
    _progress = 0;
    Song removedSong = _queue.removeFirst();
    if (_queue.isNotEmpty) {
      await _playLocal(_queue.first.audioFilePath);
      _notifyPlaySongListeners(removedSong, _queue.first);
    } else {
      print('queue empty after complete, replaying last song');
      _queue.addFirst(removedSong);
      await _playLocal(removedSong.audioFilePath);
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
