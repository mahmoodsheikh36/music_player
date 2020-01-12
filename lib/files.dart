import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class Files {

  static Future<String> getAppDir() async {
    return (await getApplicationDocumentsDirectory()).path;
  }

  static Future<dynamic> downloadFile(String url, String localPath) async {
    File file = new File((await getAbsoluteFilePath(localPath)));
    if (!(await file.exists()))
      await file.create(recursive: true);
    var request = await http.get(url,);
    var bytes = request.bodyBytes;
    await file.writeAsBytes(bytes);
    print(file.path);
  }

  static Future<String> getAbsoluteFilePath(String path) async {
    return (await getAppDir()) + "/" + path;
  }
}
