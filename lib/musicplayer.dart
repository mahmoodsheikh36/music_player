import 'package:audioplayer/audioplayer.dart'; // is this needed?

import 'song.dart';
import 'files.dart';

class MusicPlayer extends AudioPlayer {
  static MusicPlayer _globalInstance = new MusicPlayer();

  static MusicPlayer getGlobalInstance() {
    return _globalInstance;
  }

  Future<void> playRemote(String url) async {
    await super.play(url);
    // setState(() => playerState = PlayerState.playing);
  }

  Future<void> playLocal(String path) async {
    await super.play((await Files.getAbsoluteFilePath(path)), isLocal: true);
  }

  Future<void> playSong(Song song) async {
    if (!song.audioExistsLocally()) {
      print('downloading audio file for \'' + song.name + '\'');
      await song.downloadAudioFile();
    }
    playLocal(song.audioFilePath);
  }

  Future<void> pause() async {
    await super.pause();
    // setState(() => playerState = PlayerState.paused);
  }

  Future<void> stop() async {
    await super.stop();
    // setState(() {
    //     playerState = PlayerState.stopped;
    //     position = new Duration();
    // });
  }
}
