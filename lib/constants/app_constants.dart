/// Application-wide constants
class AppConstants {
  AppConstants._();

  // API Configuration
  // Change this to your local XAMPP/WAMP server
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://apis.nebo.co.ke/apis',
  );

  // API Endpoints
  static const String loginEndpoint = '/login';
  static const String registerEndpoint = '/register';
  static const String userProfileEndpoint = '/user/profile';
  static const String transactionsEndpoint = '/transactions';
  static const String goalsEndpoint = '/goals';
  static const String loansEndpoint = '/loans';
  static const String mpesaPaymentEndpoint = '/mpesa/payment';
  static const String walletEndpoint = '/wallet';

  // App Configuration
  static const String appName = 'SmartSave';
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
