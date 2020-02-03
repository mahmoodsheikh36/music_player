import 'package:flutter/material.dart';
import 'package:player/database.dart';
import 'package:player/musicplayer.dart';
import 'package:player/musicplayer_widget.dart';
import 'music.dart';
import 'placeholder_widget.dart';
import 'library_widget.dart';

final BACKGROUND_COLOR = Colors.grey[700];
final BOTTOM_NAVIGATION_BACKGROUND_COLOR = Colors.grey[800];

class Root extends StatefulWidget {
  MusicPlayer _musicPlayer;
  DbProvider _dbProvider;

  Root(this._dbProvider, this._musicPlayer);

  @override
  _RootState createState() { return _RootState(_dbProvider, _musicPlayer); }
}

class _RootState extends State<Root> {
  int _currentIndex = 0;
  MusicPlayer _musicPlayer;
  DbProvider _dbProvider;
  List<Widget> _children = [];

  _RootState(this._dbProvider, this._musicPlayer) {
    _children = [
      SafeArea(
        //child: SongListWidget(_dbProvider, _musicPlayer),
        child: MusicLibraryWidget(MusicLibrary(_dbProvider), _dbProvider, _musicPlayer),
      ),
      SafeArea(
        child: MusicPlayerWidget(_dbProvider, _musicPlayer),
      ),
      PlaceholderWidget(Colors.green)
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      body: _children[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: BOTTOM_NAVIGATION_BACKGROUND_COLOR,
        onTap: onTabTapped,
        currentIndex: _currentIndex,
        items: [
          BottomNavigationBarItem(
            icon: new Icon(Icons.library_music),
            title: new Text('Library'),
          ),
          BottomNavigationBarItem(
            icon: new Icon(Icons.play_circle_outline),
            title: new Text('Player'),
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.data_usage),
              title: Text('Data')
          )
        ],
      ),
    );
  }
  void onTabTapped(int index) {
    setState(() {
     _currentIndex = index;
   });
 }
}
