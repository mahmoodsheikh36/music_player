import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:player/database.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'files.dart';

class Song {
  int id;
  String name;
  String artist;
  String album;
  String audioFilePath;
  String imageFilePath;
  String lyrics;
  double secondsListened;
  int duration;

  Song({this.id, this.name, this.artist, this.album, this.duration, this.secondsListened});

  factory Song.fromJson(Map<String, dynamic> json) {
    /* parsing songs form json is only done when fetching data from
       /music/all_songs which doesnt contain audioFilePath, imageFilePath,
       lyrics so there is no need to check if the json map contains those
     */
    return Song(
      id: json['id'] as int,
      name: json['name'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String,
      duration: json['duration'] as int,
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
      'lyrics': lyrics,
      'duration': duration,
      'secondsListened': secondsListened,
    };
  }

  static Song fromMap(Map<String, dynamic> map) {
    Song song = Song(
      id: map['id'],
      name: map['name'],
      artist: map['artist'],
      album: map['album'],
      duration: map['duration'],
      secondsListened: map['secondsListened'],
    );
    if (map.containsKey('audioFilePath'))
      song.audioFilePath = map['audioFilePath'];
    if (map.containsKey('lyrics'))
      song.lyrics = map['lyrics'];
    if (map.containsKey('imageFilePath'))
      song.imageFilePath = map['imageFilePath'];
    return song;
  }

}
