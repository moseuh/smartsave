import 'package:flutter/foundation.dart';
import '../models/savings_goal_model.dart';
import '../repositories/savings_repository.dart';

/// Savings state management with clean architecture
class SavingsProvider with ChangeNotifier {
  final SavingsRepository _savingsRepository;

  SavingsProvider({SavingsRepository? savingsRepository})
      : _savingsRepository = savingsRepository ?? SavingsRepository();

  bool _isLoading = false;
  double _totalSavings = 0.0;
  List<double> _savingsHistory = List.filled(7, 0.0);
  List<SavingsGoal> _goals = [];
  List<Map<String, dynamic>> _recentSavings = [];
  List<Map<String, dynamic>> _leaderboard = [];
  String? _errorMessage;

  bool get isLoading => _isLoading;
  double get totalSavings => _totalSavings;
  List<double> get savingsHistory => _savingsHistory;
  List<SavingsGoal> get goals => _goals;
  List<Map<String, dynamic>> get recentSavings => _recentSavings;
  List<Map<String, dynamic>> get leaderboard => _leaderboard;
  String? get errorMessage => _errorMessage;

  /// Load all savings data for a user
  Future<void> loadSavingsData(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadTotalSavings(userId),
        _loadSavingsHistory(userId),
        _loadGoals(userId),
        _loadRecentSavings(userId),
      ]);
    } catch (e) {
      _errorMessage = 'Error loading savings data: ${e.toString()}';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadTotalSavings(String userId) async {
    try {
      _totalSavings = await _savingsRepository.getTotalSavings(userId);
    } catch (e) {
      debugPrint('Error loading total savings: $e');
    }
  }

  Future<void> _loadSavingsHistory(String userId) async {
    try {
      _savingsHistory = await _savingsRepository.getSavingsHistory(userId);
    } catch (e) {
      debugPrint('Error loading savings history: $e');
    }
  }

  Future<void> _loadGoals(String userId) async {
    try {
      _goals = await _savingsRepository.getGoals(userId);
    } catch (e) {
      debugPrint('Error loading goals: $e');
    }
  }

  Future<void> _loadRecentSavings(String userId) async {
    try {
      _recentSavings = await _savingsRepository.getRecentSavings(userId);
    } catch (e) {
      debugPrint('Error loading recent savings: $e');
    }
  }

  /// Create a new savings goal
  Future<bool> createGoal({
    required String userId,
    required String title,
    required double targetAmount,
    required DateTime targetDate,
    String? description,
    String? category,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final goal = await _savingsRepository.createGoal(
        userId: userId,
        title: title,
        targetAmount: targetAmount,
        targetDate: targetDate,
        description: description,
        category: category,
      );

      if (goal != null) {
        _goals.add(goal);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = 'Failed to create goal';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error creating goal: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Contribute to a goal
  Future<bool> contributeToGoal({
    required String goalId,
    required String userId,
    required double amount,
  }) async {
    try {
      final success = await _savingsRepository.contributeToGoal(
        goalId: goalId,
        userId: userId,
        amount: amount,
      );

      if (success) {
        // Refresh goals and total savings
        await _loadGoals(userId);
        await _loadTotalSavings(userId);
      }

      return success;
    } catch (e) {
      _errorMessage = 'Error contributing to goal: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Join a challenge
  Future<bool> joinChallenge({
    required String challengeId,
    required String userId,
  }) async {
    try {
      return await _savingsRepository.joinChallenge(
        challengeId: challengeId,
        userId: userId,
      );
    } catch (e) {
      _errorMessage = 'Error joining challenge: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Load leaderboard
  Future<void> loadLeaderboard() async {
    try {
      _leaderboard = await _savingsRepository.getLeaderboard();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading leaderboard: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Load top weekly leaderboard
  Future<void> loadTopWeeklyLeaderboard() async {
    try {
      _leaderboard = await _savingsRepository.getTopWeeklyLeaderboard();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading leaderboard: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
