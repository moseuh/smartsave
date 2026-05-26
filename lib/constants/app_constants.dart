import '../config/api_config.dart';

/// Application-wide constants
class AppConstants {
  AppConstants._();

  // All API calls go through ApiConfig — change useLocalServer there to switch environments
  static String get apiBaseUrl => ApiConfig.baseUrl;

  // App Configuration
  static const String appName = 'Nebo';
  static const String appVersion = '1.0.0';

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 15);

  // Error Messages
  static const String networkError = 'Network error. Please check your connection.';
  static const String serverError = 'Server error. Please try again later.';
  static const String unknownError = 'An unexpected error occurred.';
  static const String timeoutError = 'Request timed out. Please try again.';
  static const String authError = 'Authentication failed. Please login again.';

  // Storage Keys
  static const String userTokenKey = 'user_token';
  static const String userIdKey = 'user_id';
  static const String userEmailKey = 'user_email';
  static const String isLoggedInKey = 'is_logged_in';

  // Validation
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 50;
}
