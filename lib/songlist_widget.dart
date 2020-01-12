import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'song.dart';
import 'musicplayer.dart';
import 'files.dart';
import 'database.dart';

class SongListWidget extends StatelessWidget {
  List<Song> songs;

  SongListWidget({Key key, this.songs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Song>>(
      future: SongProvider.getGlobalInstance().open().then((dynamic val) async {
        return await SongProvider.getGlobalInstance().getAllSongs();
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) print(snapshot.error);

        if (snapshot.hasData) songs = snapshot.data;

        return snapshot.hasData
          ? ListView.builder(
            padding: const EdgeInsets.all(5),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () {
                  songs[index].play();
                  // Files.downloadFile('https://file-examples.com/wp-content/uploads/2017/11/file_example_WAV_1MG.wav', 'test.wav').then((dynamic val) {
                  //   print('playing shit =================================');
                  //   player.playLocal('test.wav');
                  // });
                  // player.playLocal('test.wav');
                  // player.playRemote('https://file-examples.com/wp-content/uploads/2017/11/file_example_WAV_1MG.wav');
                },
                child: Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text(
                          songs[index].name,
                          style: TextStyle(color: Color(0xffbc6f16)),
                        ),
                        subtitle: Text(songs[index].artist),
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
