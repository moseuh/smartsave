import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';

/// Authentication state and business logic with clean architecture
class AuthProvider with ChangeNotifier {
  final UserRepository _userRepository;
  
  bool _isAuthenticated = false;
  bool _isLoading = false;
  User? _currentUser;
  String? _errorMessage;

  AuthProvider({UserRepository? userRepository})
      : _userRepository = userRepository ?? UserRepository();

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  User? get currentUser => _currentUser;
  String? get userId => _currentUser?.id;
  String? get userEmail => _currentUser?.email;
  String? get errorMessage => _errorMessage;

  /// Initialize authentication state from storage
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString('user_id');
      
      if (storedUserId != null && storedUserId.isNotEmpty) {
        _currentUser = await _userRepository.getUserDetails(storedUserId);
        _isAuthenticated = _currentUser != null;
      }
    } catch (e) {
      print('Error initializing auth: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _userRepository.loginUser(
        email: email,
        password: password,
      );

      if (response != null && response['status'] == 'success') {
        final userId = response['userId']?.toString();
        if (userId != null) {
          // Fetch full user details
          _currentUser = await _userRepository.getUserDetails(userId);
          _isAuthenticated = _currentUser != null;

          // Store in SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', userId);
          await prefs.setString('email', email);
          if (_currentUser != null) {
            await prefs.setString('user_name', _currentUser!.fullName);
            if (_currentUser!.selfiePath != null) {
              await prefs.setString('selfie_path', _currentUser!.selfiePath!);
            }
          }

          _isLoading = false;
          notifyListeners();
          return true;
        }
      } else {
        _errorMessage = response['message'] ?? 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign up with email and password
  Future<bool> signUpWithEmail(String email, String password, String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        AppConstants.registerEndpoint,
        body: {
          'email': email,
          'password': password,
          'name': name,
        },
        requiresAuth: false,
      );

      if (response != null && response['success'] == true) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _isAuthenticated = false;
    _userId = null;
    _userEmail = null;
    _apiService.clearAuthToken();
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
