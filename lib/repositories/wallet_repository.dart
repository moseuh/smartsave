import '../models/mpesa_usage_model.dart';
import '../services/api_service.dart';

/// Repository for M-Pesa and wallet operations
class WalletRepository {
  final ApiService _apiService;

  WalletRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Get M-Pesa usage data
  Future<MpesaUsage?> getMpesaUsage(String userId) async {
    try {
      final response = await _apiService.get('/mpesa-usage/$userId');

      if (response != null && response['status'] == 'success') {
        final data = response['data'] ?? response;
        return MpesaUsage.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error fetching M-Pesa usage: $e');
      return null;
    }
  }

  /// Get wallet balance
  Future<Map<String, dynamic>?> getWalletData(String userId) async {
    try {
      final response = await _apiService.get('/wallet/$userId');

      if (response != null && response['status'] == 'success') {
        return response['data'] ?? response;
      }
      return null;
    } catch (e) {
      print('Error fetching wallet data: $e');
      return null;
    }
  }

  /// Get roundup settings
  Future<Map<String, dynamic>?> getRoundupSettings(String userId) async {
    try {
      final response = await _apiService.get('/roundup-settings/$userId');
      return response;
    } catch (e) {
      print('Error fetching roundup settings: $e');
      return null;
    }
  }

  /// Update roundup settings
  Future<bool> updateRoundupSettings({
    required String userId,
    required bool enabled,
    Map<String, dynamic>? additionalSettings,
  }) async {
    try {
      final response = await _apiService.post(
        '/roundup-settings',
        body: {
          'user_id': userId,
          'enabled': enabled,
          ...?additionalSettings,
        },
      );

      return response != null && response['status'] == 'success';
    } catch (e) {
      print('Error updating roundup settings: $e');
      rethrow;
    }
  }

  /// Send remittance
  Future<Map<String, dynamic>?> sendRemittance({
    required String userId,
    required double amount,
    required String currency,
    required String provider,
    required String phone,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final response = await _apiService.post(
        '/remittance',
        body: {
          'user_id': int.parse(userId),
          'amount': amount.toInt(),
          'currency': currency,
          'provider': provider,
          'phone': phone,
          'first_name': firstName,
          'last_name': lastName,
        },
      );

      return response;
    } catch (e) {
      print('Error sending remittance: $e');
      rethrow;
    }
  }

  /// Get favourites
  Future<List<Map<String, dynamic>>> getFavourites(String userId) async {
    try {
      final response = await _apiService.get('/favourites/$userId');

      if (response != null && response['status'] == 'success') {
        final favourites = response['favourites'] as List?;
        if (favourites != null) {
          return favourites.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching favourites: $e');
      return [];
    }
  }

  /// Add favourite
  Future<bool> addFavourite({
    required String userId,
    required String name,
    required String tillNumber,
  }) async {
    try {
      final response = await _apiService.post(
        '/favourites',
        body: {
          'user_id': userId,
          'name': name,
          'till_number': tillNumber,
        },
      );

      return response != null && response['status'] == 'success';
    } catch (e) {
      print('Error adding favourite: $e');
      rethrow;
    }
  }

  /// Delete favourite
  Future<bool> deleteFavourite(String favouriteId) async {
    try {
      final response = await _apiService.delete('/favourites/$favouriteId');
      return response != null && response['status'] == 'success';
    } catch (e) {
      print('Error deleting favourite: $e');
      rethrow;
    }
  }
}
