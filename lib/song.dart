import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:player/musicplayer.dart';
import 'dart:async';
import 'dart:convert';
import 'files.dart';

http.Client httpClient = http.Client();

Future<List<Song>> fetchSongs() async {
  final response =
      await httpClient.get('https://mahmoodsheikh.com/music/all_songs');

  // Use the compute function to run parseSongs in a separate isolate.
  return compute(parseSongs, response.body);
}

// A function that converts a response body into a List<Song>.
List<Song> parseSongs(String responseBody) {
  final parsed = jsonDecode(responseBody).cast<Map<String, dynamic>>();

  return parsed.map<Song>((json) => Song.fromJson(json)).toList();
}

class Song {
  int id;
  String name;
  String artist;
  String album;
  String audioFilePath;
  String imageFilePath;
  String lyrics;


  Song({this.id, this.name, this.artist, this.album});

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as int,
      name: json['name'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'album': album,
      'artist': artist,
      'audioFilePath': audioFilePath,
      'imageFilePath': imageFilePath,
      'lyrics': lyrics
    };
  }

  static Song fromMap(Map<String, dynamic> map) {
    Song song = new Song(
      id: map['id'],
      name: map['name'],
      artist: map['artist'],
      album: map['album'],
    );
    if (map.containsKey('audioFilePath'))
      song.audioFilePath = map['audioFilePath'];
    if (map.containsKey('lyrics'))
      song.lyrics = map['lyrics'];
    if (map.containsKey('imageFilePath'))
      song.imageFilePath = map['imageFilePath'];
    return song;
  }

  bool audioExistsLocally() {
    return audioFilePath != null;
  }
  bool imageExistsLocally() {
    return imageFilePath != null;
  }
  bool lyricsExistsLocally() {
    return lyrics != null;
  }

  Future downloadAudioFile() async {
    String localPath = 'audio/' + this.id.toString() + '.audio';
    await Files.downloadFile('https://mahmoodsheikh.com/music/get_song_audio_file/' + this.id.toString(), localPath).then((val) {
      this.audioFilePath = localPath;
    });
  }

  Future downloadImageFile() async {
    String localPath = 'image/' + this.id.toString() + '.img';
    await Files.downloadFile('https://mahmoodsheikh.com/music/get_song_image_file/' + this.id.toString(), localPath).then((val) {
      this.imageFilePath = localPath;
    });
  }

  Future downloadLyrics() async {
  }

  void play() {
    MusicPlayer.getGlobalInstance().playSong(this);
  }

}
