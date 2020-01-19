import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'files.dart';
import 'song.dart';
import 'datacollection.dart';

final _AUDIO_FOLDER  = 'audio';
final _IMAGE_FOLDER  = 'image';

class SongProvider {
  Database db;
  bool _isNewDatabase = true;

  static Future<List<Song>> _fetchAllSongsMetadata() async {
    final response =
    await http.get('https://mahmoodsheikh.com/music/all_songs');
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
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        progressOnEnd REAL,
        progressOnStart REAL
      );
      '''
    );
  }

  Future<void> open() async {
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
    }
  }

  Future insertSong(Song song) async {
    await db.insert('songs', song.toMap());
  }

  Future insertPlayback(Playback playback) async {
    await db.insert('playbacks', playback.toMap(withId: false));
  }

  Future<Playback> getLastPlayback() async {
    List<Map<String, dynamic>> maps = (await db.query(
      'sqlite_sequence',
      columns: [
        'seq',
      ],
      where: 'name = ?',
      whereArgs: ['playbacks'],
    ));
    if (maps.length == 0)
        return null;

    int lastPlaybackId = maps[0]['seq'];
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
}
