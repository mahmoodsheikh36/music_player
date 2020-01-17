import 'dart:core';
import 'musicplayer.dart';
import 'song.dart';
import 'database.dart';

class MusicMonitor {
  MusicPlayer _musicPlayer;
  SongProvider _songProvider;

  Future _updatePlayback(double newSeconds, double songProgress) async {
    Playback lastPlayback = await _songProvider.getLastPlayback();
    Song song = await _songProvider.getSong(lastPlayback.songId);
    double secondsListened;
    if (song.secondsListened == null)
      secondsListened = 0;
    else
      secondsListened = song.secondsListened;
    double totalSeconds = newSeconds + secondsListened;
    await _songProvider.updateSongColumns(song,
      <String, dynamic>{'secondsListened': totalSeconds});

    _songProvider.updatePlaybackColumns(await lastPlayback,
      <String, dynamic>{
        'endDate': DateTime.now().toString(),
        'progressOnEnd': songProgress
      });
  }

  Future _startNewPlayback(int songId) async {
    String datetime = DateTime.now().toString();
    Playback playback = Playback(
      songId: songId,
      startDate: datetime,
      endDate: datetime,
      progressOnEnd: -1
    );
    await _songProvider.insertPlayback(playback);
  }

  void _onPlaySongListener(Song oldSong, Song newSong) {
    _startNewPlayback(newSong.id);
  }

  void _onProgressListener(double oldProgress,
                           double newProgress,
                           bool   seekedPosition) {
    if (seekedPosition)
      return;
    double secondsListened = newProgress - oldProgress;

    /* happens after musicPlayer.seekPosition() is called */
    if (secondsListened <= 0)
      return;

    _updatePlayback(secondsListened, newProgress);

    // print('seconds to be logged ' + (secondsListened).toString());
  }

  void _onResumeListener() {
    _startNewPlayback(_musicPlayer.currentSong.id);
  }

  MusicMonitor(this._songProvider, this._musicPlayer) {
    _musicPlayer.addOnPlaySongListener(_onPlaySongListener);
    _musicPlayer.addOnProgressListener(_onProgressListener);
    _musicPlayer.addOnResumeListener(_onResumeListener);
  }
}

class Playback {
  int id;
  int songId;
  String startDate;
  String endDate;
  double progressOnEnd;

  Playback({this.id, this.songId, this.startDate, this.endDate, this.progressOnEnd});

  Map<String, dynamic> toMap({bool withId = true}) {
    Map<String, dynamic> map = {
      'songId': songId,
      'startDate': startDate,
      'endDate': endDate,
      'progressOnEnd': progressOnEnd,
    };
    if (withId) {
      map['id'] = id;
    }
    return map;
  }

  static Playback fromMap(Map<String, dynamic> map) {
    return Playback(
      id: map['id'],
      songId: map['songId'],
      startDate: map['startDate'],
      endDate: map['endDate'],
      progressOnEnd: map['progressOnEnd']
    );
  }
}
