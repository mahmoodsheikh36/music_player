import 'package:flutter/material.dart';
import 'placeholder_widget.dart';
import 'songlist_widget.dart';

class Home extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _HomeState();
  }
}

class _HomeState extends State<Home> {
  int _currentIndex = 0;
  final List<Widget> _children = [
    SafeArea(
      child: SongListWidget(),
    ),
    PlaceholderWidget(Colors.deepOrange),
    PlaceholderWidget(Colors.green)
  ];
  @override
  Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.grey[700],
        body: _children[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.grey[800],
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
