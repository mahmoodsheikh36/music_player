import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:player/database.dart';

class Song {
  int id;
  String name;
  String lyrics;
  List<Artist> artists;
  int timeAdded;
  Album album;

  /* i should work on initializing and handling these variables properly */
  File audioFile;
  File imageFile;
  double duration;

  Song(this.id,
      this.name,
      this.lyrics,
      this.artists,
      this.timeAdded,
      this.duration,
      {this.album});

  factory Song.fromJson(Map<String, dynamic> json) {
    /* parsing songs form json is only done when fetching data from
       /music/all_songs which doesnt contain audioFilePath, imageFilePath,
       lyrics so there is no need to check if the json map contains those
     */
    int id = json['id'] as int;
    String name = json['name'] as String;
    String lyrics = json['lyrics'] as String;
    Album album = json.containsKey('album') ? Album.fromJson(json['album']) : null;
    List<Artist> artists = json['artists'].map((Map model) => Artist.fromJson(model)).toList();
    int timeAdded = json['time_added'] as int;
    double duration = json['duration'] as double;

    return Song(id, name, lyrics, artists, timeAdded, duration, album: album);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'artists': artists,
      'lyrics': lyrics,
      'album': album,
      'time_added': timeAdded,
      'duration': duration
    };
  }

  static Future<Song> fromDatabaseMap(DbProvider _dbProvider,
                                      Map<String, dynamic> map) async {
    int id = map['id'];
    String name = map['name'];
    String lyrics = map['lyrics'];
    int timeAdded = map['time_added'];
    List<Artist> artists = await _dbProvider.getSongArtists(id);
    double duration = map['duration'];

    // the following line would cause infinite recursion
    // Album album = await _dbProvider.getSongAlbum(id);

    Song song = Song(id, name, lyrics, artists, timeAdded, duration);

    song.audioFile = await _dbProvider.getSongAudio(song.id);
    song.imageFile = await _dbProvider.getSongImage(song.id);

    return song;
  }

  bool hasAudio() {
    return this.audioFile != null;
  }
  bool hasImage() {
    return this.imageFile != null;
  }
}

class Album {
  int id;
  Artist artist;
  String name;
  List<Song> songs;
  int timeAdded;

  Album(this.id, this.name, this.artist, this.songs, this.timeAdded);

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      json['id'] as int,
      json['name'] as String,
      Artist.fromJson(json['artist']),
      jsonDecode(json['songs']).cast<Map<String, dynamic>>().map<Song>((json)
        => Song.fromJson(json)).toList(),
      json['time_added'],
    );
  }

  static Future<Album> fromDatabaseMap(DbProvider _dbProvider, Map<String, dynamic> map) async {
    return Album(
      map['id'],
      map['name'],
      await _dbProvider.getArtist(map['artist_id']),
      await _dbProvider.getAlbumSongs(map['id']),
      map['time_added'],
    );
  }
}

class Artist {
  int id;
  String name;

  Artist(this.id, this.name);

  factory Artist.fromJson(Map<String, dynamic> json) {
    /* parsing songs form json is only done when fetching data from
       /music/all_songs which doesnt contain audioFilePath, imageFilePath,
       lyrics so there is no need to check if the json map contains those
     */
    return Artist(
      json['id'] as int,
      json['name'] as String,
    );
  }

  static Artist fromDatabaseMap(Map<String, dynamic> map) {
    return Artist(map['id'], map['name']);
  }
}
