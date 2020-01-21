import 'package:flutter/material.dart';
import 'package:player/musicplayer.dart';
import 'database.dart';
import 'datacollection.dart';
import 'root_widget.dart';

void main() {
  runApp(App());
}

Color textColor = Color(0xffddaa44);

class App extends StatelessWidget {
  final MusicPlayer _musicPlayer = new MusicPlayer();
  final DbProvider _dbProvider = new DbProvider();
  MusicMonitor _musicMonitor;

  App() {
    _musicMonitor = MusicMonitor(_dbProvider, _musicPlayer);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'music_player',
      theme: ThemeData(
        // Define the default brightness and colors.

        primaryColor: textColor,
        accentColor: textColor,

        // Define the default font family.
        fontFamily: 'Georgia',

        // Define the default TextTheme. Use this to specify the default
        // text styling for headlines, titles, bodies of text, and more.
        textTheme: TextTheme(
          headline: TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold, color: textColor),
          body1: TextStyle(fontSize: 14.0, fontFamily: 'Hind', color: textColor),
          title: TextStyle(fontSize: 17.0, fontStyle: FontStyle.normal, color: textColor),
          subtitle: TextStyle(fontSize: 13.0, fontStyle: FontStyle.normal, color: Colors.black),
        ),
      ),
      home: WillPopScope(
        child: Root(_dbProvider, _musicPlayer),
        onWillPop: () async {
          return false;
        },
      ),
    );
  }
}
