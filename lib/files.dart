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

  static Future saveHttpResponse(http.Response response, String localPath) async {
    File file = new File((await Files.getAbsoluteFilePath(localPath)));
    var bytes = response.bodyBytes;
    if (!(await file.exists()))
      await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    print('saved http response to path ' + localPath);
  }

  static Future<String> getAbsoluteFilePath(String path) async {
    if (path == null)
      return null;
    print((await getAppDir()) + "/" + path);
    return (await getAppDir()) + "/" + path;
  }
}
