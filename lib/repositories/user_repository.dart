import '../models/user_model.dart';
import '../services/api_service.dart';
import '../constants/app_constants.dart';

/// Repository for user-related data operations
class UserRepository {
  final ApiService _apiService;

  UserRepository({ApiService? apiService}) 
      : _apiService = apiService ?? ApiService();

  /// Fetch user details by ID
  Future<User?> getUserById(String userId) async {
    try {
      final response = await _apiService.get('/user/$userId');
      
      if (response != null && response['status'] == 'success') {
        return User.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error fetching user: $e');
      rethrow;
    }
  }

  /// Fetch user details (alternative endpoint)
  Future<User?> getUserDetails(String userId) async {
    try {
      final response = await _apiService.get('/user-details/$userId');
      
      if (response != null && response['status'] == 'success') {
        final data = response['data'] ?? response;
        return User.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error fetching user details: $e');
      rethrow;
    }
  }

  /// Update user profile
  Future<bool> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      final response = await _apiService.put(
        '/user/$userId',
        body: updates,
      );
      
      return response != null && response['status'] == 'success';
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  /// Upload profile picture
  Future<String?> uploadProfilePicture(String userId, String imagePath) async {
    try {
      // TODO: Implement multipart file upload when ApiService supports it
      // For now, this is a placeholder
      print('Upload profile picture not yet implemented for: $imagePath');
      return null;
    } catch (e) {
      print('Error uploading profile picture: $e');
      rethrow;
    }
  }

  /// Register new user
  Future<Map<String, dynamic>?> registerUser({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String nationalId,
    required String dateOfBirth,
    required String password,
    String? selfiePath,
    String? idDocumentPath,
    String? googleIdToken,
    bool isGoogleSignIn = false,
  }) async {
    try {
      final body = {
        'full_name': fullName,
        'email': email,
        'phone_number': phoneNumber,
        'national_id': nationalId,
        'date_of_birth': dateOfBirth,
        'password': password,
        if (googleIdToken != null) 'google_id_token': googleIdToken,
        if (isGoogleSignIn) 'is_google_sign_in': 'true',
      };

      final response = await _apiService.post(
        '/register',
        body: body,
        requiresAuth: false,
      );

      return response;
    } catch (e) {
      print('Error registering user: $e');
      rethrow;
    }
  }

  /// Login user
  Future<Map<String, dynamic>?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.post(
        '/login',
        body: {
          'email': email,
          'password': password,
        },
        requiresAuth: false,
      );

      return response;
    } catch (e) {
      print('Error logging in: $e');
      rethrow;
    }
  }

  /// Google Sign-In
  Future<Map<String, dynamic>?> googleSignIn({
    required String email,
    required String googleIdToken,
  }) async {
    try {
      final response = await _apiService.post(
        '/login',
        body: {
          'email': email,
          'google_id_token': googleIdToken,
          'is_google_sign_in': true,
        },
        requiresAuth: false,
      );

      return response;
    } catch (e) {
      print('Error with Google sign-in: $e');
      rethrow;
    }
  }
}
