import 'package:flutter/foundation.dart';

/// Centralized error logging utility
class ErrorLogger {
  ErrorLogger._();

  /// Log error to console and analytics
  static void logError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
  }) {
    if (kDebugMode) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔴 ERROR${context != null ? ' in $context' : ''}');
      print('Error: $error');
      if (stackTrace != null) {
        print('Stack Trace:\n$stackTrace');
      }
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }

    // In production, send to crash reporting service
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }

  /// Log info message
  static void logInfo(String message, {String? context}) {
    if (kDebugMode) {
      print('ℹ️ INFO${context != null ? ' [$context]' : ''}: $message');
    }
  }

  /// Log warning
  static void logWarning(String message, {String? context}) {
    if (kDebugMode) {
      print('⚠️ WARNING${context != null ? ' [$context]' : ''}: $message');
    }
  }

  /// Log success
  static void logSuccess(String message, {String? context}) {
    if (kDebugMode) {
      print('✅ SUCCESS${context != null ? ' [$context]' : ''}: $message');
    }
  }

  /// Log API request
  static void logApiRequest(String method, String endpoint, {Map<String, dynamic>? body}) {
    if (kDebugMode) {
      print('🌐 API $method: $endpoint');
      if (body != null) {
        print('   Body: $body');
      }
    }
  }

  /// Log API response
  static void logApiResponse(int statusCode, dynamic body) {
    if (kDebugMode) {
      print('📥 API Response [$statusCode]: $body');
    }
  }
}
