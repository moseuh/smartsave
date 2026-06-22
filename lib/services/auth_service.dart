import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Authentication service for Firebase and Google Sign-In
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '825042983512-b3eea0b1eg88hvqks2c7d0i989tj79qf.apps.googleusercontent.com'
        : null,
    serverClientId: '1020426440691-2h1lkmu995u590m9rh6g1ffbrktmaa4v.apps.googleusercontent.com',
  );

  User? get currentUser => _firebaseAuth.currentUser;
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Save user info
      await _saveUserInfo(credential.user);
      
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  /// Sign up with email and password
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name if provided
      if (displayName != null && credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
      }
      
      // Save user info
      await _saveUserInfo(credential.user);
      
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled');
      }

      // Obtain the auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      
      // Save user info
      await _saveUserInfo(userCredential.user);
      
      return userCredential;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      throw Exception('Failed to sign in with Google: ${e.toString()}');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.signOut(),
      ]);
      
      // Clear saved user info
      await _clearUserInfo();
    } catch (e) {
      debugPrint('Sign out error: $e');
      throw Exception('Failed to sign out');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  /// Save user info to SharedPreferences
  Future<void> _saveUserInfo(User? user) async {
    if (user == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userIdKey, user.uid);
    await prefs.setString(AppConstants.userEmailKey, user.email ?? '');
    await prefs.setBool(AppConstants.isLoggedInKey, true);
    
    // Get and save ID token
    final token = await user.getIdToken();
    if (token != null) {
      await prefs.setString(AppConstants.userTokenKey, token);
    }
  }

  /// Clear user info from SharedPreferences
  Future<void> _clearUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userIdKey);
    await prefs.remove(AppConstants.userEmailKey);
    await prefs.remove(AppConstants.userTokenKey);
    await prefs.setBool(AppConstants.isLoggedInKey, false);
  }

  /// Handle Firebase errors
  String _handleFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
