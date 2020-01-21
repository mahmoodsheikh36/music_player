import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const bool kReleaseMode =
  bool.fromEnvironment('dart.vm.product', defaultValue: false);

class Files {

  static Future<String> getAppDir() async {
    String path = (await getExternalStorageDirectory()).path;
    return kReleaseMode ? path : path + '/debug';
  }

  static Future<dynamic> downloadFile(String url, String localPath) async {
    File file = new File((await getAbsoluteFilePath(localPath)));
    if (!(await file.exists()))
      await file.create(recursive: true);
    var request = await http.get(url,);
    var bytes = request.bodyBytes;
    await file.writeAsBytes(bytes);
    print('downloaded to ' + localPath);
  }

  static Future<String> getAbsoluteFilePath(String path) async {
    print((await getAppDir()) + "/" + path);
    return (await getAppDir()) + "/" + path;
  }
}
