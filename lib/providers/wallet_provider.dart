import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../constants/app_constants.dart';

/// Wallet state and business logic
class WalletProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  double _balance = 0.0;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _transactions = [];

  double get balance => _balance;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get transactions => _transactions;

  /// Fetch wallet balance
  Future<void> fetchBalance() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get(AppConstants.walletEndpoint);
      
      if (response != null && response['balance'] != null) {
        _balance = double.tryParse(response['balance'].toString()) ?? 0.0;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch transaction history
  Future<void> fetchTransactions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get(AppConstants.transactionsEndpoint);
      
      if (response != null && response['transactions'] != null) {
        _transactions = List<Map<String, dynamic>>.from(response['transactions']);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
