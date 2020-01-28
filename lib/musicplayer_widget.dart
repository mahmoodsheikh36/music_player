import 'dart:io';
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:player/database.dart';
import 'package:player/musicplayer.dart';
import 'package:player/song.dart';

final _DISABLED_PLAYBACK_BUTTON_COLOR = Colors.grey[600];
final _ENABLED_PLAYBACK_BUTTON_COLOR = Colors.black;

class MusicPlayerWidget extends StatefulWidget {
  final MusicPlayer _musicPlayer;
  final DbProvider _dbProvider;

  MusicPlayerWidget(this._dbProvider, this._musicPlayer);

  _MusicPlayerWidgetState createState() => _MusicPlayerWidgetState(_dbProvider, _musicPlayer);
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget> {
  final MusicPlayer _musicPlayer;
  final DbProvider _dbProvider;

  bool _isPlayNextButtonEnabled;
  bool _isPlayPrevButtonEnabled;

  void _resetPlaybackButtons() {
    if (_musicPlayer.hasNextSong() && _isPlayNextButtonEnabled)
      return;
    _isPlayNextButtonEnabled = _musicPlayer.hasNextSong();
  }

  void _onPlayListener(Song newSong) {
    _resetPlaybackButtons();
    setState(() {
    });
  }

  void _onAddToQueueListener() {
    _resetPlaybackButtons();
    setState(() {
    });
  }

  _MusicPlayerWidgetState(this._dbProvider, this._musicPlayer) {
    _musicPlayer.addOnPlayListener(_onPlayListener);
    _musicPlayer.addOnAddToQueueListener(_onAddToQueueListener);
    _isPlayNextButtonEnabled = _musicPlayer.hasNextSong();
    _isPlayPrevButtonEnabled = false;
  }

  @override
  void dispose() {
    _musicPlayer.removeOnPlayListener(_onPlayListener);
    _musicPlayer.removeOnAddToQueueListener(_onAddToQueueListener);
    super.dispose();
  }

  Future<File> _getSongImageFile(Song song) async {
    _dbProvider.prepareSongForPlayerPreview(song, (success) {
      if (success && this.mounted) {
        setState(() {
        });
      }
    });
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
              builder: (context, snapshot) {
                Song currentSong = _musicPlayer.currentSong;
                if (_dbProvider.songImageExistsLocally(currentSong)) {
                  return FutureBuilder<File>(
                    future: _dbProvider.getSongImageFile(currentSong).then((imageFile) {
                      return imageFile;
                    }),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Image.file(
                          snapshot.data,
                          width: MediaQuery.of(context).size.width * 0.65,
                        );
                      } else {
                        return CircularProgressIndicator();
                      }
                    }
                  );
                } else {
                  _getSongImageFile(currentSong);
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
                  icon: Icon(
                    Icons.skip_previous,
                    color: _isPlayPrevButtonEnabled ?
                    _ENABLED_PLAYBACK_BUTTON_COLOR :
                    _DISABLED_PLAYBACK_BUTTON_COLOR,
                  ),
                  iconSize: 35,
                ),
                _PlayPauseButton(_musicPlayer),
                IconButton(
                  tooltip: 'skip',
                  onPressed: () {
                    if (_isPlayNextButtonEnabled) {
                      _musicPlayer.skip();
                    }
                  },
                  icon: Icon(
                    Icons.skip_next,
                    color: _isPlayNextButtonEnabled ?
                    _ENABLED_PLAYBACK_BUTTON_COLOR :
                    _DISABLED_PLAYBACK_BUTTON_COLOR,
                  ),
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

  Future _onPlaySongListener(Song newSong) async {
    _controller.duration = new Duration(seconds: newSong.duration);
    // _controller..forward(from: 0);
  }

  void _onPositionChangeListener(Duration duration) {
    _controller.value = (duration.inMilliseconds / 1000)
                        / _musicPlayer.currentSong.duration;
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(seconds: _musicPlayer.currentSong.duration),
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );//..forward(from: _musicPlayer.progress / _musicPlayer.currentSong.duration);

    /* invoke the on position change manually because musicPlayer wont do it */
    _musicPlayer.getCurrentPosition().then((int milliseconds) {
      _onPositionChangeListener(Duration(milliseconds: milliseconds));
    });

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    )..addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.dismissed)
        _controller.forward();
      else if (status == AnimationStatus.completed)
        _controller.reset();
    });

    _musicPlayer.addOnPlayListener(_onPlaySongListener);
    _musicPlayer.addOnPositionChangeListener(_onPositionChangeListener);
  }

  @override
  void dispose() {
    _musicPlayer.removeOnPlayListener(_onPlaySongListener);
    _musicPlayer.removeOnPositionChangeListener(_onPositionChangeListener);
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
    bool playing = _musicPlayer.isPlaying();
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
    _playPause = _musicPlayer.isPlaying() ? Icons.pause : Icons.play_arrow;
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
