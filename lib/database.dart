import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'files.dart';
import 'song.dart';

final _AUDIO_FOLDER = 'audio';
final _IMAGE_FOLDER = 'image';

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
        duration int
      )
      '''
    );
  }

  Future<void> open() async {
    if (await databaseExists('music.db')) {
      _isNewDatabase = false;
    }
    db = await openDatabase(
      'music.db',
      version: 11,
      onCreate: this.onCreate
    );
    if (_isNewDatabase) {
      List<Song> songs = await _fetchAllSongsMetadata();
      for (Song song in songs) {
        await insert(song);
        print(song);
      }
    }
  }

  Future insert(Song song) async {
    await db.insert('songs', song.toMap());
  }

  Future<Song> getSong(String id) async {
    List<Map> maps = (await db.query(
      'songs',
      columns: [
        'id',
        'name',
        'artist',
        'album',
        'audioFilePath',
        'imageFilePath',
        'lyrics',
        'duration',
      ],
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
      columns: [
        'id',
        'name',
        'artist',
        'album',
        'audioFilePath',
        'imageFilePath',
        'lyrics',
        'duration',
      ],
    ));
    List<Song> songs = List<Song>();
    for (Map map in maps) {
      songs.add(Song.fromMap(map));
    }
    return songs;
  }

  Future<void> updateSong(Song song) async {
    return await db.update('songs', song.toMap(),
        where: 'id = ?', whereArgs: [song.id]);
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
    if (success) this.updateSong(song);
    return success;
  }

  Future<bool> prepareSongForPlayerPreview(Song song) async {
    print('preparing song \'' + song.name + '\' for player preview');
    bool success = await _downloadSongImage(song);
    if (success) this.updateSong(song);
    return success;
  }

  bool songAudioExistsLocally(Song song) {
    String localPath = _AUDIO_FOLDER + "/" + song.id.toString() + '.audio';
    return song.audioFilePath == localPath;
  }
}
