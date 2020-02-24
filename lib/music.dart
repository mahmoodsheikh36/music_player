import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:player/database.dart';
import 'package:player/utils.dart';

class Song {
  int _id;
  String _name;
  String _lyrics;
  List<Artist> _artists;
  int _timeAdded;
  Album album;
  int secondsListened;

  File audio;
  File image;
  int duration;

  Song(int id,
      String name,
      String lyrics,
      List<Artist> artists,
      int timeAdded,
      {Album album}) {
    _id = id;
    _name = name;
    _lyrics = lyrics;
    _artists = artists;
    _timeAdded = timeAdded;
    album = album;
  }

  bool get hasAudio => audio != null;
  bool get hasImage => image != null;
  bool get isSingle => album == null;
  bool get hasAlbum => album != null;
  String get name => _name;
  int get id => _id;
  List<Artist> get artists => _artists;
}

abstract class SongList {
  List<Song> get songs;
  File get image;
  String get title;
  String get subtitle;
  bool get hasImage;
}

class Playlist implements SongList {
  File image;
  int _id;
  String _name;
  List<Song> _songs;
  int _timeAdded;

  Playlist(int id, String name, List<Song> songs, int timeAdded, {File image}) {
    _id = id;
    _name = name;
    _songs = songs;
    _timeAdded = timeAdded;
    this.image = image;
  }

  int get id => _id;
  String get name => _name;

  @override
  List<Song> get songs => _songs;

  @override
  String get subtitle => _songs.length.toString() +
      (_songs.length == 1 ? ' song' : ' songs');

  @override
  String get title => _name;

  @override
  bool get hasImage => image != null;
}

class SingleSongsList implements SongList {
  List<Song> _songs;
  File image;

  SingleSongsList(List<Song> singleSongs, File image) {
    _songs = singleSongs;
    this.image = image;
  }

  @override
  bool get hasImage => image != null;

  @override
  List<Song> get songs => _songs;

  @override
  String get subtitle => _songs.length.toString() +
      (_songs.length == 1 ? ' song' : ' songs');

  @override
  String get title => 'Singles';

}

class LikedSongsList implements SongList {
  List<Song> _songs;
  File image;

  LikedSongsList(List<Song> singleSongs, File image) {
    _songs = singleSongs;
    this.image = image;
  }

  @override
  bool get hasImage => image != null;

  @override
  List<Song> get songs => _songs;

  @override
  String get subtitle => _songs.length.toString() +
      (_songs.length == 1 ? ' song' : ' songs');

  @override
  String get title => 'Liked Songs';

}

class Album implements SongList {
  int _id;
  Artist _artist;
  String _name;
  List<Song> _songs;
  int _timeAdded;
  File image;

  Album(
      int id,
      String name,
      Artist artist,
      List<Song> songs,
      int timeAdded,
      {File image}) {
    _id = id;
    _artist = artist;
    _name = name;
    _songs = songs;
    _timeAdded = timeAdded;
    this.image = image;
  }

  int get id => _id;

  String get name => _name;

  @override
  String get title => _name;

  @override
  List<Song> get songs => _songs;

  @override
  String get subtitle => _artist.name;

  @override
  bool get hasImage => image != null;
}

class Artist {
  int id;
  String name;
  int timeAdded;
  List<Album> albums;
  List<Song> singles;

  Artist({this.id, this.name, this.timeAdded, this.albums, this.singles});
}

class MusicLibrary {
  List<Album> albums;
  SingleSongsList singlesList;
  List<Playlist> playlists;
  LikedSongsList likedSongsList;
  List<Artist> artists;
  DbProvider _dbProvider;
  bool _prepared = false;

  MusicLibrary(DbProvider provider) {
    _dbProvider = provider;
  }

  Future prepare() async {
    Completer completer = new Completer();
    _dbProvider.getMusic((albums, playlists, singlesList, likedSongsList, artists) {
      this.albums = albums;
      this.singlesList = singlesList;
      this.playlists = playlists;
      this.likedSongsList = likedSongsList;
      this.artists = artists;
      completer.complete();
      _prepared = true;
    });
    return completer.future;
  }

  Song getSong(int songId) {
    for (final album in albums) {
      for (final song in album.songs) {
        if (song.id == songId)
          return song;
      }
    }
    for (final song in singlesList.songs) {
      if (song.id == songId)
        return song;
    }
    return null;
  }

  List<SongList> get songLists {
    List<SongList> all = List();
    all.add(likedSongsList);
    all.add(singlesList);
    all.addAll(playlists);
    all.addAll(albums);
    return all;
  }

  bool get isPrepared => _prepared;
}
