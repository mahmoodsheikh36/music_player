import 'dart:math';

import 'package:flutter/material.dart';
import 'package:player/dataanalysis.dart';
import 'package:player/root_widget.dart';
import 'package:player/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'musicplayer.dart';
import 'music.dart';
import 'database.dart';

const double _ALBUM_IMAGE_SIZE = 70;
const double _BODY_PADDING = 10;
const double _PADDING_BETWEEN_ELEMENTS = 5;
const double _SONG_STATE_INDICATOR_SIZE = 30;

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
  ScrollController _scrollController;
  final _sharedPreferencesScrollOffsetKey = "library_scroll_offset";

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

  _MusicLibraryWidgetState(
      MusicLibrary library,
      DbProvider provider,
      MusicPlayer player) {
    _library = library;
    _player = player;
    _dbProvider = provider;
    /* we dont want it to be null incase the widget gets built before
       the sharedpreference for the offset value gets loaded
     */
    _getSavedScrollOffset().then((double savedOffset) {
      _scrollController = ScrollController(initialScrollOffset: savedOffset);
      _scrollController.addListener(() {
        print('saving offset');
        _saveScrollOffset(_scrollController.offset);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_library.isPrepared) {
      print('library is prepared, building the widget...');
      return Scrollbar(
        child: ListView.builder(
          key: new PageStorageKey('listview'),
          controller: _scrollController,
          padding: EdgeInsets.all(_PADDING_BETWEEN_ELEMENTS),
          itemCount: _library.songLists.length,
          itemBuilder: (context, index) {
            SongList songList = _library.songLists[index];
            if (!songList.hasImage) {
              _dbProvider.downloadSongListImage(songList).then((shouldRebuild) {
                if (shouldRebuild && this.mounted)
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
      _library.prepare().then((whatever) {
        setState(() { });
      }).catchError((error, stackTrace) {
        print(error);
        print(stackTrace);
      });
      return Center(child: CircularProgressIndicator());
    }
  }

}

class SongListWidget extends StatefulWidget {
  MusicPlayer _player;
  SongList _songList;
  DbProvider _dbProvider;

  SongListWidget(DbProvider provider, MusicPlayer player, SongList songList) {
    _player = player;
    _songList = songList;
    _dbProvider = provider;
  }


  @override
  State<StatefulWidget> createState() => SongListWidgetState(
    _dbProvider,
    _player,
    _songList
  );
}

class SongListWidgetState extends State<SongListWidget> {
  MusicPlayer _player;
  SongList _songList;
  DbProvider _dbProvider;

  SongListWidgetState(DbProvider provider, MusicPlayer player, SongList songList) {
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
                            if (this.mounted)
                              setState(() { });
                          } else {
                            print('wont play song ' + song.name);
                          }
                        });
                      }
                      setState(() { });
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
                            subtitle: Row(
                              children: [
                                SizedBox(
                                  child: _player.currentSong == song ? Icon(Icons.play_arrow, color: Colors.green) :
                                          _dbProvider.isDownloadingSongAudio(song) ? CircularProgressIndicator(strokeWidth: 1,) :
                                            song.hasAudio ? Icon(Icons.done, color: Colors.green) :
                                              Icon(Icons.file_download, color: Colors.red),
                                  width: _SONG_STATE_INDICATOR_SIZE,
                                  height: _SONG_STATE_INDICATOR_SIZE,
                                ),
                                Text(
                                  song.artists[0].name + " " + Utils.secondsToTimeString(song.secondsListened),
                                  style: Theme.of(context).textTheme.subtitle,
                                ),
                              ],
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
                                  if (gotAudio) {
                                    _player.addToQueue(song);
                                    if (this.mounted)
                                      setState(() { });
                                  }
                                });
                              }
                              setState(() { });
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
