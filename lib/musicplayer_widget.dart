import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:player/database.dart';
import 'package:player/musicplayer.dart';
import 'package:player/music.dart';

const double IMAGE_TO_BODY_WIDTH_PERCENTAGE = 0.65;
const double BODY_PADDING = 20;
const double PLAYBACK_CONTROL_ICON_SIZE = 24;

class MusicPlayerWidget extends StatefulWidget {
  final MusicPlayer _musicPlayer;
  final DbProvider _dbProvider;

  MusicPlayerWidget(this._dbProvider, this._musicPlayer);

  _MusicPlayerWidgetState createState() => _MusicPlayerWidgetState(_dbProvider, _musicPlayer);
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget> {
  final MusicPlayer _musicPlayer;
  final DbProvider _dbProvider;

  void _onPlayListener(Song newSong) {
    setState(() {
    });
  }

  _MusicPlayerWidgetState(this._dbProvider, this._musicPlayer) {
    _musicPlayer.addOnPlayListener(_onPlayListener);
  }

  @override
  void dispose() {
    _musicPlayer.removeOnPlayListener(_onPlayListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _musicPlayer.currentSong != null ?
        Container(
          padding: EdgeInsets.all(BODY_PADDING),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Builder(
                builder: (context) {
                  Song currentSong = _musicPlayer.currentSong;
                  if (currentSong.hasImage) {
                    print('image: ' + currentSong.image.path);
                    print('image: ' + currentSong.image.toString());
                    return Image.file(
                      currentSong.image,
                      width: MediaQuery.of(context).size.width * IMAGE_TO_BODY_WIDTH_PERCENTAGE,
                    );
                  } else {
                    _dbProvider.downloadSongImage(currentSong).then((gotImage) {
                      if (gotImage)
                        setState(() { });
                    });
                    return CircularProgressIndicator();
                  }
                },
              ),
              SizedBox(height: 40),
              Text(
                _musicPlayer.currentSong.name + ' - ' + _musicPlayer.currentSong.artists[0].name,
                style: Theme.of(context).textTheme.title,
              ),
              SizedBox(height: 40),
              _ProgressIndicator(_musicPlayer),
              SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  IconButton(
                    icon: Icon(
                      Icons.favorite,
                      color: Colors.pink,
                      size: PLAYBACK_CONTROL_ICON_SIZE,
                      semanticLabel: 'song liked',
                    ),
                  ),
                  IconButton(
                    tooltip: 'go back',
                    icon: Icon(
                      Icons.skip_previous,
                    ),
                    iconSize: PLAYBACK_CONTROL_ICON_SIZE,
                  ),
                  _PlayPauseButton(_musicPlayer),
                  IconButton(
                    tooltip: 'skip',
                    onPressed: () {
                      _musicPlayer.skip();
                    },
                    icon: Icon(
                      Icons.skip_next,
                    ),
                    iconSize: PLAYBACK_CONTROL_ICON_SIZE,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.loop,
                      color: _musicPlayer.playbackMode == PlaybackMode.LOOP ?
                        Colors.grey : Colors.pink,
                      size: PLAYBACK_CONTROL_ICON_SIZE,
                      semanticLabel: 'switch between playback modes',
                    ),
                    onPressed: () {
                      _musicPlayer.changePlaybackMode();
                      setState(() { });
                    },
                  )
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
    _controller.duration = new Duration(milliseconds: (newSong.duration * 1000).toInt());
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
      duration: Duration(milliseconds: (_musicPlayer.currentSong.duration * 1000).toInt()),
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
