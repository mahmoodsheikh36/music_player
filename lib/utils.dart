import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class Utils {
  static final Random _random = Random.secure();

  static String randomString([int length = 32]) {
    var values = List<int>.generate(length, (i) => _random.nextInt(256));

    return base64Url.encode(values);
  }

  static int currentTime() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  static String secondsToTimeString(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    String str = '';
    if (hours > 0) {
      if (hours == 1)
        str += hours.toString() + ' hr, ';
      else
        str += hours.toString() + ' hrs, ';
    }
    if (minutes > 0) {
      if (minutes == 1)
        str += minutes.toString() + ' min, ';
      else
        str += minutes.toString() + ' mins, ';
    }
    if (seconds > 0) {
      if (seconds == 1)
        str += seconds.toString() + ' sec';
      else
        str += seconds.toString() + ' secs';
    }
    return str;
  }

  /* only supports files in the base assets directory, no need for subdirectories atm */
  static Future<File> getAssetAsFile(String assetName) async {
    var bytes = await rootBundle.load("assets/" + assetName);
    String dir = (await getApplicationDocumentsDirectory()).path;
    String fullPath = '$dir/$assetName';
    await _writeToFile(bytes, fullPath);
    return File(fullPath);
//write to app path
  }

  /* helper function for getAssetAsFile */
  static Future _writeToFile(ByteData data, String path) async {
    final buffer = data.buffer;
    return await File(path).writeAsBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }
}