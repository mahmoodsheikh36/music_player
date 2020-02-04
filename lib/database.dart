import 'dart:convert';
import 'dart:async';
import 'dart:core';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:player/utils.dart';
import 'package:sqflite/sqflite.dart';

import 'files.dart';
import 'music.dart';
import 'datacollection.dart';
import 'functionqueue.dart';

const _BACKEND = "http://10.0.0.55";
const _USERNAME = 'mahmooz';
const _PASSWORD = 'mahmooz';

const LIKED_SONGS_PLAYLIST_ID = 1;

const _DOWNLOAD_TIMEOUT = 200;
const _FILES_FOLDER = 'files';

class DbProvider {
  Database db;
  bool _isNewDatabase = true;
  FunctionQueue _httpRequestFunctionQueue = FunctionQueue();

  Future<Map<String, dynamic>> _fetchMetadata() async {
    try {
      int lastMetadataRequestTime = await _getLastMetadataRequestTime();
      Response response;
      if (lastMetadataRequestTime == null) {
        print('fetching metadata for the first time');
        response = await http.get(_BACKEND +
            '/music/metadata');
      } else {
        print('fetching metadata after last time: ' +
            lastMetadataRequestTime.toString());
        response = await http.get(_BACKEND +
            '/music/metadata?after_time=' + lastMetadataRequestTime.toString());
      }
      _addMetadataRequestTime(Utils.currentTime());
      return jsonDecode(response.body);
    } on SocketException catch (_) {
      print('no internet connection');
      return null;
    }
  }

  Future _handleMetadata(Map<String, dynamic> metadata) async {
    if (metadata == null)
      return;
    final songs = metadata['songs'] as List;
    for (final song in songs) {
      await _addSongsRow(
          song['id'],
          song['name'],
          song['lyrics'],
          song['time_added']);
    }
    final songArtists = metadata['song_artists'] as List;
    for (final songArtist in songArtists) {
      await _addSongArtistsRow(
          songArtist['id'],
          songArtist['artist_id'],
          songArtist['song_id']);
    }
    final albumSongs = metadata['album_songs'] as List;
    for (final albumSong in albumSongs) {
      await _addAlbumSongsRow(
          albumSong['id'],
          albumSong['song_id'],
          albumSong['album_id']);
    }
    final albums = metadata['albums'] as List;
    for (final album in albums) {
      await _addAlbumsRow(
          album['id'],
          album['name'],
          album['artist_id'],
          album['time_added']);
    }
    final singleSongs = metadata['single_songs'] as List;
    for (final singleSong in singleSongs) {
      await _addSingleSongsRow(singleSong['id'], singleSong['song_id']);
    }
    final allSongAudio = metadata['song_audio'] as List;
    for (final songAudio in allSongAudio) {
      await _addSongAudioRow(
          songAudio['id'],
          songAudio['song_id'],
          songAudio['user_static_file_id'],
          songAudio['duration']);
    }
    final songImages = metadata['song_images'] as List;
    for (final songImage in songImages) {
      await _addSongImagesRow(
          songImage['id'],
          songImage['song_id'],
          songImage['user_static_file_id']);
    }
    final artists = metadata['artists'] as List;
    for (final artist in artists) {
      await _addArtistsRow(
          artist['id'],
          artist['name'],
          artist['time_added']);
    }
    final albumImages = metadata['album_images'] as List;
    for (final albumImage in albumImages) {
      await _addAlbumImagesRow(
          albumImage['id'],
          albumImage['album_id'],
          albumImage['user_static_file_id']);
    }
    final playlists = metadata['playlists'] as List;
    for (final playlist in playlists) {
      await _addPlaylistRow(
          playlist['id'],
          playlist['name'],
          playlist['time_added']);
    }
    final playlistSongs = metadata['playlist_songs'] as List;
    for (final playlistSong in playlistSongs) {
      /* TODO: handle this trash code wtf, should be done like that thats stupid
      */
      int playlistId = playlistSong['playlist_id'];
      int songId = playlistSong['song_id'];
      if (playlistId == LIKED_SONGS_PLAYLIST_ID) {
        if (await isSongLiked(songId)) {
          print('skipping already added liked song');
          continue;
        }
      }
      await _addPlaylistSongsRow(
          playlistSong['id'],
          playlistSong['song_id'],
          playlistSong['playlist_id'],
          playlistSong['time_added']);
    }
    final playlistImages = metadata['playlist_images'] as List;
    for (final playlistImage in playlistImages) {
      await _addPlaylistImagesRow(
          playlistImage['id'],
          playlistImage['playlist_id'],
          playlistImage['user_static_file_id']);
    }
    final hiddenAlbums = metadata['hidden_albums'] as List;
    for (final hiddenAlbum in hiddenAlbums) {
      int albumId = hiddenAlbum['album_id'];
      await _deleteAlbum(albumId);
    }
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA FOREIGN_KEYS = OFF');
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE metadata_requests (
        time int
      );
      ''');

    await db.execute('''
      CREATE TABLE playlist_images (
        id int,
        playlist_id int,
        file_id int,
        FOREIGN KEY (playlist_id) REFERENCES playlists (id),
        FOREIGN KEY (file_id) REFERENCES files (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE playlists (
        id int,
        name TEXT NOT NULL,
        time_added int
      );
      ''');

    await db.execute('''
      CREATE TABLE playlist_songs (
        id int,
        song_id int,
        playlist_id int,
        time_added int
      );
      ''');

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
        file_id int,
        duration int,
        FOREIGN KEY (song_id) REFERENCES songs (id),
        FOREIGN KEY (file_id) REFERENCES files (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE song_images (
        id int,
        song_id int,
        file_id int,
        FOREIGN KEY (song_id) REFERENCES songs (id),
        FOREIGN KEY (file_id) REFERENCES files (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE album_images (
        id int,
        album_id int,
        file_id int,
        FOREIGN KEY (album_id) REFERENCES albums (id),
        FOREIGN KEY (file_id) REFERENCES files (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE artists (
        id int,
        name TEXT NOT NULL,
        time_added int
      );
      ''');

    await db.execute('''
      CREATE TABLE files (
        id id,
        name TEXT
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

  Future initIfNotAlready() async {
    if (db != null && db.isOpen)
      return;
    print('opening db');
    await _openDb();
    Map<String, dynamic> metadata = await _fetchMetadata();
    await _handleMetadata(metadata);
  }

  Future _openDb() async {
    final DATABASE_PATH = await Files.getAbsoluteFilePath('music.db');
    //await deleteDatabase(DATABASE_PATH);
    db = await openDatabase(
        DATABASE_PATH,
        version: 11,
        onCreate: _onCreate,
        onConfigure: _onConfigure,
    );
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

  Future updatePlaybackRow(Playback playback,
      Map<String, dynamic> values) async {
    return await db.update('playbacks', values,
        where: 'id = ?', whereArgs: [playback.id]);
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

  Future<Artist> _getArtist(int artistId) async {
    List<Map> maps = await db.query(
      'artists',
      columns: null,
      where: 'id = ?',
      whereArgs: [artistId]
    );
    if (maps.length == 0)
      return null;
    Map artistMap = maps[0];
    return Artist(artistMap['id'], artistMap['name'], artistMap['time_added']);
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

  Future _addSongArtistsRow(int id, int artistId, int songId) async {
    await db.insert('song_artists', <String, dynamic>{
      'id': id,
      'artist_id': artistId,
      'song_id': songId,
    });
  }

  Future _addAlbumsRow(int id, String name, int artistId, int timeAdded) async {
    await db.insert('albums', <String, dynamic>{
      'id': id,
      'name': name,
      'artist_id': artistId,
      'time_added': timeAdded,
    });
  }

  Future _addSongAudioRow(
      int id,
      int songId,
      int fileId,
      int duration) async {
    await db.insert('song_audio', <String, dynamic>{
      'id': id,
      'song_id': songId,
      'file_id': fileId,
      'duration': duration,
    });
  }

  Future _addSongImagesRow(
      int id,
      int songId,
      int fileId) async {
    await db.insert('song_images', <String, dynamic>{
      'id': id,
      'song_id': songId,
      'file_id': fileId,
    });
  }

  Future _addArtistsRow(
      int id,
      String name,
      int timeAdded) async {
    await db.insert('artists', <String, dynamic>{
      'id': id,
      'name': name,
      'time_added': timeAdded,
    });
  }

  Future _addAlbumImagesRow(
      int id,
      int albumId,
      int fileId) async {
    await db.insert('album_images', <String, dynamic>{
      'id': id,
      'album_id': albumId,
      'file_id': fileId,
    });
  }

  Future<List<Map>> _getAlbumsRows() async {
    List<Map> maps = await db.query(
        'albums',
        columns: null
    );
    return maps;
  }

  Future<Map> _getAlbumsRow(int albumId) async {
    List<Map> maps = await db.query(
        'albums',
        columns: null,
        where: 'id = ?',
        whereArgs: [albumId]
    );
    if (maps.length == 0)
      return null;
    return maps[0];
  }

  Future<List<Album>> getAlbums() async {
    List<Map> albumMaps = await _getAlbumsRows();
    List<Album> albums = [];
    for (Map map in albumMaps) {
      Album album = new Album(
        map['id'],
        map['name'],
        await _getArtist(map['artist_id']),
        await _getAlbumSongs(map['id']),
        map['time_added'],
        image: await _getAlbumImage(map['id']),
      );
      for (Song song in album.songs) {
        song.album = album;
      }
      albums.add(album);
    }
    return albums;
  }

  Future<File> _getAlbumImage(int albumId) async {
    Map albumImage = await _getAlbumImagesRow(albumId);
    int fileId = albumImage['file_id'];
    String filePath = await Files.getAbsoluteFilePath(await _getFileName(fileId));
    return filePath == null ? filePath : File(filePath);
  }

  Future<List<Song>> _getAlbumSongs(int albumId) async {
    List<Song> songs = [];
    List<Map> albumSongsMaps = await _getAlbumSongsRows(albumId);
    for (final albumSongsMap in albumSongsMaps) {
      songs.add(await _getSong(albumSongsMap['song_id']));
    }
    return songs;
  }

  Future<List<Artist>> getSongArtists(int songId) async {
    List<Artist> artists = [];
    List<Map> songArtistsMaps = await getSongArtistsRows(songId);
    for (final songArtistsMap in songArtistsMaps) {
      Artist artist = await _getArtist(songArtistsMap['artist_id']);
      artists.add(artist);
    }
    return artists;
  }

  Future<List<Map>> getSongArtistsRows(int songId) async {
    List<Map> maps = await db.query(
        'song_artists',
        columns: null,
        where: 'song_id = ?',
        whereArgs: [songId]
    );
    return maps;
  }

  Future<List<Map>> _getAlbumSongsRows(int albumId) async {
    List<Map> maps = await db.query(
        'album_songs',
        columns: null,
        where: 'album_id = ?',
        whereArgs: [albumId]
    );
    return maps;
  }

  Future<Map> _getSongsRow(int songId) async {
    List<Map> maps = await db.query(
        'songs',
        columns: null,
        where: 'id = ?',
        whereArgs: [songId]
    );
    return maps[0];
  }

  Future<List<Map>> getSingleSongsRows() async {
    List<Map> maps = await db.query(
        'single_songs',
        columns: null,
    );
    return maps;
  }

  Future<List<Song>> getSingles() async {
    List<Map> singleSongsMaps = await getSingleSongsRows();
    List<Song> singles = [];
    for (final singleSongsMap in singleSongsMaps) {
      singles.add(await _getSong(singleSongsMap['song_id']));
    }
    return singles;
  }

  Future<Song> _getSong(int songId) async {
    Map songMap = await _getSongsRow(songId);
    Song song = Song(
        songMap['id'],
        songMap['name'],
        songMap['lyrics'],
        await getSongArtists(songMap['id']),
        songMap['time_added']);

    Map songAudio = await _getSongAudioRow(songId);
    song.duration = songAudio['duration'];

    int audioFileId = songAudio['file_id'];
    String audioFileName = await _getFileName(audioFileId);
    if (audioFileName != null) {
      song.audio = File(await Files.getAbsoluteFilePath(audioFileName));
    }

    Map songImage = await _getSongImagesRow(songId);
    int imageFileId = songImage['file_id'];
    String imageFileName = await _getFileName(imageFileId);
    if (imageFileName != null) {
      song.image = File(await Files.getAbsoluteFilePath(imageFileName));
    }

    return song;
  }

  Future<bool> downloadSongListImage(SongList songList) async {
    if (songList is Album)
      return await downloadAlbumImage(songList);
    else if (songList is Playlist)
      return await downloadPlaylistImage(songList);
    else {
      print('only albums and playlists images can be downloaded');
      return false;
    }
  }

  Future<bool> downloadPlaylistImage(Playlist playlist) async {
    Completer<bool> completer = new Completer<bool>();
    String fileName = _FILES_FOLDER + '/' + Utils.randomString();
    String functionId = playlist.hashCode.toString();
    if (_httpRequestFunctionQueue.hasEntryWithId(functionId)) {
      print('rejecting image download request');
      completer.complete(false);
    } else {
      print('adding playlist image to download queue: ' + playlist.name);
      _httpRequestFunctionQueue.add((functionQueueCallback) async {
        Map playlistImage = await _getPlaylistImagesRow(playlist.id);
        int fileId = playlistImage['file_id'];
        String savedFilename = await _getFileName(fileId);
        final response = await http.get(
            _BACKEND + '/static/file/$fileId'
        ).timeout(Duration(seconds: _DOWNLOAD_TIMEOUT), onTimeout: () {
          print('timed out downloading image for playlist \'' + playlist.name +
              '\'');
          return null;
        });
        if (response != null) {
          await Files.saveHttpResponse(response, fileName);
          playlist.image = File(await Files.getAbsoluteFilePath(fileName));
          if (savedFilename != null) {
            File oldFile = File(await Files.getAbsoluteFilePath(savedFilename));
            oldFile.delete();
            await _updateFileRow(fileId, fileName);
          } else {
            await _addFileRow(fileId, fileName);
          }
          print('downloaded image for playlist ' + playlist.name);
          completer.complete(true);
        } else {
          print('failed to download image for playlist ' + playlist.name);
          completer.complete(false);
        }
        functionQueueCallback();
      }, id: functionId);
    }
    return completer.future;
  }

  Future<bool> downloadAlbumImage(Album album) async {
    Completer<bool> completer = new Completer<bool>();
    String fileName = _FILES_FOLDER + '/' + Utils.randomString();
    String functionId = album.hashCode.toString();
    if (_httpRequestFunctionQueue.hasEntryWithId(functionId)) {
      print('rejecting image download request');
      completer.complete(false);
    } else {
      print('adding album image to download queue: ' + album.name);
      _httpRequestFunctionQueue.add((functionQueueCallback) async {
        Map albumImage = await _getAlbumImagesRow(album.id);
        int fileId = albumImage['file_id'];
        String savedFilename = await _getFileName(fileId);
        final response = await http.get(
            _BACKEND + '/static/file/$fileId'
        ).timeout(Duration(seconds: _DOWNLOAD_TIMEOUT), onTimeout: () {
          print('timed out downloading image for album \'' + album.name +
              '\'');
          return null;
        });
        if (response != null) {
          await Files.saveHttpResponse(response, fileName);
          album.image = File(await Files.getAbsoluteFilePath(fileName));
          for (Song song in album.songs) {
            song.image = album.image;
          }
          if (savedFilename != null) {
            File oldFile = File(await Files.getAbsoluteFilePath(savedFilename));
            oldFile.delete();
            await _updateFileRow(fileId, fileName);
          } else {
            await _addFileRow(fileId, fileName);
          }
          print('downloaded image for album ' + album.name);
          completer.complete(true);
        } else {
          print('failed to download image for album ' + album.name);
          completer.complete(false);
        }
        functionQueueCallback();
      }, id: functionId);
    }
    return completer.future;
  }

  Future<bool> downloadSongImage(Song song) async {
    Completer<bool> completer = new Completer<bool>();
    String fileName = _FILES_FOLDER + '/' + Utils.randomString();
    String functionId = song.hashCode.toString() + 'image';
    if (_httpRequestFunctionQueue.hasEntryWithId(functionId)) {
      print('rejecting song image download request: ' + song.name);
      completer.complete(false);
    } else {
      print('adding song image to download queue: ' + song.name);
      _httpRequestFunctionQueue.add((functionQueueCallback) async {
        Map songImage = await _getSongImagesRow(song.id);
        int fileId = songImage['file_id'];
        String savedFilename = await _getFileName(fileId);
        final response = await http.get(
            _BACKEND + '/static/file/$fileId'
        ).timeout(Duration(seconds: _DOWNLOAD_TIMEOUT), onTimeout: () {
          print('timed out downloading image for song: ' + song.name);
          return null;
        });
        if (response != null) {
          await Files.saveHttpResponse(response, fileName);
          song.image = File(await Files.getAbsoluteFilePath(fileName));
          if (savedFilename != null) {
            File(await Files.getAbsoluteFilePath(savedFilename)).delete();
            _updateFileRow(fileId, fileName);
          } else {
            await _addFileRow(fileId, fileName);
          }
          print('downloaded image for song: ' + song.name);
          completer.complete(true);
        } else {
          print('failed to download image for song: ' + song.name);
          completer.complete(false);
        }
        functionQueueCallback();
      }, id: functionId);
    }
    return completer.future;
  }

  String _getSongAudioUniqueId(Song song) {
    return song.hashCode.toString() + 'audio';
  }

  bool isDownloadingSongAudio(Song song) {
    return _httpRequestFunctionQueue.hasEntryWithId(_getSongAudioUniqueId(song));
  }

  Future<bool> downloadSongAudio(Song song) async {
    Completer<bool> completer = new Completer<bool>();
    String fileName = _FILES_FOLDER + '/' + Utils.randomString();
    if (isDownloadingSongAudio(song)) {
      print('rejecting song audio download request: ' + song.name);
      completer.complete(false);
    } else {
      print('adding song audio to download queue: ' + song.name);
      _httpRequestFunctionQueue.add((functionQueueCallback) async {
        Map songAudio = await _getSongAudioRow(song.id);
        int fileId = songAudio['file_id'];
        String savedFilename = await _getFileName(fileId);
        final response = await http.get(
            _BACKEND + '/static/file/$fileId'
        ).timeout(Duration(seconds: _DOWNLOAD_TIMEOUT), onTimeout: () {
          print('timed out downloading audio for song: ' + song.name);
          return null;
        });
        if (response != null) {
          await Files.saveHttpResponse(response, fileName);
          song.audio = File(await Files.getAbsoluteFilePath(fileName));
          if (savedFilename != null) {
            File(await Files.getAbsoluteFilePath(savedFilename)).delete();
            _updateFileRow(fileId, fileName);
          } else {
            await _addFileRow(fileId, fileName);
          }
          print('downloaded audio for song ' + song.name);
          completer.complete(true);
        } else {
          print('failed to download audio for song ' + song.name);
          completer.complete(false);
        }
        functionQueueCallback();
      }, id: _getSongAudioUniqueId(song));
    }
    return completer.future;
  }

  Future<Map> _getSongImagesRow(int songId) async {
    List<Map> maps = await db.query(
      'song_images',
      columns: null,
      where: 'song_id = ?',
      whereArgs: [songId]
    );
    return maps[0];
  }

  Future<Map> _getSongAudioRow(int songId) async {
    List<Map> maps = await db.query(
      'song_audio',
      columns: null,
      where: 'song_id = ?',
      whereArgs: [songId]
    );
    return maps[0];
  }

  Future<Map> _getAlbumImagesRow(int albumId) async {
    List<Map> maps = await db.query(
      'album_images',
      columns: null,
      where: 'album_id = ?',
      whereArgs: [albumId],
    );
    return maps[0];
  }

  Future _updateAlbumImagesRow(int albumImagesId,
      Map<String, dynamic> values) async {
    return await db.update('album_images', values,
        where: 'id = ?', whereArgs: [albumImagesId]);
  }

  Future _updateSongAudioRow(int songAudioId,
      Map<String, dynamic> values) async {
    return await db.update('song_audio', values,
        where: 'id = ?', whereArgs: [songAudioId]);
  }

  Future _updateSongImagesRow(int songImageId,
      Map<String, dynamic> values) async {
    return await db.update('song_images', values,
        where: 'id = ?', whereArgs: [songImageId]);
  }

  Future _addFileRow(int id, String fileName) async {
    await db.insert('files', <String, dynamic>{
      'id': id,
      'name': fileName,
    });
  }

  Future _updateFileRow(int fileId, String fileName) async {
    await db.update(
      'files',
      {
        'name': fileName
      },
      where: 'id = ?',
      whereArgs: [fileId]
    );
  }

  Future<String> _getFileName(int fileId) async {
    List<Map> maps = await db.query(
      'files',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [fileId],
    );
    if (maps.length == 0)
      return null;
    return maps[0]['name'];
  }

  Future _addPlaylistRow(int id, String name, int timeAdded) async {
    await db.insert('playlists', <String, dynamic>{
      'id': id,
      'name': name,
      'time_added': timeAdded,
    });
  }

  Future _addPlaylistSongsRow(int id, int songId, int playlistId, int timeAdded) async {
    await db.insert('playlist_songs', <String, dynamic>{
      'id': id,
      'song_id': songId,
      'playlist_id': playlistId,
      'time_added': timeAdded,
    });
  }

  Future<List<Map>> _getPlaylistsRows() async {
    List<Map> maps = await db.query(
      'playlists',
      columns: null,
    );
    return maps;
  }

  Future<List<Map>> _getPlaylistSongsRows(int playlistId) async {
    List<Map> maps = await db.query(
      'playlist_songs',
      columns: null,
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
    );
    return maps;
  }
  Future<Map> _getPlaylistSongsRow(int playlistId, int songId) async {
    List<Map> maps = await db.query(
      'playlist_songs',
      columns: null,
      where: 'playlist_id = ? AND song_id = ?',
      whereArgs: [playlistId, songId],
    );
    if (maps.length == 0)
      return null;
    return maps[0];
  }

  Future getPlaylists(MusicLibrary library) async {
    List<Map> playlistMaps = await _getPlaylistsRows();
    List<Playlist> playlists = [];
    for (final playlistMap in playlistMaps) {
      final playlist = Playlist(
        playlistMap['id'],
        playlistMap['name'],
        await _getPlaylistSongs(playlistMap['id'], library),
        playlistMap['time_added'],
        image: await _getPlaylistImage(playlistMap['id']),
      );
      playlists.add(playlist);
    }
    return playlists;
  }

  Future<List<Song>> _getPlaylistSongs(int playlistId, MusicLibrary library) async {
    List<Map> playlistSongsMaps = await _getPlaylistSongsRows(playlistId);
    List<Song> songs = [];
    for (final playlistSongsMap in playlistSongsMaps) {
      int songId = playlistSongsMap['song_id'];
      songs.add(library.getSong(songId));
    }
    return songs;
  }

  Future<File> _getPlaylistImage(int playlistId) async {
    Map albumImage = await _getPlaylistImagesRow(playlistId);
    int fileId = albumImage['file_id'];
    String filePath = await Files.getAbsoluteFilePath(await _getFileName(fileId));
    return filePath == null ? null : File(filePath);
  }

  Future _addPlaylistImagesRow(
      int id,
      int playlistId,
      int fileId) async {
    await db.insert('playlist_images', <String, dynamic>{
      'id': id,
      'playlist_id': playlistId,
      'file_id': fileId,
    });
  }

  Future<Map> _getPlaylistImagesRow(int playlistId) async {
    List<Map> maps = await db.query(
      'playlist_images',
      columns: null,
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
    );
    return maps[0];
  }

  Future<int> _getLastMetadataRequestTime() async {
    List<Map> maps = await db.query(
      'metadata_requests',
      columns: ['time'],
      orderBy: 'time DESC',
      limit: 1,
    );
    if (maps.length == 0)
      return null;
    return maps[0]['time'];
  }
  Future _addMetadataRequestTime(int time) async {
    await db.insert('metadata_requests', <String, dynamic>{
      'time': time
    });
  }

  /* wipes it from the face of the earth */
  Future _deleteAlbum(int albumId) async {
    print('deleting album ' + albumId.toString());
    Map albumMap = await _getAlbumsRow(albumId);
    if (albumMap == null) {
      print('album $albumId doesnt exist, no need to delete it');
      return;
    }
    Map albumImage = await _getAlbumImagesRow(albumId);
    int fileId = albumImage['file_id'];
    await _deleteDatabaseFile(fileId);
    List<Map> albumSongsRows = await _getAlbumSongsRows(albumId);
    for (final albumSongsRow in albumSongsRows) {
      int songId = albumSongsRow['song_id'];
      Map songAudio = await _getSongAudioRow(songId);
      Map songImage = await _getSongImagesRow(songId);
      int audioFileId = songAudio['file_id'];
      int imageFileId = songImage['file_id'];
      _deleteDatabaseFile(audioFileId);
      _deleteDatabaseFile(imageFileId);
    }
    await db.delete(
      'albums',
      where: 'id = ?',
      whereArgs: [albumId],
    );
  }

  Future _deleteDatabaseFile(int fileId) async {
    String fileName = await _getFileName(fileId);
    if (fileName != null) {
      File file = File(await Files.getAbsoluteFilePath(fileName));
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future addSongToLikedSongsPlaylist(int songId) async {
    final response = await http.post(_BACKEND +
        '/music/add_song_to_playlist?playlist_id=$LIKED_SONGS_PLAYLIST_ID&song_id=$songId',
      body: {
        'username': _USERNAME,
        'password': _PASSWORD,
      }
    );
    int rowId = int.tryParse(response.body);
    if (rowId != null) {
      await _addPlaylistSongsRow(
          rowId, songId, LIKED_SONGS_PLAYLIST_ID, Utils.currentTime());
      print('added song to liked songs playlist');
    } else {
      print(response.body);
    }
  }

  Future<bool> isSongLiked(int songId) async {
    Map playlistSongsRow = await _getPlaylistSongsRow(LIKED_SONGS_PLAYLIST_ID, songId);
    return playlistSongsRow != null;
  }
}
