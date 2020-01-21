import 'package:player/database.dart';
import 'package:player/datacollection.dart';
import 'package:player/song.dart';

Future<Map<Song, double>> getSecondsListenedToAllSongs(DbProvider dbProvider,
                                                       int songCount) async {
  final map = <Song, double>{};
  List<Song> songs = await dbProvider.getAllSongs();
  for (int i = 0; i < songCount && i < songs.length; ++i) {
    Song song = songs[i];
  }
}

Future<double> getSecondsListenedToSong(DbProvider dbProvider, int songId) async {
  double seconds = 0;
  List<Playback> playbacks = await dbProvider.getPlaybacksForSong(songId);
  for (Playback playback in playbacks) {
    if (playback.endTimestamp > 0)
      seconds += (playback.endTimestamp - playback.startTimestamp) / 1000;
  }
  return seconds;
}
