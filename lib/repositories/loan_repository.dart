import '../models/loan_model.dart';
import '../services/api_service.dart';

/// Repository for loan-related operations
class LoanRepository {
  final ApiService _apiService;

  LoanRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Get all loans for a user
  Future<List<Loan>> getLoans(String userId) async {
    try {
      final response = await _apiService.get('/loans/$userId');

      if (response != null && response['status'] == 'success') {
        final loans = response['loans'] as List?;
        if (loans != null) {
          return loans.map((json) => Loan.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching loans: $e');
      return [];
    }
  }

  /// Check loan eligibility
  Future<Map<String, dynamic>?> checkEligibility(String userId) async {
    try {
      final response = await _apiService.get('/loan-eligibility/$userId');
      return response;
    } catch (e) {
      print('Error checking loan eligibility: $e');
      return null;
    }
  }

  /// Apply for a loan
  Future<Loan?> applyForLoan({
    required String userId,
    required double amount,
    required int durationMonths,
    String? purpose,
  }) async {
    try {
      final response = await _apiService.post(
        '/apply-loan',
        body: {
          'user_id': userId,
          'amount': amount,
          'duration_months': durationMonths,
          'purpose': purpose,
        },
      );

      if (response != null && response['status'] == 'success') {
        return Loan.fromJson(response['loan'] ?? response);
      }
      return null;
    } catch (e) {
      print('Error applying for loan: $e');
      rethrow;
    }
  }

  /// Repay loan
  Future<bool> repayLoan({
    required String loanId,
    required String userId,
    required double amount,
  }) async {
    try {
      final response = await _apiService.post(
        '/repay-loan',
        body: {
          'loan_id': loanId,
          'user_id': userId,
          'amount': amount,
        },
      );

      return response != null && response['status'] == 'success';
    } catch (e) {
      print('Error repaying loan: $e');
      rethrow;
    }
  }

  /// Request bank loan
  Future<bool> requestBankLoan({
    required String userId,
    required double amount,
    required int durationMonths,
    required Map<String, dynamic> additionalData,
  }) async {
    try {
      final response = await _apiService.post(
        '/bank-loan-request',
        body: {
          'user_id': userId,
          'amount': amount,
          'duration_months': durationMonths,
          ...additionalData,
        },
      );

      return response != null && response['status'] == 'success';
    } catch (e) {
      print('Error requesting bank loan: $e');
      rethrow;
    }
  }

  /// Get pending loans
  Future<List<Loan>> getPendingLoans() async {
    try {
      final response = await _apiService.get('/pending-loans');

      if (response != null && response['status'] == 'success') {
        final loans = response['loans'] as List?;
        if (loans != null) {
          return loans.map((json) => Loan.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching pending loans: $e');
      return [];
    }
  }
}
