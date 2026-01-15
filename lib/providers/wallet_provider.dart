import 'package:flutter/foundation.dart';
import '../models/mpesa_usage_model.dart';
import '../repositories/wallet_repository.dart';

/// Wallet state management with clean architecture
class WalletProvider with ChangeNotifier {
  final WalletRepository _walletRepository;

  WalletProvider({WalletRepository? walletRepository})
      : _walletRepository = walletRepository ?? WalletRepository();

  bool _isLoading = false;
  MpesaUsage? _mpesaUsage;
  Map<String, dynamic>? _walletData;
  List<Map<String, dynamic>> _favourites = [];
  String? _errorMessage;

  bool get isLoading => _isLoading;
  MpesaUsage? get mpesaUsage => _mpesaUsage;
  Map<String, dynamic>? get walletData => _walletData;
  List<Map<String, dynamic>> get favourites => _favourites;
  String? get errorMessage => _errorMessage;
  double get balance => _walletData?['balance'] ?? 0.0;

  /// Load all wallet data
  Future<void> loadWalletData(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadMpesaUsage(userId),
        _loadWalletBalance(userId),
        _loadFavourites(userId),
      ]);
    } catch (e) {
      _errorMessage = 'Error loading wallet data: ${e.toString()}';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadMpesaUsage(String userId) async {
    try {
      _mpesaUsage = await _walletRepository.getMpesaUsage(userId);
    } catch (e) {
      debugPrint('Error loading M-Pesa usage: $e');
    }
  }

  Future<void> _loadWalletBalance(String userId) async {
    try {
      _walletData = await _walletRepository.getWalletData(userId);
    } catch (e) {
      debugPrint('Error loading wallet balance: $e');
    }
  }

  Future<void> _loadFavourites(String userId) async {
    try {
      _favourites = await _walletRepository.getFavourites(userId);
    } catch (e) {
      debugPrint('Error loading favourites: $e');
    }
  }

  /// Send remittance
  Future<bool> sendRemittance({
    required String userId,
    required double amount,
    required String currency,
    required String provider,
    required String phone,
    required String firstName,
    required String lastName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _walletRepository.sendRemittance(
        userId: userId,
        amount: amount,
        currency: currency,
        provider: provider,
        phone: phone,
        firstName: firstName,
        lastName: lastName,
      );

      _isLoading = false;
      
      if (response != null && response['status'] == 'success') {
        // Refresh wallet balance
        await _loadWalletBalance(userId);
        notifyListeners();
        return true;
      } else {
        _errorMessage = response?['message'] ?? 'Remittance failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Remittance error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Add favourite
  Future<bool> addFavourite({
    required String userId,
    required String name,
    required String tillNumber,
  }) async {
    try {
      final success = await _walletRepository.addFavourite(
        userId: userId,
        name: name,
        tillNumber: tillNumber,
      );

      if (success) {
        await _loadFavourites(userId);
      }
      
      return success;
    } catch (e) {
      _errorMessage = 'Error adding favourite: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Delete favourite
  Future<bool> deleteFavourite(String favouriteId, String userId) async {
    try {
      final success = await _walletRepository.deleteFavourite(favouriteId);
      
      if (success) {
        await _loadFavourites(userId);
      }
      
      return success;
    } catch (e) {
      _errorMessage = 'Error deleting favourite: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Update roundup settings
  Future<bool> updateRoundupSettings({
    required String userId,
    required bool enabled,
    Map<String, dynamic>? additionalSettings,
  }) async {
    try {
      return await _walletRepository.updateRoundupSettings(
        userId: userId,
        enabled: enabled,
        additionalSettings: additionalSettings,
      );
    } catch (e) {
      _errorMessage = 'Error updating roundup settings: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
