import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:player/database.dart';
import 'package:player/musicplayer.dart';
import 'package:player/song.dart';

import 'files.dart';

class MusicPlayerWidget extends StatefulWidget {
  final MusicPlayer _musicPlayer;
  final SongProvider _songProvider;

  MusicPlayerWidget(this._songProvider, this._musicPlayer);

  _MusicPlayerWidgetState createState() => _MusicPlayerWidgetState(_songProvider, _musicPlayer);
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget> {
  final MusicPlayer _musicPlayer;
  final SongProvider _songProvider;

  void _onPlaySongListener(Song oldSong, Song newSong) {
    setState(() {
      /* just rebuild the widget */
    });
  }

  _MusicPlayerWidgetState(this._songProvider, this._musicPlayer) {
    _musicPlayer.addOnPlaySongListener(_onPlaySongListener);
  }

  @override
  void dispose() {
    _musicPlayer.removeOnPlaySongListener(_onPlaySongListener);
    super.dispose();
  }

  Future<File> _getSongImageFile(Song song) async {
    bool success = await _songProvider.prepareSongForPlayerPreview(song);
    if (success)
      return File(await Files.getAbsoluteFilePath(song.imageFilePath));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _musicPlayer.currentSong != null ?
      Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            FutureBuilder<File>(
              future: _getSongImageFile(_musicPlayer.currentSong),
              builder: (BuildContext context, AsyncSnapshot<File> snapshot) {
                if (snapshot.hasError)
                print(snapshot.error);

                if (snapshot.hasData && snapshot.data != null) {
                  return Image.file(
                    snapshot.data,
                    width: MediaQuery.of(context).size.width * 0.65,
                  );
                } else {
                  return CircularProgressIndicator();
                }
              },
            ),
            SizedBox(height: 40),
            Text(
              _musicPlayer.currentSong.name + ' - ' + _musicPlayer.currentSong.artist,
              style: Theme.of(context).textTheme.title,
            ),
            SizedBox(height: 40),
            _ProgressIndicator(_musicPlayer),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  tooltip: 'go back',
                  icon: Icon(Icons.skip_previous),
                  iconSize: 35,
                ),
                _PlayPauseButton(_musicPlayer),
                IconButton(
                  tooltip: 'skip',
                  icon: Icon(Icons.skip_next),
                  iconSize: 35,
                ),
              ],
            ),
          ],
        )
      ) : CircularProgressIndicator()
    );
  }

}

class _ProgressIndicator extends StatefulWidget {
  final MusicPlayer _musicPlayer;

  _ProgressIndicator(this._musicPlayer);

  @override
  _ProgressIndicatorState createState() => _ProgressIndicatorState(_musicPlayer);
}

class _ProgressIndicatorState extends State<_ProgressIndicator> with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<double> _animation;
  final GlobalKey _gestureDetectorKey = GlobalKey();
  MusicPlayer _musicPlayer;

  _ProgressIndicatorState(this._musicPlayer);

  Future<void> _onPlaySongListener(Song oldSong, Song newSong) async {
    _controller.duration = new Duration(seconds: newSong.duration);
    // _controller..forward(from: 0);
  }

  Future<void> _onProgressListener(double oldProgress,
                                   double newProgress,
                                   bool   seekedPosition) {
    _controller.value = newProgress / _musicPlayer.currentSong.duration;
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(seconds: _musicPlayer.currentSong.duration),
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );//..forward(from: _musicPlayer.progress / _musicPlayer.currentSong.duration);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    )..addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.dismissed)
        _controller.forward();
      else if (status == AnimationStatus.completed)
        _controller.reset();
    });

    _musicPlayer.addOnPlaySongListener(_onPlaySongListener);
    _musicPlayer.addOnProgressListener(_onProgressListener);
  }

  @override
  void dispose() {
    _musicPlayer.removeOnPlaySongListener(_onPlaySongListener);
    _musicPlayer.removeOnProgressListener(_onProgressListener);
    _controller.stop();
    super.dispose();
  }

  double _getBarWidth() {
    RenderBox renderBox = _gestureDetectorKey.currentContext.findRenderObject();
    Size size = renderBox.size;
    return size.width;
  }

  void _handleTap(TapUpDetails details) {
    double width = _getBarWidth();
    Offset pos = details.localPosition;
    double percentage = pos.dx / width * 100;
    _musicPlayer.seekPercentage(percentage);
    // _controller..forward(from: pos.dx / width);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: _handleTap,
      behavior: HitTestBehavior.opaque,
      key: _gestureDetectorKey,
      child: Column(
        children: [
          SizedBox(height: 10),
          AnimatedBuilder(
            animation: _animation,
            builder: (BuildContext context, Widget widget) {
              return LinearProgressIndicator(value: _animation.value);
            },
          ),
          SizedBox(height: 10),
        ]
      ),
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final MusicPlayer _musicPlayer;

  _PlayPauseButton(this._musicPlayer);

  @override
  State<StatefulWidget> createState() {
    return _PlayPauseButtonState(_musicPlayer);
  }
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  final MusicPlayer _musicPlayer;
  IconData _playPause;

  void _toggle() {
    bool playing = _musicPlayer.playing;
    if (playing) {
      _playPause = Icons.play_arrow;
      _musicPlayer.pause();
    } else {
      _playPause = Icons.pause;
      _musicPlayer.resume();
    }
    setState(() { }); /* just rebuild the widget */
  }

  _PlayPauseButtonState(this._musicPlayer) {
    _playPause = _musicPlayer.playing ? Icons.pause : Icons.play_arrow;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_playPause),
      tooltip: 'toggle playing state of song',
      onPressed: _toggle,
      iconSize: 50,
    );
  }

}
