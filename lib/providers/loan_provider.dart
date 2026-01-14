import 'package:flutter/foundation.dart';
import '../models/loan_model.dart';
import '../repositories/loan_repository.dart';

/// Loan state management with clean architecture
class LoanProvider with ChangeNotifier {
  final LoanRepository _loanRepository;

  LoanProvider({LoanRepository? loanRepository})
      : _loanRepository = loanRepository ?? LoanRepository();

  bool _isLoading = false;
  List<Loan> _loans = [];
  Map<String, dynamic>? _eligibility;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  List<Loan> get loans => _loans;
  List<Loan> get activeLoans => _loans.where((l) => l.isActive).toList();
  List<Loan> get pendingLoans => _loans.where((l) => l.isPending).toList();
  Map<String, dynamic>? get eligibility => _eligibility;
  String? get errorMessage => _errorMessage;
  bool get isEligible => _eligibility?['eligible'] == true;

  /// Load all loan data for a user
  Future<void> loadLoanData(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadLoans(userId),
        _loadEligibility(userId),
      ]);
    } catch (e) {
      _errorMessage = 'Error loading loan data: ${e.toString()}';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadLoans(String userId) async {
    try {
      _loans = await _loanRepository.getLoans(userId);
    } catch (e) {
      debugPrint('Error loading loans: $e');
    }
  }

  Future<void> _loadEligibility(String userId) async {
    try {
      _eligibility = await _loanRepository.checkEligibility(userId);
    } catch (e) {
      debugPrint('Error checking eligibility: $e');
    }
  }

  /// Apply for a loan
  Future<bool> applyForLoan({
    required String userId,
    required double amount,
    required int durationMonths,
    String? purpose,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loan = await _loanRepository.applyForLoan(
        userId: userId,
        amount: amount,
        durationMonths: durationMonths,
        purpose: purpose,
      );

      if (loan != null) {
        _loans.add(loan);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = 'Loan application failed';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error applying for loan: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Repay loan
  Future<bool> repayLoan({
    required String loanId,
    required String userId,
    required double amount,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _loanRepository.repayLoan(
        loanId: loanId,
        userId: userId,
        amount: amount,
      );

      if (success) {
        // Refresh loans
        await _loadLoans(userId);
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Error repaying loan: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Request bank loan
  Future<bool> requestBankLoan({
    required String userId,
    required double amount,
    required int durationMonths,
    required Map<String, dynamic> additionalData,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _loanRepository.requestBankLoan(
        userId: userId,
        amount: amount,
        durationMonths: durationMonths,
        additionalData: additionalData,
      );

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Error requesting bank loan: ${e.toString()}';
      _isLoading = false;
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
