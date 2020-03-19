import 'dart:convert';
import 'dart:async';
import 'dart:core';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:sqflite/sqflite.dart';

import 'dataanalysis.dart';
import 'utils.dart';
import 'files.dart';
import 'music.dart';
import 'datacollection.dart';
import 'functionqueue.dart';

const _BACKEND = "http://10.0.0.54";
const _USERNAME = 'mahmooz';
const _PASSWORD = 'mahmooz';

const _DOWNLOAD_TIMEOUT = 100;
const _FILES_FOLDER = 'files';

class DbProvider {
  Database db;
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
          song['time_added'],
          song['audio_file_id'],
          song['duration'],
          song['bitrate'],
          song['codec'],
      );
    }
    final songArtists = metadata['song_artists'] as List;
    for (final songArtist in songArtists) {
      await _addSongArtistsRow(
          songArtist['id'],
          songArtist['artist_id'],
          songArtist['song_id']);
    }
    final albumArtists = metadata['album_artists'] as List;
    for (final albumArtist in albumArtists) {
      await _addAlbumArtistsRow(
          albumArtist['id'],
          albumArtist['artist_id'],
          albumArtist['album_id']);
    }
    final albumSongs = metadata['album_songs'] as List;
    for (final albumSong in albumSongs) {
      await _addAlbumSongsRow(
          albumSong['id'],
          albumSong['song_id'],
          albumSong['album_id'],
          albumSong['index_in_album'],
      );
    }
    final albums = metadata['albums'] as List;
    for (final album in albums) {
      await _addAlbumsRow(
          album['id'],
          album['name'],
          album['time_added'],
          album['year'],
          album['image_file_id']);
    }
    final singleSongs = metadata['single_songs'] as List;
    for (final singleSong in singleSongs) {
      await _addSingleSongsRow(
          singleSong['id'],
          singleSong['song_id'],
          singleSong['image_file_id'],
          singleSong['year'],
      );
    }
    final artists = metadata['artists'] as List;
    for (final artist in artists) {
      await _addArtistsRow(
          artist['id'],
          artist['name'],
          artist['time_added']);
    }
    final likedSongs = metadata['liked_songs'];
    for (final likedSong in likedSongs) {
      if (await isSongLiked(likedSong['song_id']))
        continue;
      await _addLikedSongsRow(
        likedSong['id'],
        likedSong['song_id'],
      );
    }
    final deletedAlbums = metadata['deleted_albums'];
    for (final deletedAlbum in deletedAlbums) {
      await _deleteAlbum(
        deletedAlbum['album_id'],
      );
    }
    await _addMetadataRequestTime(Utils.currentTime());
    print('done handling metadata');
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
      CREATE TABLE liked_songs (
        id INTEGER PRIMARY KEY,
        song_id int,
        time_added int,
        FOREIGN KEY (song_id) REFERENCES songs (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE songs (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        time_added int,
        audio_file_id INTEGER NOT NULL,
        duration REAL,
        bitrate int,
        codec TEXT NOT NULL,
        FOREIGN KEY (audio_file_id) REFERENCES files (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE song_artists (
        id INTEGER PRIMARY KEY,
        artist_id int,
        song_id int,
        FOREIGN KEY (artist_id) REFERENCES artists (id),
        FOREIGN KEY (song_id) REFERENCES songs (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE album_songs (
        id INTEGER PRIMARY KEY,
        song_id int,
        album_id int,
        index_in_album int,
        FOREIGN KEY (song_id) REFERENCES songs (id),
        FOREIGN KEY (album_id) REFERENCES albums (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE albums (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        time_added int,
        year INTEGER,
        image_file_id INTEGER NOT NULL,
        FOREIGN KEY (image_file_id) REFERENCES files (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE album_artists (
        id INTEGER PRIMARY KEY,
        artist_id INTEGER NOT NULL,
        album_id INTEGER NOT NULL,
        FOREIGN KEY (artist_id) REFERENCES artists (id),
        FOREIGN KEY (album_id) REFERENCES albums (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE single_songs (
        id INTEGER PRIMARY KEY,
        song_id int,
        image_file_id INTEGER NOT NULL,
        year INTEGER,
        FOREIGN KEY (image_file_id) REFERENCES files (id),
        FOREIGN KEY (song_id) REFERENCES songs (id)
      );
      ''');

    await db.execute('''
      CREATE TABLE artists (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        time_added int
      );
      ''');

    await db.execute('''
      CREATE TABLE files (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
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
    // following line is for debugging only, it deletes the database
    //await deleteDatabase(DATABASE_PATH);
    db = await openDatabase(
        DATABASE_PATH,
        version: 11, // not sure what that is
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
    return Artist(
        id: artistMap['id'],
        name: artistMap['name'],
        timeAdded: artistMap['time_added'],
        singles: [],
        albums: []
    );
  }

  Future _addSingleSongsRow(int id, int songId, int imageFileId, int year) async {
    await db.insert('single_songs', <String, dynamic>{
      'id': id,
      'song_id': songId,
      'image_file_id': imageFileId,
      'year': year
    });
  }

  Future _addAlbumSongsRow(int id, int songId, int albumId, int indexInAlbum) async {
    await db.insert('album_songs', <String, dynamic>{
      'id': id,
      'song_id': songId,
      'album_id': albumId,
      'index_in_album': indexInAlbum,
    });
  }

  Future _addSongsRow(int id, String name, int timeAdded, int audioFileId,
                      double duration, int bitrate, String codec) async {
    await db.insert('songs', <String, dynamic>{
      'id': id,
      'name': name,
      'time_added': timeAdded,
      'audio_file_id': audioFileId,
      'duration': duration,
      'bitrate': bitrate,
      'codec': codec,
    });
  }

  Future _addSongArtistsRow(int id, int artistId, int songId) async {
    await db.insert('song_artists', <String, dynamic>{
      'id': id,
      'artist_id': artistId,
      'song_id': songId,
    });
  }

  Future _addAlbumArtistsRow(int id, int artistId, int albumId) async {
    await db.insert('album_artists', <String, dynamic>{
      'id': id,
      'artist_id': artistId,
      'album_id': albumId,
    });
  }

  Future _addAlbumsRow(int id, String name, int timeAdded, int year, int imageFileId) async {
    await db.insert('albums', <String, dynamic>{
      'id': id,
      'name': name,
      'time_added': timeAdded,
      'year': year,
      'image_file_id': imageFileId,
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

  Future<List<Map>> _getAlbumsRows() async {
    List<Map> maps = await db.query(
      'albums',
      columns: null,
      orderBy: 'time_added DESC',
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

  Future<MusicLibrary> getMusic(callback) async {
    await this.initIfNotAlready();

    List<Map> albumsRows = await _getAlbumsRows();
    List<Map> songsRows = await _getSongsRows();
    List<Map> singleSongsRows = await _getSingleSongsRows();
    List<Map> albumSongsRows = await _getAlbumSongsRows();
    List<Map> songArtistsRows = await _getSongArtistsRows();
    List<Map> likedSongsRows = await _getLikedSongsRows();
    List<Map> albumArtistsRows = await _getAlbumArtistsRows();

    Map<int, Artist> artistsMap = {};
    List<Artist> artistsList = await _getArtists();
    for (Artist artist in artistsList) {
      artistsMap.putIfAbsent(artist.id, () => artist);
    }

    Map<int, Map> filesMap = {};
    List<Map> filesRows = await _getFilesRows();
    for (Map filesRow in filesRows) {
      filesMap.putIfAbsent(filesRow['id'], () => filesRow);
    }

    Map songsMap = {};
    for (final songsRow in songsRows) {
      int songId = songsRow['id'];
      List<Artist> songArtists = [];
      for (final songArtistsRow in songArtistsRows) {
        if (songArtistsRow['song_id'] == songId)
          songArtists.add(artistsMap[songArtistsRow['artist_id']]);
      }

      int audioFileId = songsRow['audio_file_id'];
      String audioFileName = filesMap[audioFileId] == null ? null :
      filesMap[audioFileId]['name'];

      Song song = Song(
        songId,
        songsRow['name'],
        null,
        songArtists,
        songsRow['time_added'],
        audioFileName == null ? null :
            File(await Files.getAbsoluteFilePath(audioFileName)),
        songsRow['duration']
      );

      song.secondsListened = (await getSecondsListenedToSong(this, song.id)).toInt();

      songsMap.putIfAbsent(song.id, () => song);
    }

    List<Album> albums = [];

    for (final albumsRow in albumsRows) {
      int albumId = albumsRow['id'];
      List<Artist> albumArtists = [];
      for (final albumArtistsRow in albumArtistsRows) {
        if (albumArtistsRow['album_id'] == albumId) {
          Artist artist = artistsMap[albumArtistsRow['artist_id']];
          if (artist == null)
            throw new Exception('artist not found in database for album ' +
                albumsRow['id'].toString() + ', artist id: ' +
                artist.id.toString());
          albumArtists.add(artist);
        }
      }
      List<Song> albumSongs = [];
      for (final albumSongsRow in albumSongsRows) {
        if (albumSongsRow['album_id'] == albumId) {
          int songId = albumSongsRow['song_id'];
          albumSongs.add(songsMap[songId]);
        }
      }

      int imageFileId = albumsRow['image_file_id'];
      String imageFileName = filesMap[imageFileId] == null ? null :
          filesMap[imageFileId]['name'];

      Album album = Album(
        albumsRow['id'],
        albumsRow['name'],
        albumArtists,
        albumSongs,
        albumsRow['time_added'],
        imageFileName == null ? null :
          File(await Files.getAbsoluteFilePath(imageFileName)),
      );

      for (Artist artist in albumArtists) {
        artist.albums.add(album);
      }

      for (final song in album.songs) {
        song.album = album;
        song.image = album.image;
      }
      albums.add(album);
    }

    List<Song> singleSongs = [];

    for (final singleSongsRow in singleSongsRows) {
      int songId = singleSongsRow['song_id'];
      Song single = songsMap[songId];
      int imageFileId = singleSongsRow['image_file_id'];
      String imageFileName = filesMap[imageFileId] == null ? null :
          filesMap[imageFileId]['name'];
      single.image = imageFileName == null ? null :
          File(await Files.getAbsoluteFilePath(imageFileName));
      singleSongs.add(single);
      for (final artist in single.artists) {
        artist.singles.add(single);
      }
    }

    List<Song> likedSongs = [];

    for (final likedSongsRow in likedSongsRows) {
      int songId = likedSongsRow['song_id'];
      likedSongs.add(songsMap[songId]);
    }

    final singlesList = SingleSongsList(
      singleSongs,
      await Utils.getAssetAsFile('music_note.png'),
    );

    final likedSongsList = LikedSongsList(
        likedSongs,
        await Utils.getAssetAsFile('liked_songs_image.png'));

    callback(albums, singlesList, likedSongsList, artistsList);
  }

  Future<List<Artist>> _getArtists() async {
    List<Map> artistsRows = await _getArtistsRows();
    List<Artist> artists = [];
    for (final artistsRow in artistsRows) {
      artists.add(Artist(
          id: artistsRow['id'],
          name: artistsRow['name'],
          timeAdded: artistsRow['time_added'],
          albums: [],
          singles: []));
    }
    return artists;
  }

  Future<List<Map>> _getSingleSongsRows() async {
    List<Map> maps = await db.query(
      'single_songs',
      columns: null,
    );
    return maps;
  }

  Future<Map> _getSingleSongsRow(int singleId) async {
    List<Map> maps = await db.query(
      'single_songs',
      columns: null,
      where: 'id = ?',
      whereArgs: [singleId],
    );
    if (maps.length == 0)
      return null;
    return maps[0];
  }

  Future<Map> _getSingleSongsRowBySongId(int songId) async {
    List<Map> maps = await db.query(
      'single_songs',
      columns: null,
      where: 'song_id = ?',
      whereArgs: [songId],
    );
    if (maps.length == 0)
      return null;
    return maps[0];
  }

  Future<List<Map>> _getSongsRows() async {
    List<Map> maps = await db.query(
      'songs',
      columns: null,
    );
    return maps;
  }

  Future<Map> _getSongsRow(int songId) async {
    List<Map> maps = await db.query(
      'songs',
      columns: null,
      where: 'id = ?',
      whereArgs: [songId],
    );
    if (maps.length == 0)
      return null;
    return maps[0];
  }

  Future<List<Map>> _getArtistsRows() async {
    List<Map> maps = await db.query(
      'artists',
      columns: null,
    );
    return maps;
  }

  Future<File> _getAlbumImage(int albumId) async {
    Map albumsRow = await _getAlbumsRow(albumId);
    int imageFileId = albumsRow['image_file_id'];
    String filePath = await Files.getAbsoluteFilePath(await _getFileName(imageFileId));
    return filePath == null ? filePath : File(filePath);
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

  Future<List<Map>> _getAlbumSongsRows() async {
    List<Map> maps = await db.query(
        'album_songs',
        columns: null,
    );
    return maps;
  }

  Future<List<Map>> getSingleSongsRows() async {
    List<Map> maps = await db.query(
        'single_songs',
        columns: null,
    );
    return maps;
  }

  Future<bool> downloadSongListImage(SongList songList) async {
    if (songList is Album)
      return await downloadAlbumImage(songList);
    //else if (songList is Playlist)
      //return await downloadPlaylistImage(songList);
    else {
      print('only albums and playlists images can be downloaded');
      return false;
    }
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
        Map albumsRow = await _getAlbumsRow(album.id);
        int fileId = albumsRow['image_file_id'];
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
        int fileId = await _getSongImageFileId(song);
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
        Map songsRow = await _getSongsRow(song.id);
        print('downloading audio with bitrate of ' + songsRow['bitrate'].toString());
        int fileId = songsRow['audio_file_id'];
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

  Future<List<Map>> _getFilesRows() async {
    List<Map> maps = await db.query(
      'files',
      columns: null,
    );
    return maps;
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

  Future<List<Map>> _getPlaylistSongsRows() async {
    List<Map> maps = await db.query(
      'playlist_songs',
      columns: null,
    );
    return maps;
  }

  Future<List<Map>> _getSongArtistsRows() async {
    List<Map> maps = await db.query(
      'song_artists',
      columns: null,
    );
    return maps;
  }

  Future<List<Map>> _getAlbumArtistsRows() async {
    List<Map> maps = await db.query(
      'album_artists',
      columns: null,
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

  Future _deleteSong(int songId) async {
    Map songRow = await _getSongsRow(songId);
    await _deleteLikedSongsRows(songId);
    await _deleteSongsRow(songId);
    await _deleteSongArtists(songId);
    if (songRow['image_file_id'] != null)
      _deleteDatabaseFile(songRow['image_file_id']);
  }

  Future _deleteLikedSongsRows(int songId) async {
    await db.delete(
      'liked_songs',
      where: 'song_id = ?',
      whereArgs: [songId],
    );
  }

  Future _deleteAlbum(int albumId) async {
    Map albumRow = await _getAlbumsRow(albumId);
    if (albumRow == null) {
      print('album $albumId doesnt exist, no need to delete it');
      return;
    }
    print('deleting album: $albumId');
    List<Map> albumSongsRows = await _getSongsRowsForAlbum(albumId);
    for (final albumSongsRow in albumSongsRows) {
      int songId = albumSongsRow['song_id'];
      _deleteSong(songId);
      await _deleteAlbumSongsRow(albumSongsRow['id']);
    }
    int imageFileId = albumRow['image_file_id'];
    await _deleteDatabaseFile(imageFileId);
    await _deleteAlbumsRow(albumId);
  }

  Future _deleteSingle(int singleId) async {
    Map singleRow = await _getSingleSongsRow(singleId);
    if (singleRow == null) {
      print('no need to delete single ' + singleId.toString());
      return;
    }
    int songId = singleRow['song_id'];
    _deleteSong(songId);
    _deleteSingleSongsRow(singleRow['id']);
    print('deleted single song with id ' + singleId.toString());
  }

  Future<List<Map>> _getSongsRowsForAlbum(int albumId) async {
    List<Map> maps = await db.query(
      'album_songs',
      columns: null,
      where: 'album_id = ?',
      whereArgs: [albumId],
    );
    return maps;
  }

  Future _deleteAlbumsRow(int albumId) async {
    await db.delete(
      'albums',
      where: 'id = ?',
      whereArgs: [albumId],
    );
  }

  Future _deleteSingleSongsRow(int singleId) async {
    await db.delete(
      'single_songs',
      where: 'id = ?',
      whereArgs: [singleId],
    );
  }

  Future _deleteSongsRow(int songId) async {
    await db.delete(
      'songs',
      where: 'id = ?',
      whereArgs: [songId],
    );
  }

  Future _deleteAlbumSongsRow(int rowId) async {
    await db.delete(
      'album_songs',
      where: 'id = ?',
      whereArgs: [rowId],
    );
  }

  Future _deleteSongArtists(int songId) async {
    await db.delete(
      'song_artists',
      where: 'song_id = ?',
      whereArgs: [songId],
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

  Future _addSongLyricsRow(
      int id,
      int songId,
      String lyrics) async {
    await db.insert('song_lyrics', <String, dynamic>{
      'song_id': songId,
      'lyrics': lyrics,
    });
  }

  Future _addPlaylistRemovalsRow(
      int id,
      int playlistId,
      int timeAdded) async {
    await db.insert('song_lyrics', <String, dynamic>{
      'id': id,
      'playlist_id': playlistId,
      'time_added': timeAdded,
    });
  }

  Future _addLikedSongsRow(
      int id,
      int songId) async {
    await db.insert('liked_songs', <String, dynamic>{
      'id': id,
      'song_id': songId,
    });
  }

  Future _addLikedSongRemovalsRow(
      int id,
      int songId) async {
    await db.insert('liked_song_removals', <String, dynamic>{
      'id': id,
      'song_id': songId,
    });
  }

  Future _addPlaylistSongAdditionsRow(
      int id,
      int playlistId,
      int songId) async {
    await db.insert('playlist_song_additions', <String, dynamic>{
      'id': id,
      'song_id': songId,
      'playlist_id': playlistId,
    });
  }

  Future _addPlaylistSongRemovalsRow(
      int id,
      int playlistId,
      int songId) async {
    await db.insert('playlist_song_removals', <String, dynamic>{
      'id': id,
      'song_id': songId,
      'playlist_id': playlistId,
    });
  }
  Future<Map<String, dynamic>> _getSongLyricsRow(int songId) async {
    List<Map> maps = await db.query(
      'song_lyrics',
      columns: null,
      where: 'song_id = ?',
      whereArgs: [songId],
    );
    if (maps.length == 0)
      return null;
    return maps[0];
  }

  Future<String> _getSongLyrics(int songId) async {
    Map map = await _getSongLyricsRow(songId);
    if (map == null)
      return null;
    return map['lyrics'];
  }

  Future<List<Map>> _getLikedSongsRows() async {
    List<Map> maps = await db.query(
      'liked_songs',
      columns: null,
    );
    return maps;
  }

  Future likeSong(int songId) async {
    final response = await http.post(
      _BACKEND + '/music/like_song?id=$songId',
      body: {
        'username': _USERNAME,
        'password': _PASSWORD,
      }
    );
    final json = jsonDecode(response.body);
    if (json['success']) {
      _addLikedSongsRow(
          json['liked_songs_row_id'],
          songId
      );
      print('successfully liked song');
    } else {
      print(json['error']);
    }
  }

  Future<Map> _getLikedSongsRow(int songId) async {
    List<Map> maps = await db.query(
      'liked_songs',
      columns: null,
      where: 'song_id = ?',
      whereArgs: [songId]
    );
    if (maps.length == 0)
      return null;
    return maps[0];
  }

  Future<bool> isSongLiked(int songId) async {
    return (await _getLikedSongsRow(songId)) != null;
  }

  Future<int> _getSongImageFileId(Song song) async {
    if (song.isSingle) {
      Map singleSongsRow = await _getSingleSongsRowBySongId(song.id);
      return singleSongsRow['image_file_id'];
    } else {
      Map albumsRow = await _getAlbumsRow(song.album.id);
      return albumsRow['image_file_id'];
    }
  }
}
