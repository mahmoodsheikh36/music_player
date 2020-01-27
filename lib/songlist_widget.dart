import 'package:flutter/material.dart';
import 'package:player/dataanalysis.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'musicplayer.dart';
import 'song.dart';
import 'database.dart';

class SongListWidget extends StatelessWidget {
  final MusicPlayer _musicPlayer;
  final DbProvider _dbProvider;
  ScrollController _scrollController;
  final _sharedPreferencesScrollOffsetKey = "songListScrollOffset";

  void _saveScrollOffset(double offset) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_sharedPreferencesScrollOffsetKey, offset);
  }
  Future<double> _getSavedScrollOffset() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_sharedPreferencesScrollOffsetKey))
      return prefs.getDouble(_sharedPreferencesScrollOffsetKey);
    return 0;
  }

  SongListWidget(this._dbProvider, this._musicPlayer) {
  }

  @override
  Widget build(BuildContext context) {
    _getSavedScrollOffset().then((double savedOffset) {
      _scrollController = ScrollController(initialScrollOffset: savedOffset);
      _scrollController.addListener(() {
        _saveScrollOffset(_scrollController.offset);
      });
    });
    return FutureBuilder<List<Song>>(
      future: _dbProvider.openDb().then((val) {
        return _dbProvider.getAllSongsSorted();
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) print(snapshot.error);

        if (snapshot.hasData) {
          return Scrollbar(
          child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(5),
              itemCount: snapshot.data.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    Song song = snapshot.data[index];
                    getSecondsListenedToSong(_dbProvider, song.id).then((
                        double seconds) {
                      print('seconds listened to song: ' + seconds.toString());
                    });
                    if (_dbProvider.songAudioExistsLocally(song)) {
                      _musicPlayer.play(song);
                    } else {
                      _dbProvider.prepareSongForPlaying(song, (success) {
                        if (success) {
                          _musicPlayer.addToQueue(song);
                          print('added \'' + song.name + '\' to queue');
                        } else {
                          print('error preparing song \'' + song.name +
                              '\' for playing');
                        }
                      });
                    }
                    // _dbProvider.prepareSongForPlayerPreview(song);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ListTile(
                          title: Text(
                            snapshot.data[index].name,
                            style: Theme
                                .of(context)
                                .textTheme
                                .title,
                          ),
                          subtitle: Text(
                            snapshot.data[index].artist,
                            style: Theme
                                .of(context)
                                .textTheme
                                .subtitle,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'add to queue',
                        icon: Icon(
                          Icons.add_to_queue,
                        ),
                        onPressed: () {
                          Song song = snapshot.data[index];
                          if (_dbProvider.songAudioExistsLocally(song)) {
                            _musicPlayer.addToQueue(song);
                            print('added \'' + song.name + '\' to queue');
                          } else {
                            _dbProvider.prepareSongForPlaying(song, (success) {
                              if (success) {
                                _musicPlayer.addToQueue(song);
                                print('added \'' + song.name + '\' to queue');
                              } else {
                                print('error preparing song \'' + song.name +
                                  '\' for playing');
                              }
                            });
                          }
                        }
                      ),
                    ],
                  ),
                );
              }
            ),
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      );
    }
  }
