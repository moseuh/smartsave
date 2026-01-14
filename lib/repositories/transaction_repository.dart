import '../models/transaction_model.dart';
import '../services/api_service.dart';

/// Repository for transaction-related operations
class TransactionRepository {
  final ApiService _apiService;

  TransactionRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Get all transactions for a user
  Future<List<Transaction>> getTransactions(String userId) async {
    try {
      final response = await _apiService.get('/transactions/$userId');

      if (response != null && response['status'] == 'success') {
        final transactions = response['transactions'] as List?;
        if (transactions != null) {
          return transactions
              .map((json) => Transaction.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }

  /// Get last payment transaction
  Future<Transaction?> getLastPayment(String userId) async {
    try {
      final response = await _apiService.get('/last-payment/$userId');

      if (response != null && response['status'] == 'success') {
        final data = response['payment'] ?? response;
        return Transaction.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error fetching last payment: $e');
      return null;
    }
  }

  /// Get transaction status
  Future<Map<String, dynamic>?> getTransactionStatus(String transactionId) async {
    try {
      final response = await _apiService.get('/transaction-status/$transactionId');
      return response;
    } catch (e) {
      print('Error fetching transaction status: $e');
      return null;
    }
  }

  /// Process paybill payment
  Future<Map<String, dynamic>?> processPaybillPayment({
    required String userId,
    required String businessNumber,
    required String accountNumber,
    required double amount,
  }) async {
    try {
      final response = await _apiService.post(
        '/process-paybill-payment',
        body: {
          'user_id': userId,
          'business_number': businessNumber,
          'account_number': accountNumber,
          'amount': amount,
        },
      );

      return response;
    } catch (e) {
      print('Error processing paybill payment: $e');
      rethrow;
    }
  }

  /// Get buy goods payments
  Future<List<Map<String, dynamic>>> getBuyGoodsPayments(String userId) async {
    try {
      final response = await _apiService.get('/buy-goods-payments?userId=$userId');

      if (response != null && response['status'] == 'success') {
        final payments = response['payments'] as List?;
        if (payments != null) {
          return payments.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching buy goods payments: $e');
      return [];
    }
  }
}
