import 'dart:convert';
import 'dart:async';
import 'dart:core';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'files.dart';
import 'music.dart';
import 'datacollection.dart';
import 'functionqueue.dart';

const BACKEND = "http://10.0.0.15";
const USERNAME = 'mahmooz';

const _AUDIO_FOLDER  = 'audio';
const _IMAGE_FOLDER  = 'image';
const _DOWNLOAD_TIMEOUT = 200;

class DbProvider {
  Database db;
  bool _isNewDatabase = true;
  List<Function> _onNewSongListeners = List<Function>();
  FunctionQueue _httpRequestFunctionQueue = FunctionQueue();

  static Future<Map<String, dynamic>> _fetchMetadata() async {
    try {
      final response = await http.get(BACKEND + '/music/metadata');
      return jsonDecode(response.body);
    } on SocketException catch (_) {
      print('no internet connection');
      return null;
    }
  }

  static Future _handleMetadata(Map<String, dynamic> metadata) async {
    if (metadata == null)
      return;
    print('number of albums: ' + metadata['albums'].length.toString());
    print('number of artists: ' + metadata['artists'].length.toString());
  }

  static List<Song> _parseSongsMetadata(String responseBody) {
    final parsed = jsonDecode(responseBody).cast<Map<String, dynamic>>();
    return parsed.map<Song>((json) => Song.fromJson(json)).toList();
  }

  Future onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE songs (
        id int,
        name TEXT NOT NULL,
        lyrics TEXT,
        time_added int
      );
      ''');

    await db.execute('''
      CREATE TABLE song_artists (
        id int,
        artist_id int,
        song_id int,
        FOREIGN KEY (artist_id) REFERENCES artists (id),
        FOREIGN KEY (song_id) REFERENCES songs (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE album_songs (
        id int,
        song_id int,
        album_id int,
        FOREIGN KEY (song_id) REFERENCES songs (id),
        FOREIGN KEY (album_id) REFERENCES albums (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE albums (
        id int,
        name TEXT NOT NULL,
        artist_id int,
        time_added int,
        FOREIGN KEY (artist_id) REFERENCES artists (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE single_songs (
        id int,
        song_id int,
        FOREIGN KEY (song_id) REFERENCES songs (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE song_audio (
        id int,
        song_id int,
        file_path TEXT NOT NULL,
        FOREIGN KEY (song_id) REFERENCES songs (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE song_images (
        id int,
        song_id int,
        file_path TEXT NOT NULL,
        FOREIGN KEY (song_id) REFERENCES songs (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE playbacks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id INTEGER,
        start_time int,
        end_time int,
        FOREIGN KEY (song_id) REFERENCES songs (id)
      );
      '''
    );
    await db.execute('''
      CREATE TABLE pauses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playback_id INTEGER,
        time int,
        FOREIGN KEY(playback_id) REFERENCES playbacks(id)
      );
      '''
    );
    await db.execute('''
      CREATE TABLE resumes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playback_id INTEGER,
        time int,
        FOREIGN KEY(playback_id) REFERENCES playbacks(id)
      );
      '''
    );
    await db.execute('''
      CREATE TABLE seeks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playback_id INTEGER,
        time int,
        position REAL,
        FOREIGN KEY(playback_id) REFERENCES playbacks(id)
      );
      '''
    );
  }

  Future openDb() async {
    if (db != null && db.isOpen)
      return;
    final DATABASE_PATH = await Files.getAbsoluteFilePath('music.db');
    if (await databaseExists(DATABASE_PATH)) {
      _isNewDatabase = false;
    }
    db = await openDatabase(
        DATABASE_PATH,
        version: 11,
        onCreate: this.onCreate
    );
    //if (_isNewDatabase) {
      Map<String, dynamic> metadata = await _fetchMetadata();
      _handleMetadata(metadata);
      print(metadata['artists']);
    //} else {
      print('checking for changes in remote library...');
    //}
  }

  Future insertPlayback(Playback playback) async {
    await db.insert('playbacks', playback.toMap());
  }

  Future<int> _getLastAutoId(String tableName) async {
    List<Map<String, dynamic>> maps = (await db.query(
      'sqlite_sequence',
      columns: [
        'seq',
      ],
      where: 'name = ?',
      whereArgs: [tableName],
    ));
    if (maps.length == 0)
      return null;
    return maps[0]['seq'];
  }

  Future<Playback> getLastPlayback() async {
    int lastPlaybackId = await _getLastAutoId('playbacks');
    return Playback.fromMap((await db.query(
      'playbacks',
      columns: null,
      where: 'id = ?',
      whereArgs: [lastPlaybackId],
    ))[0]);
  }

  Future updatePlaybackColumns(Playback playback,
      Map<String, dynamic> values) async {
    return await db.update('playbacks', values,
        where: 'id = ?', whereArgs: [playback.id]);
  }

  void _downloadSongAudio(Song song, Function callback) {
    String localPath = _AUDIO_FOLDER + '/' + song.id.toString() + '.audio';
    if (song.hasAudio()) {
      callback(true);
      return;
    }
    if (_httpRequestFunctionQueue.hasEntryWithId(localPath)) {
      callback(false);
      return;
    }
    _httpRequestFunctionQueue.add((functionQueueCallback) async {
      final response = await http.post(
          'https://mahmoodsheikh.com/music/audio?song_id=' + song.id.toString(),
          body: {
            'username': USERNAME
          }
      ).timeout(Duration(seconds: _DOWNLOAD_TIMEOUT), onTimeout: () {
        print('timed out downloading audio for \'' + song.name + '\'');
        return null;
      });
      if (response != null) {
        await Files.saveHttpResponse(response, localPath);
        song.audioFile = File(await Files.getAbsoluteFilePath(localPath));
        /*
        this.updateSongColumns(song,
            <String, String>{
              'audioFilePath': song.audioFilePath
            }).then((whatever) {
        });
         */
        callback(true);
        print('downloaded audio for song ' + song.name);
      } else {
        callback(false);
      }
      functionQueueCallback();
    }, id: localPath);
  }

  void _downloadSongImage(Song song, Function callback) {
    String localPath = _IMAGE_FOLDER + "/" + song.id.toString() + '.img';
    if (song.hasImage()) {
      callback(true);
      return;
    }
    if (_httpRequestFunctionQueue.hasEntryWithId(localPath)) {
      print('rejecting image download request');
      callback(false);
      return;
    }
    print('downloading image...');
    _httpRequestFunctionQueue.add((functionQueueCallback) async {
      final response = await http.post(
          'https://mahmoodsheikh.com/music/image?song_id=' + song.id.toString(),
          body: {
            'username': USERNAME
          }
      ).timeout(Duration(seconds: _DOWNLOAD_TIMEOUT), onTimeout: () {
        print('timed out downloading image for \'' + song.name + '\'');
        return null;
      });
      if (response != null) {
        await Files.saveHttpResponse(response, localPath);
        song.imageFile = File(await Files.getAbsoluteFilePath(localPath));
        /*
        this.updateSongColumns(song,
            <String, String>{'imageFilePath': song.imageFilePath});
         */
        callback(true);
        print('downloaded image for song ' + song.name);
      } else {
        callback(false);
      }
      functionQueueCallback();
    }, id: localPath);
  }

  void prepareSongForPlaying(Song song, Function callback) {
    print('preparing song \'' + song.name + '\' for playing');
    _downloadSongAudio(song, (success) {
      callback(success);
    });
  }

  void prepareSongForPlayerPreview(Song song, Function callback) {
    print('preparing song \'' + song.name + '\' for player preview');
    _downloadSongImage(song, (success) {
      callback(success);
    });
  }

  void addOnNewSongListener(Function listener) {
    this._onNewSongListeners.add(listener);
  }

  void _notifyOnNewSongListeners(Song song) {
    for (Function listener in _onNewSongListeners) {
      listener(song);
    }
  }

  Future<List<Song>> _fetchNewSongsMetadata() async {
    List<Map<String, dynamic>> maps = await db.query(
      'songs',
      columns: [
        'id',
      ],
      orderBy: 'id DESC',
      limit: 1,
    );
    int lastSongId;
    if (maps.length == 0)
      lastSongId = -1; /* -1 will result in all songs being refetched */
    else
      lastSongId = maps[0]['id'];

    print('lastSongId: ' + lastSongId.toString());
    final response =
    await http.post(
        'https://mahmoodsheikh.com/music/songs?after_id=' +
            lastSongId.toString(),
        body: {
          'username': USERNAME
        }
    );
    return compute(_parseSongsMetadata, response.body);
  }

  Future insertPause(int playbackId, int time) async {
    await db.insert('pauses', <String, dynamic>{
      'playback_id': playbackId,
      'time': time
    });
  }

  Future insertResume(int playbackId, int time) async {
    await db.insert('resumes', <String, dynamic>{
      'playback_id': playbackId,
      'time': time
    });
  }

  Future insertSeek(int playbackId, double position, int time) async {
    await db.insert('seeks', <String, dynamic>{
      'playback_id': playbackId,
      'position': position,
      'time': time
    });
  }

  Future<List<Playback>> getPlaybacksForSong(int songId) async {
    List<Map> maps = await db.query(
        'playbacks',
        columns: null,
        where: 'song_id = ?',
        whereArgs: [songId]
    );
    List<Playback> playbacks = List<Playback>();
    for (Map map in maps) {
      playbacks.add(Playback.fromMap(map));
    }
    return playbacks;
  }

  Future<List<int>> getPausesForPlayback(int playbackId) async {
    List<Map> maps = await db.query(
        'pauses',
        columns: ['time'],
        where: 'playback_id = ?',
        whereArgs: [playbackId]
    );
    List<int> pauseTimestamps = List<int>();
    for (Map map in maps) {
      pauseTimestamps.add(map['time']);
    }
    return pauseTimestamps;
  }

  Future<File> getSongImage(int songId) async {
    List<Map> maps = await db.query(
        'song_images',
        columns: ['file_path'],
        where: 'song_id = ?',
        whereArgs: [songId]
    );
    if (!maps[0].containsKey('file_path'))
      return null;
    return File(await Files.getAbsoluteFilePath(maps[0]['file_path']));
  }

  Future<File> getSongAudio(int songId) async {
    List<Map> maps = await db.query(
        'song_audio',
        columns: ['file_path'],
        where: 'song_id = ?',
        whereArgs: [songId]
    );
    if (!maps[0].containsKey('file_path'))
      return null;
    return File(await Files.getAbsoluteFilePath(maps[0]['file_path']));
  }

  Future addSongImage(int imageId, int songId, String imageFilePath) async {
    await db.insert('song_images', <String, dynamic>{
      'id': imageId,
      'song_id': songId,
      'file_path': imageFilePath,
    });
  }

  Future addSongAudio(int imageId, int songId, String audioFilePath) async {
    await db.insert('song_images', <String, dynamic>{
      'id': imageId,
      'song_id': songId,
      'file_path': audioFilePath,
    });
  }

  Future<Artist> getArtist(int artistId) async {
    List<Map> maps = await db.query(
      'artists',
      columns: null,
      where: 'id = ?',
      whereArgs: [artistId]
    );
    if (maps.length == 0)
      return null;
    return Artist.fromDatabaseMap(maps[0]);
  }

  Future<List<Artist>> getSongArtists(int songId) async {
    List<Map> maps = await db.query(
      'song_artists',
      columns: [
        'artist_id'
      ],
      where: 'song_id = ?',
      whereArgs: [songId]
    );
    List<Artist> artists = List<Artist>();
    for (Map map in maps) {
      int artistId = map['artist_id'];
      artists.add(await getArtist(artistId));
    }
    return artists;
  }

  Future<Album> getSongAlbum(int songId) async {
    List<Map> maps = await db.query(
      'albums',
      columns: null,
      where: 'song_id = ?',
      whereArgs: [songId]
    );
    if (maps.length == 0)
      return null;
    return Album.fromDatabaseMap(this, maps[0]);
  }

  Future<List<Song>> getAlbumSongs(int albumId) async {
    List<Map> maps = await db.query(
      'album_songs',
      columns: [
        'song_id'
      ],
      where: 'album_id = ?',
      whereArgs: [albumId]
    );
    List<Song> songs = List<Song>();
    for (Map map in maps) {
      int songId = map['song_id'];
      songs.add(await getSong(songId));
    }
    return songs;
  }

  Future<Song> getSong(int songId) async {
    List<Map> maps = await db.query(
        'songs',
        columns: null,
        where: 'song_id = ?',
        whereArgs: [songId]
    );
    return await Song.fromDatabaseMap(this, maps[0]);
  }

  Future _addSingleSongsRow(int id, int songId) async {
    await db.insert('single_songs', <String, dynamic>{
      'id': id,
      'song_id': songId,
    });
  }

  Future _addAlbumSongsRow(int id, int songId, int albumId) async {
    await db.insert('album_songs', <String, dynamic>{
      'id': id,
      'song_id': songId,
      'album_id': albumId,
    });
  }

  Future _addSongsRow(int id, String name, String lyrics, int timeAdded) async {
    await db.insert('songs', <String, dynamic>{
      'id': id,
      'name': name,
      'lyrics': lyrics,
      'time_added': timeAdded,
    });
  }
}
