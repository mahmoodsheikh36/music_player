import 'package:sqflite/sqflite.dart';
import 'song.dart';

class SongProvider {
  Database db;
  static SongProvider globalInstance = new SongProvider();

  static SongProvider getGlobalInstance() {
    return globalInstance;
  }

  Future onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE songs (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT NOT NULL,
        audioFilePath TEXT
      )
      '''
    );
  }

  Future open() async {
    await deleteDatabase('music.db');
    db = await openDatabase(
      'music.db',
      version: 11,
      onCreate: this.onCreate
    );
    List<Song> songs = await fetchSongs();
    for (Song song in songs) {
      await insert(song);
    }
  }

  Future insert(Song song) async {
    print('inserting song \'' + song.name + '\'');
    await db.insert('songs', song.toMap());
  }

  Future<Song> getSong(String id) async {
    List<Map> maps = (await db.query(
      'songs',
      columns: ['id', 'name', 'artist', 'album', 'audioFilePath'],
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
      columns: ['id', 'name', 'artist', 'album', 'audioFilePath'],
    ));
    List<Song> songs = List<Song>();
    for (Map map in maps) {
      songs.add(Song.fromMap(map));
    }
    return songs;
  }
}
