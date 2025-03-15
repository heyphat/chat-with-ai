import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Save a file on web platform
void saveFileOnWeb(String content, String fileName) {
  // Convert content to bytes
  final bytes = Uint8List.fromList(utf8.encode(content));

  // Create a blob and URL
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);

  // Create an anchor element to trigger download
  final anchor =
      html.AnchorElement()
        ..href = url
        ..style.display = 'none'
        ..download = fileName;

  // Add to DOM, trigger click, and clean up
  html.document.body!.children.add(anchor);
  anchor.click();
  html.document.body!.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}
