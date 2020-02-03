import 'package:flutter/material.dart';
import 'package:player/dataanalysis.dart';
import 'package:player/root_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'musicplayer.dart';
import 'music.dart';
import 'database.dart';
import 'musicplayer_widget.dart';

const double _ALBUM_IMAGE_SIZE = 70;
const double _BODY_PADDING = 10;
const double _PADDING_BETWEEN_ELEMENTS = 5;

class MusicLibraryWidget extends StatefulWidget {
  MusicLibrary _library;
  MusicPlayer _player;
  DbProvider _dbProvider;

  MusicLibraryWidget(
      MusicLibrary library,
      DbProvider provider,
      MusicPlayer player) {
    _library = library;
    _player = player;
    _dbProvider = provider;
  }

  @override
  State<StatefulWidget> createState() {
    return _MusicLibraryWidgetState(_library, _dbProvider, _player);
  }
}

class _MusicLibraryWidgetState extends State<MusicLibraryWidget> {
  MusicLibrary _library;
  MusicPlayer _player;
  DbProvider _dbProvider;

  _MusicLibraryWidgetState(
      MusicLibrary library,
      DbProvider provider,
      MusicPlayer player) {
    _library = library;
    _player = player;
    _dbProvider = provider;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _library.prepare().catchError((error, stackTrace) {
        print(error);
        print(stackTrace);
      }),
      builder: (context, snapshot) {
        if (_library.isPrepared) {
          print('library is prepared, building the widget...');
          return Scrollbar(
            child: ListView.builder(
              padding: EdgeInsets.all(_PADDING_BETWEEN_ELEMENTS),
              itemCount: _library.songLists.length,
              itemBuilder: (context, index) {
                SongList songList = _library.songLists[index];
                if (!songList.hasImage) {
                  _dbProvider.downloadSongListImage(songList).then((shouldRebuild) {
                    if (shouldRebuild)
                      setState(() {});
                  });
                }
                return InkWell(
                  onTap: () {
                    print('tap tap tap!!! on songList ' + songList.title);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SongListWidget(_dbProvider, _player, songList),
                      ),
                    );
                  },
                  child: Row(
                    children: <Widget>[
                      songList.hasImage ?
                        Image.file(
                          songList.image,
                          width: _ALBUM_IMAGE_SIZE,
                          height: _ALBUM_IMAGE_SIZE,
                        ) :
                        CircularProgressIndicator(),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.all(_PADDING_BETWEEN_ELEMENTS),
                          title: Text(
                            songList.title,
                            style: Theme.of(context).textTheme.title,
                          ),
                          subtitle: Text(
                            songList.subtitle,
                            style: Theme.of(context).textTheme.subtitle,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
          ),
          );
        } else {
          print('library is not prepared');
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }

}

class SongListWidget extends StatelessWidget {
  MusicPlayer _player;
  SongList _songList;
  DbProvider _dbProvider;
  /*
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
   */

  SongListWidget(DbProvider provider, MusicPlayer player, SongList songList) {
    _player = player;
    _songList = songList;
    _dbProvider = provider;
  }

  @override
  Widget build(BuildContext context) {
    /*
    _getSavedScrollOffset().then((double savedOffset) {
      _scrollController = ScrollController(initialScrollOffset: savedOffset);
      _scrollController.addListener(() {
        _saveScrollOffset(_scrollController.offset);
      });
    });
     */
    return SafeArea(
      child: Scaffold(
        backgroundColor: BACKGROUND_COLOR,
        body: Scrollbar(
          child: ListView.builder(
              padding: const EdgeInsets.all(_BODY_PADDING),
              //controller: _scrollController,
              itemCount: _songList.songs.length + 1,
              itemBuilder: (context, index) {
                /* first element will be image */
                if (index == 0) {
                  return Image.file(
                    _songList.image,
                  );
                } else {
                  int songIndex = index - 1;
                  Song song = _songList.songs[songIndex];
                  return InkWell(
                    onTap: () {
                      getSecondsListenedToSong(_dbProvider, song.id).then((
                          double seconds) {
                        print('seconds listened to song: ' + seconds.toString());
                      });

                      if (song.hasAudio) {
                        _player.play(_songList, songIndex);
                      } else {
                        _dbProvider.downloadSongAudio(song).then((gotAudio) {
                          if (gotAudio) {
                            print('playing song ' + song.name);
                            _player.play(_songList, songIndex);
                          } else {
                            print('wont play song ' + song.name);
                          }
                        });
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: ListTile(
                            title: Text(
                              song.name,
                              style: Theme.of(context).textTheme.title,
                            ),
                            subtitle: Text(
                              song.artists[0].name,
                              style: Theme.of(context).textTheme.subtitle,
                            ),
                          ),
                        ),
                        IconButton(
                            tooltip: 'add to queue',
                            icon: Icon(
                              Icons.add_to_queue,
                            ),
                            onPressed: () {
                              if (song.hasAudio) {
                                _player.addToQueue(song);
                              } else {
                                _dbProvider.downloadSongAudio(song).then((
                                    gotAudio) {
                                  if (gotAudio)
                                    _player.addToQueue(song);
                                });
                              }
                            }
                        ),
                      ],
                    ),
                  );
                }
              }
          ),
        ),
      ),
    );
  }
}
