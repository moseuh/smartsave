// lib/html_stub.dart
class FileUploadInputElement {
  String? accept;
  List<dynamic> get files => [];
  void click() {}
  Stream get onChange => Stream.empty();
}

class FileReader {
  dynamic result;
  void readAsArrayBuffer(dynamic file) {}
  Stream get onLoadEnd => Stream.empty();
}

class Url {
  static String createObjectUrlFromBlob(dynamic blob) => '';
  static void revokeObjectUrl(String url) {}
}

class Blob {
  Blob(List<dynamic> parts);
}