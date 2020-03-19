import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:collection';
import 'music.dart';

enum PlaybackMode {
  LOOP_ONE_SONG,
  LOOP
}

class MusicPlayer {
  // typedef Listener = void Function(double previous, double current, bool seekedPosition);
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Function> _onPlayListeners = List<Function>();
  final List<Function> _onPositionChangeListeners = List<Function>();
  final List<Function> _onPauseListeners = List<Function>();
  final List<Function> _onResumeListeners = List<Function>();
  final List<Function> _onSkipListeners = List<Function>();
  final List<Function> _onCompleteListeners = List<Function>();
  final List<Function> _onSeekListeners = List<Function>();
  final List<Function> _onAddToQueueListeners = List<Function>();
  final Queue<Song> _queue = Queue<Song>();
  final Queue<Song> _endedSongs = Queue<Song>();
  PlaybackMode _playbackMode = PlaybackMode.LOOP;

  MusicPlayer() {
    _audioPlayer.onAudioPositionChanged.listen((Duration position) {
      _notifyOnPositionChangeListeners(position);
    });

    _audioPlayer.onPlayerStateChanged.listen((AudioPlayerState state) {
      print(state);
      switch (state) {
        case AudioPlayerState.COMPLETED:
          _onSongComplete();
          break;
        default:
          break;
      }
    });
  }

  Future<void> _playRemote(String url) async {
    await _audioPlayer.play(url);
  }

  Future<void> _playLocal(String path) async {
    await _audioPlayer.play(path, isLocal: true);
  }

  void addToQueue(Song song) {
    bool emptyQueue = _queue.isEmpty;
    _queue.addLast(song);
    if (emptyQueue) {
      _playLocal(song.audio.path).then((whatever) {
        _notifyOnAddToQueueListeners();
        this._notifyOnPlayListeners(song);
      });
    } else {
      _notifyOnAddToQueueListeners();
    }
  }

  Future<void> skip() async {
    await _audioPlayer.stop();
    _endedSongs.addLast(_queue.removeFirst());
    if (_queue.isEmpty) {
      _queue.add(_endedSongs.removeFirst());
    }
    await _playLocal(_queue.first.audio.path);
    _playbackMode = PlaybackMode.LOOP;
    _notifyOnSkipListeners(_queue.first);
    _notifyOnPlayListeners(_queue.first);
  }

  Future skipToPrevious() async {
    bool wasPaused = !isPlaying();
    int positionInMillis = await getCurrentPosition();
    await _audioPlayer.stop();
    print('endedSongs queue size: ' + _endedSongs.length.toString());
    /* if more than 4 seconds, then we want to go to the beginning of the song */
    if (positionInMillis > 4000) {
      await _playLocal(_queue.first.audio.path);
      _notifyOnSeekListeners(new Duration(seconds: 0));
    } else {
      Song lastEndedSong = _endedSongs.isNotEmpty ? _endedSongs.removeLast() : null;
      _endedSongs.addLast(_queue.removeFirst());
      if (lastEndedSong != null) {
        _queue.addFirst(lastEndedSong);
        await _playLocal(_queue.first.audio.path);
        _notifyOnSkipListeners(_queue.first);
        _notifyOnPlayListeners(_queue.first);
      } else {
        _queue.addFirst(_endedSongs.removeFirst());
        await _playLocal(_queue.first.audio.path);
        /* if there were no songs in the ended songs queue,
          consider it a seek-to-position/replay action */
        _notifyOnSeekListeners(new Duration(seconds: 0));
        if (wasPaused)
          _notifyOnResumeListeners();
      }
      _playbackMode = PlaybackMode.LOOP;
    }
  }

  Future<void> play(Song song) async {
    if (_queue.isNotEmpty) {
      _queue.clear();
      _endedSongs.clear();
      await _audioPlayer.stop();
    }
    _queue.addFirst(song);
    await _playLocal(song.audio.path);
    _playbackMode = PlaybackMode.LOOP;
    _notifyOnPlayListeners(song);
  }

  Future<void> resume() async {
    Song songToResume = _queue.first;
    await _playLocal(songToResume.audio.path);
    _notifyOnResumeListeners();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _notifyOnPauseListeners();
  }

  Future<void> _seekDuration(Duration duration) async {
    print('seeked duration ' + duration.toString());
    await _audioPlayer.seek(duration);
    _notifyOnSeekListeners(duration);
  }

  Future<void> seekPercentage(double percentage) async {
    percentage = percentage < 0 ? 0 : percentage > 100 ? 100 : percentage;
    double seconds = _queue.first.duration * (percentage / 100);
    int milliSeconds = ((seconds * 1000) % 1000).toInt();
    await _seekDuration(Duration(seconds: seconds.toInt(),
                                 milliseconds: milliSeconds));
  }

  void addOnPlayListener(Function listener) {
    this._onPlayListeners.add(listener);
  }
  void removeOnPlayListener(Function listener) {
    this._onPlayListeners.remove(listener);
  }
  void _notifyOnPlayListeners(Song song) {
    for (Function listener in _onPlayListeners) {
      listener(song);
    }
  }

  void addOnPositionChangeListener(Function listener) {
    this._onPositionChangeListeners.add(listener);
  }
  void removeOnPositionChangeListener(Function listener) {
    this._onPositionChangeListeners.remove(listener);
  }
  void _notifyOnPositionChangeListeners(Duration newPosition) {
    for (Function listener in _onPositionChangeListeners) {
      listener(newPosition);
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
    this._onResumeListeners.remove(listener);
  }
  void _notifyOnResumeListeners() {
    print('notifying resume...');
    for (Function listener in _onResumeListeners) {
      listener();
    }
  }

  void addOnCompleteListener(Function listener) {
    this._onCompleteListeners.add(listener);
  }
  void removeOnCompleteListener(Function listener) {
    this._onCompleteListeners.remove(listener);
  }
  void _notifyOnCompleteListeners() {
    for (Function listener in _onCompleteListeners) {
      listener();
    }
  }

  void addOnSkipListener(Function listener) {
    this._onSkipListeners.add(listener);
  }
  void removeOnSkipListener(Function listener) {
    this._onSkipListeners.remove(listener);
  }
  void _notifyOnSkipListeners(Song newSong) {
    for (Function listener in _onSkipListeners) {
      listener(newSong);
    }
  }

  void addOnSeekListener(Function listener) {
    this._onSeekListeners.add(listener);
  }
  void removeOnSeekListener(Function listener) {
    this._onSeekListeners.remove(listener);
  }
  void _notifyOnSeekListeners(Duration newDuration) {
    for (Function listener in _onSeekListeners) {
      listener(newDuration);
    }
  }

  void addOnAddToQueueListener(Function listener) {
    this._onAddToQueueListeners.add(listener);
  }
  void removeOnAddToQueueListener(Function listener) {
    this._onAddToQueueListeners.remove(listener);
  }
  void _notifyOnAddToQueueListeners() {
    for (Function listener in _onAddToQueueListeners) {
      listener();
    }
  }

  Future<void> _onSongComplete() async {
    await _audioPlayer.stop();
    print(_queue.first.id.toString() + ' completed');
    if (_playbackMode == PlaybackMode.LOOP_ONE_SONG) {
      await _playLocal(_queue.first.audio.path);
    } else if (_playbackMode == PlaybackMode.LOOP) {
      _endedSongs.addLast(_queue.removeFirst());
      if (_queue.isEmpty) {
        _queue.add(_endedSongs.removeFirst());
      }
      await _playLocal(_queue.first.audio.path);
    }
    _notifyOnCompleteListeners();
    _notifyOnPlayListeners(_queue.first);
  }

  Song get currentSong {
    if (_queue.isEmpty)
      return null;
    return _queue.first;
  }

  bool isPlaying() {
    return _audioPlayer.state == AudioPlayerState.PLAYING;
  }

  /* current position in milliseconds */
  Future<int> getCurrentPosition() async {
    return await _audioPlayer.getCurrentPosition();
  }

  void changePlaybackMode() {
    if (_playbackMode == PlaybackMode.LOOP_ONE_SONG)
      _playbackMode = PlaybackMode.LOOP;
    else if (_playbackMode == PlaybackMode.LOOP)
      _playbackMode = PlaybackMode.LOOP_ONE_SONG;
  }

  PlaybackMode get playbackMode => _playbackMode;
}
