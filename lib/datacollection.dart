import 'package:player/database.dart';
import 'package:player/musicplayer.dart';
import 'package:player/music.dart';

class MusicMonitor {
  MusicPlayer _musicPlayer;
  DbProvider _dbProvider;

  MusicMonitor(this._dbProvider, this._musicPlayer) {
    _musicPlayer.addOnPositionChangeListener(_onPositionChangeListener);
    _musicPlayer.addOnPauseListener(_onPauseListener);
    _musicPlayer.addOnPlayListener(_onPlayListener);
    _musicPlayer.addOnResumeListener(_onResumeListener);
    // _musicPlayer.addOnCompleteListener(_onCompleteListener);
    _musicPlayer.addOnSeekListener(_onSeekListener);
    // _musicPlayer.addOnSkipListener(_onSkipListener);
  }

  void _onPlayListener(Song newSong) {
    print('datacollection: new song \'' + newSong.name + '\'');
    _startNewPlayback(newSong.id);
  }

  void _onPositionChangeListener(Duration newPosition) {
    _dbProvider.getLastPlayback().then((Playback lastPlayback) {
      _dbProvider.updatePlaybackColumns(lastPlayback, <String, dynamic>{
        'endTimestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  void _onPauseListener() {
    _dbProvider.getLastPlayback().then((Playback lastPlayback) {
      _dbProvider.insertPause(lastPlayback.id,
                              DateTime.now().millisecondsSinceEpoch);
      print('datacollection: inserted pause');
    });
  }

  void _onResumeListener() {
    _dbProvider.getLastPlayback().then((Playback lastPlayback) {
      _dbProvider.insertResume(lastPlayback.id,
                               DateTime.now().millisecondsSinceEpoch);
      print('datacollection: inserted resume');
    });
  }

  void _onCompleteListener() {
    print('datacollection: complete, probs nothing to do now lol');
  }

  void _onSeekListener(Duration newPosition) {
    _dbProvider.getLastPlayback().then((Playback lastPlayback) {
      _dbProvider.insertSeek(lastPlayback.id,
                             newPosition.inMilliseconds / 1000,
                             DateTime.now().millisecondsSinceEpoch);
      print('datacollection: inserted seek');
    });
  }

  void _onSkipListener(Song newSong) {
    print('datacollection: skip');
  }

  Future _startNewPlayback(int songId) async {
    Playback newPlayback = Playback(
      songId: songId,
      startTimestamp: DateTime.now().millisecondsSinceEpoch,
      endTimestamp: -1,
    );
    _dbProvider.insertPlayback(newPlayback);
  }

}

class Playback {
  int id;
  int songId;
  int startTimestamp;
  int endTimestamp;

  Playback({this.id,
            this.songId,
            this.startTimestamp,
            this.endTimestamp});

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'songId': songId,
      'startTimestamp': startTimestamp,
      'endTimestamp': endTimestamp,
    };
  }

  static Playback fromMap(Map<String, dynamic> map) {
    return Playback(
      id: map['id'],
      songId: map['songId'],
      startTimestamp: map['startTimestamp'],
      endTimestamp: map['endTimestamp'],
    );
  }
}
