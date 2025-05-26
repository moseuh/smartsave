import 'dart:html' as html;

class WebUtils {
  static String createObjectUrlFromBlob(List<int> bytes) {
    final blob = html.Blob([bytes]);
    return html.Url.createObjectUrlFromBlob(blob);
  }

  static void revokeObjectUrl(String url) {
    html.Url.revokeObjectUrl(url);
  }
}