import '../models/savings_goal_model.dart';
import '../services/api_service.dart';

/// Repository for savings-related operations
class SavingsRepository {
  final ApiService _apiService;

  SavingsRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Get user's total savings
  Future<double> getTotalSavings(String userId) async {
    try {
      final response = await _apiService.get('/user-savings/$userId');

      if (response != null && response['status'] == 'success') {
        final data = response['data'] ?? response;
        return double.tryParse(data['total_savings']?.toString() ?? '0') ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      print('Error fetching total savings: $e');
      rethrow;
    }
  }

  /// Get savings history
  Future<List<double>> getSavingsHistory(String userId) async {
    try {
      final response = await _apiService.get('/savings-history/$userId');

      if (response != null && response['status'] == 'success') {
        final history = response['history'] as List?;
        if (history != null) {
          return history
              .map((e) => double.tryParse(e.toString()) ?? 0.0)
              .toList();
        }
      }
      return List.filled(7, 0.0);
    } catch (e) {
      print('Error fetching savings history: $e');
      return List.filled(7, 0.0);
    }
  }

  /// Get recent savings transactions
  Future<List<Map<String, dynamic>>> getRecentSavings(String userId) async {
    try {
      final response = await _apiService.get('/savings-recent/$userId');

      if (response != null && response['status'] == 'success') {
        final savings = response['savings'] as List?;
        if (savings != null) {
          return savings.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching recent savings: $e');
      return [];
    }
  }

  /// Get all goals for a user
  Future<List<SavingsGoal>> getGoals(String userId) async {
    try {
      final response = await _apiService.get('/goalslist/$userId');

      if (response != null && response['status'] == 'success') {
        final goals = response['goals'] as List?;
        if (goals != null) {
          return goals
              .map((json) => SavingsGoal.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching goals: $e');
      return [];
    }
  }

  /// Create a new savings goal
  Future<SavingsGoal?> createGoal({
    required String userId,
    required String title,
    required double targetAmount,
    required DateTime targetDate,
    String? description,
    String? category,
  }) async {
    try {
      final response = await _apiService.post(
        '/goalscreate',
        body: {
          'user_id': userId,
          'title': title,
          'target_amount': targetAmount,
          'target_date': targetDate.toIso8601String(),
          'description': description,
          'category': category,
        },
      );

      if (response != null && response['status'] == 'success') {
        return SavingsGoal.fromJson(response['goal'] ?? response);
      }
      return null;
    } catch (e) {
      print('Error creating goal: $e');
      rethrow;
    }
  }

  /// Contribute to a goal
  Future<bool> contributeToGoal({
    required String goalId,
    required String userId,
    required double amount,
  }) async {
    try {
      final response = await _apiService.post(
        '/challengescontribute',
        body: {
          'goal_id': goalId,
          'user_id': userId,
          'amount': amount,
        },
      );

      return response != null && response['status'] == 'success';
    } catch (e) {
      print('Error contributing to goal: $e');
      rethrow;
    }
  }

  /// Join a challenge
  Future<bool> joinChallenge({
    required String challengeId,
    required String userId,
  }) async {
    try {
      final response = await _apiService.post(
        '/challengesjoin',
        body: {
          'challenge_id': challengeId,
          'user_id': userId,
        },
      );

      return response != null && response['status'] == 'success';
    } catch (e) {
      print('Error joining challenge: $e');
      rethrow;
    }
  }

  /// Get leaderboard
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    try {
      final response = await _apiService.get('/leaderboard');

      if (response != null && response['status'] == 'success') {
        final leaderboard = response['leaderboard'] as List?;
        if (leaderboard != null) {
          return leaderboard.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching leaderboard: $e');
      return [];
    }
  }

  /// Get top 10 weekly leaderboard
  Future<List<Map<String, dynamic>>> getTopWeeklyLeaderboard() async {
    try {
      final response = await _apiService.get('/leaderboard/top-10-weekly');

      if (response != null && response['status'] == 'success') {
        final leaderboard = response['leaderboard'] as List?;
        if (leaderboard != null) {
          return leaderboard.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching weekly leaderboard: $e');
      return [];
    }
  }
}
