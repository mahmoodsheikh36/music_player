import 'package:flutter/material.dart';
import 'package:player/dataanalysis.dart';

import 'musicplayer.dart';
import 'song.dart';
import 'database.dart';

class SongListWidget extends StatelessWidget {
  final MusicPlayer _musicPlayer;
  final DbProvider _dbProvider;

  SongListWidget(this._dbProvider, this._musicPlayer);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Song>>(
      future: _dbProvider.openDb().then((val) {
        return _dbProvider.getAllSongsSorted();
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) print(snapshot.error);

        return snapshot.hasData
          ? ListView.builder(
            padding: const EdgeInsets.all(5),
            itemCount: snapshot.data.length,
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () {
                  Song song = snapshot.data[index];
                  getSecondsListenedToSong(_dbProvider, song.id).then((double seconds) {
                    print('seconds listened to song: ' + seconds.toString());
                  });
                  if (_dbProvider.songAudioExistsLocally(song)) {
                    _musicPlayer.play(song);
                  } else {
                    _dbProvider.prepareSongForPlaying(song).then((bool success) {
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
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text(
                          snapshot.data[index].name,
                          style: Theme.of(context).textTheme.title,
                        ),
                        subtitle: Text(
                            snapshot.data[index].artist,
                            style: Theme.of(context).textTheme.subtitle,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          )
          : Center(child: CircularProgressIndicator());
      },
    );
  }
}
