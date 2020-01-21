import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'files.dart';
import 'song.dart';
import 'datacollection.dart';

const _AUDIO_FOLDER  = 'audio';
const _IMAGE_FOLDER  = 'image';

class DbProvider {
  Database db;
  bool _isNewDatabase = true;
  List<Function> _onNewSongListeners = List<Function>();

  static Future<List<Song>> _fetchAllSongsMetadata() async {
    final response = await http.get('https://mahmoodsheikh.com/music/songs');
    return compute(_parseSongsMetadata, response.body);
  }
  static List<Song> _parseSongsMetadata(String responseBody) {
    final parsed = jsonDecode(responseBody).cast<Map<String, dynamic>>();
    return parsed.map<Song>((json) => Song.fromJson(json)).toList();
  }

  Future onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE songs (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT NOT NULL,
        audioFilePath TEXT,
        imageFilePath TEXT,
        lyrics TEXT,
        duration int,
        secondsListened REAL,
        dateAdded TEXT NOT NULL
      );
      '''
    );
    await db.execute('''
      CREATE TABLE playbacks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        songId INTEGER,
        startTimestamp int,
        endTimestamp int,
        FOREIGN KEY (songId) REFERENCES songs (id)
      );
      '''
    );
    await db.execute('''
      CREATE TABLE pauses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playbackId INTEGER,
        timestamp int,
        FOREIGN KEY(playbackId) REFERENCES playbacks(id)
      );
      '''
    );
    await db.execute('''
      CREATE TABLE resumes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pauseId INTEGER,
        timestamp int,
        FOREIGN KEY(pauseId) REFERENCES pauses(id)
      );
      '''
    );
    await db.execute('''
      CREATE TABLE seeks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playbackId INTEGER,
        timestamp int,
        position REAL,
        FOREIGN KEY(playbackId) REFERENCES playbacks(id)
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
    if (_isNewDatabase) {
      List<Song> songs = await _fetchAllSongsMetadata();
      for (Song song in songs) {
        print('inserting song: ' + song.name);
        await insertSong(song);
      }
    } else {
      print('checking for new songs in remote library..');
      _fetchNewSongsMetadata().then((List<Song> newSongs) {
        print('new songs count: ' + newSongs.length.toString());
        for (Song song in newSongs) {
          print('new song ' + song.name);
          insertSong(song).then((val) {
            _notifyOnNewSongListeners(song);
          });
        }
      });
    }
  }

  Future insertSong(Song song) async {
    await db.insert('songs', song.toMap());
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

  Future<Song> getSong(int id) async {
    List<Map> maps = (await db.query(
      'songs',
      columns: null,
      where: 'id = ?',
      whereArgs: [id]
    ));
    if (maps.length > 0)
      return Song.fromMap(maps.first);
    return null;
  }

  Future<List<Song>> getAllSongs() async {
    List<Map> maps = (await db.query(
      'songs',
      columns: null,
    ));
    List<Song> songs = List<Song>();
    for (Map map in maps) {
      songs.add(Song.fromMap(map));
    }
    return songs;
  }

  Future<List<Song>> getAllSongsSorted() async {
    List<Song> songList = await getAllSongs();
    for (int i = 0; i < songList.length; ++i) {
      for (int j = i; j < songList.length; ++j) {
        if (songList[i].dateAdded.isBefore(songList[j].dateAdded)) {
          Song tmp = songList[i];
          songList[i] = songList[j];
          songList[j] = tmp;
        }
      }
    }
    return songList;
  }

  /* shouldnt update all values at once unless necessary */
  Future<void> updateSong(Song song) async {
    return await db.update('songs', song.toMap(),
      where: 'id = ?', whereArgs: [song.id]);
  }
  /* use this to update specific values */
  Future<void> updateSongColumns(Song song, Map<String, dynamic> values) async {
    return await db.update('songs', values,
      where: 'id = ?', whereArgs: [song.id]);
  }

  Future<void> updatePlayback(Playback playback) async {
    return await db.update('playbacks', playback.toMap(),
      where: 'id = ?', whereArgs: [playback.id]);
  }
  Future updatePlaybackColumns(Playback playback, Map<String, dynamic> values) async {
    return await db.update('playbacks', values,
      where: 'id = ?', whereArgs: [playback.id]);
  }

  Future<bool> _downloadSongAudio(Song song) async {
    String localPath = _AUDIO_FOLDER + '/' + song.id.toString() + '.audio';
    if (song.audioFilePath == localPath)
      return true;
    bool success = false;
    await Files.downloadFile('https://mahmoodsheikh.com/music/get_song_audio_file/' + song.id.toString(), localPath).then((val) {
      song.audioFilePath = localPath;
      success = true;
    }).catchError((error) { print(error); });
    return success;
  }

  Future<bool> _downloadSongImage(Song song) async {
    String localPath = _IMAGE_FOLDER + "/" + song.id.toString() + '.img';
    if (song.imageFilePath == localPath)
      return true;
    bool success = false;
    await Files.downloadFile('https://mahmoodsheikh.com/music/get_song_image_file/' + song.id.toString(), localPath).then((val) {
      song.imageFilePath = localPath;
      success = true;
    }).catchError((error) { print(error); });
    return success;
  }

  Future<bool> prepareSongForPlaying(Song song) async {
    print('preparing song \'' + song.name + '\' for playing');
    bool success = await _downloadSongAudio(song);
    if (success) await this.updateSongColumns(song,
      <String, String>{'audioFilePath': song.audioFilePath});
    return success;
  }

  Future<bool> prepareSongForPlayerPreview(Song song) async {
    print('preparing song \'' + song.name + '\' for player preview');
    bool success = await _downloadSongImage(song);
    if (success) await this.updateSongColumns(song,
      <String, String>{'imageFilePath': song.imageFilePath});
    return success;
  }

  bool songAudioExistsLocally(Song song) {
    String localPath = _AUDIO_FOLDER + "/" + song.id.toString() + '.audio';
    return song.audioFilePath == localPath;
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
    List<Map<String, dynamic>> maps = (await db.query(
      'songs',
      columns: [
        'id',
      ],
      orderBy: 'id DESC',
      limit: 1,
    ));

    int lastSongId = maps[0]['id'];
    print('lastSongId: ' + lastSongId.toString());
    final response =
      await http.get('https://mahmoodsheikh.com/music/songs?after_id=' + lastSongId.toString());
    return compute(_parseSongsMetadata, response.body);
  }

  Future insertPause(int playbackId, int timestamp) async {
    await db.insert('pauses', <String, dynamic>{
      'playbackId': playbackId,
      'timestamp': timestamp
    });
  }

  Future insertResume(int pauseId, int timestamp) async {
    await db.insert('resumes', <String, dynamic>{
      'pauseId': pauseId,
      'timestamp': timestamp
    });
  }

  Future<int> getLastPauseId() async {
    return await _getLastAutoId('pauses');
  }

  Future insertSeek(int playbackId, double position, int timestamp) async {
    await db.insert('seeks', <String, dynamic>{
      'playbackId': playbackId,
      'position': position,
      'timestamp': timestamp
    });
  }
}
