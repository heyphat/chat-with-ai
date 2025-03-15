// This is a stub file used when the app is not running on the web platform
// It provides empty implementations that mirror the dart:html API we're using
// so that our code can compile on non-web platforms.

class Blob {
  Blob(List<dynamic> data);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  String href = '';
  String download = '';
  String style = '';

  void click() {}
}

class Document {
  List<dynamic> children = [];
  Element? body;
}

class Element {
  List<dynamic> children = [];
  void add(dynamic child) {}
  void remove(dynamic child) {}
}

// Add more stub classes as needed 