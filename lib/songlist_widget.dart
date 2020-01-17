import 'package:flutter/material.dart';

import 'musicplayer.dart';
import 'song.dart';
import 'database.dart';

class SongListWidget extends StatelessWidget {
  final MusicPlayer _musicPlayer;
  final SongProvider _songProvider;

  SongListWidget(this._songProvider, this._musicPlayer);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Song>>(
      future: _songProvider.open().then((val) {
        return _songProvider.getAllSongs();
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
                  if (_songProvider.songAudioExistsLocally(song)) {
                    _musicPlayer.play(song);
                  } else {
                    _songProvider.prepareSongForPlaying(song).then((bool success) {
                        if (success) {
                          _musicPlayer.addToQueue(song);
                          print('added \'' + song.name + '\' to queue');
                        } else {
                            print('error preparing song \'' + song.name +
                            '\' for playing');
                        }
                    });
                  }
                  // _songProvider.prepareSongForPlayerPreview(song);
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
