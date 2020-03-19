import 'package:flutter/material.dart';
import 'musicplayer.dart';
import 'database.dart';
import 'datacollection.dart';
import 'root_widget.dart';

void main() {
  runApp(App());
}

Color textColor = Color(0xffddaa44);

class App extends StatefulWidget {
  final MusicPlayer _musicPlayer = new MusicPlayer();
  final DbProvider _dbProvider = new DbProvider();
  MusicMonitor _musicMonitor;

  App() {
    _musicMonitor = MusicMonitor(_dbProvider, _musicPlayer);
  }

  @override
  State<StatefulWidget> createState() => AppState(_dbProvider, _musicPlayer);
}

class AppState extends State<App> {
  MusicPlayer _musicPlayer;
  DbProvider _dbProvider;

  AppState(DbProvider dbProvider, MusicPlayer musicPlayer) {
    _musicPlayer = musicPlayer;
    _dbProvider = dbProvider;
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
        fontFamily: 'Inconsolata',

        // Define the default TextTheme. Use this to specify the default
        // text styling for headlines, titles, bodies of text, and more.
        textTheme: TextTheme(
          headline: TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold, color: textColor),
          body1: TextStyle(fontSize: 14.0, fontFamily: 'Inconsolata', color: textColor),
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
