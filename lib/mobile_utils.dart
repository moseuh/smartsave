class WebUtils {
  static String createObjectUrlFromBlob(List<int> bytes) {
    throw UnsupportedError('This operation is only supported on the web.');
  }

  static void revokeObjectUrl(String url) {
    // No-op (do nothing) on mobile platforms
  }
}