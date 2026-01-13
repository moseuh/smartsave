import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'SetSavingsGoalScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/graph.dart'; // Assuming this is your SavingsDashboard page

class GoalsDashboard extends StatefulWidget {
  final String userId;
  const GoalsDashboard({super.key, required this.userId});

  @override
  State<GoalsDashboard> createState() => _GoalsDashboardState();
}

class _GoalsDashboardState extends State<GoalsDashboard> {
  List<Map<String, dynamic>> goals = [];
  List<String> badges = [];
  bool isLoading = false;
  double currentSavings = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAllData();
    });
  }

  Future<void> _fetchAllData() async {
    setState(() => isLoading = true);
    await Future.wait([
      _retryApiCall(fetchGoals),
      _retryApiCall(fetchRecentSavings),
      _retryApiCall(loadBadges),
    ]);
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _retryApiCall(Future<void> Function() apiCall) async {
    const maxRetries = 3;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await apiCall();
        return;
      } catch (e) {
        debugPrint('Attempt $attempt failed: $e');
        if (attempt == maxRetries) {
          debugPrint('Max retries reached for API call');
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

Future<void> fetchGoals() async {
  try {
    final response = await http.get(
      Uri.parse('http://apis.nebo.co.ke/apis/goalslist/${widget.userId}'),
      headers: {"Content-Type": "application/json"},
    ).timeout(const Duration(seconds: 15));

    debugPrint('Goals API Status: ${response.statusCode}');
    debugPrint('Goals API Body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Server returned ${response.statusCode}');
    }

    // THIS IS THE ONLY CHANGE YOU NEED
    final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

    if (jsonResponse['status'] != 'success' || jsonResponse['data'] is! List) {
      throw Exception('Invalid response format');
    }

    final List<dynamic> rawGoals = jsonResponse['data'];

    if (mounted) {
      setState(() {
        goals = rawGoals.map<Map<String, dynamic>>((g) {
          return {
            'id': g['id']?.toString() ?? '',
            'goal_type': (g['goal_type']?.toString().trim().isNotEmpty == true)
                ? g['goal_type'].toString().trim()
                : 'General',
            'goal_name': (g['goal_name']?.toString().trim().isNotEmpty == true)
                ? g['goal_name'].toString().trim()
                : 'My Savings Goal #${g['id']}',
            'goal_amount': (g['goal_amount'] as num?)?.toDouble() ?? 10000.0,
            'duration_days': (g['duration_days'] as int?) ?? 30,
            'created_at': g['created_at']?.toString() ?? DateTime.now().toString(),
            'selected_option': g['selected_option']?.toString(),
          };
        }).toList();

        debugPrint('Goals successfully loaded: $goals');
      });
    }
  } catch (e) {
    debugPrint('Error fetching goals: $e');
    if (mounted) {
      setState(() => goals = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load goals')),
      );
    }
  }
}
  Future<void> fetchRecentSavings() async {
    try {
      final response = await http.get(
        Uri.parse('http://apis.nebo.co.ke/apis/savings-recent/${widget.userId}'),
        headers: {
          "Content-Type": "application/json",
          // "Authorization": "Bearer your_api_token",
        },
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Recent savings request timed out');
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success' && data['data'] is List) {
          if (mounted) {
            setState(() {
              final recentSavings = List<Map<String, dynamic>>.from(data['data']).map((entry) {
                return {
                  'amount': entry['amount'] is num ? entry['amount'].toDouble() : 0.0,
                  'created_at': entry['created_at']?.toString() ?? '',
                };
              }).toList();
              currentSavings = recentSavings.fold(0.0, (sum, item) => sum + item['amount']);
              debugPrint('Recent savings fetched, Total: $currentSavings');
            });
          }
        } else {
          if (mounted) {
            setState(() {
              currentSavings = 0.0;
              debugPrint('No recent savings found: ${data['message']}');
            });
          }
        }
      } else {
        debugPrint('Failed to fetch recent savings: ${response.statusCode}');
        if (mounted) {
          setState(() => currentSavings = 0.0);
        }
      }
    } catch (e) {
      debugPrint('Error fetching recent savings: $e');
      if (mounted) {
        setState(() => currentSavings = 0.0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching recent savings: $e')),
        );
      }
    }
  }

  Future<void> loadBadges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBadges = prefs.getStringList('badges_${widget.userId}') ?? [];
      if (mounted) {
        setState(() {
          badges = savedBadges;
          if (goals.isNotEmpty && !badges.contains('Goal Creator')) {
            badges.add('Goal Creator');
            prefs.setStringList('badges_${widget.userId}', badges);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading badges: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading badges: $e')),
        );
      }
    }
  }

  double calculateProgress(Map<String, dynamic> goal) {
    return goal['goal_amount'] > 0 ? (currentSavings / goal['goal_amount']).clamp(0.0, 1.0) : 0.0;
  }

  double calculateProbability(Map<String, dynamic> goal) {
    final requiredDailySavings = goal['goal_amount'] / goal['duration_days'];
    final daysElapsed = DateTime.now().difference(DateTime.parse(goal['created_at'])).inDays.clamp(0, goal['duration_days']);
    final expectedSavings = requiredDailySavings * daysElapsed;
    return currentSavings >= goal['goal_amount']
        ? 100.0
        : ((currentSavings / expectedSavings) * 100).clamp(0.0, 100.0);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1F2937),
      child: Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: Colors.transparent,
        ),
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF374151),
            elevation: 4,
            title: const Text(
              'Your Goals',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SavingsDashboard(userId: widget.userId),
                  ),
                );
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GoalCreationScreen(userId: widget.userId),
                    ),
                  );
                },
              ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFF5BB1B)))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Badges',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        badges.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'No badges earned yet',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : SizedBox(
                                height: 70,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: badges.map((badge) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                        child: Chip(
                                          label: Text(
                                            badge,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          avatar: Icon(
                                            badge == 'Goal Starter'
                                                ? Icons.star
                                                : badge == 'Consistent Saver'
                                                    ? Icons.savings
                                                    : badge == 'Super Saver'
                                                        ? Icons.trending_up
                                                        : Icons.flag,
                                            color: Colors.black,
                                            size: 18,
                                          ),
                                          backgroundColor: const Color(0xFFF5BB1B),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          elevation: 4,
                                          shadowColor: Colors.black.withOpacity(0.3),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                        const SizedBox(height: 32),
                        const Text(
                          'Your Goals',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        goals.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'No goals created yet. Create one to start tracking!',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : Column(
                                children: goals.map((goal) {
                                  final progress = calculateProgress(goal);
                                  final probability = calculateProbability(goal);
                                  final requiredDailySavings = goal['goal_amount'] / goal['duration_days'];
                                  final daysLeft = (goal['duration_days'] -
                                          DateTime.now().difference(DateTime.parse(goal['created_at'])).inDays)
                                      .clamp(0, goal['duration_days']);

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: Card(
                                      color: const Color(0xFF374151),
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    goal['goal_name'],
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  goal['goal_type'],
                                                  style: const TextStyle(
                                                    color: Color(0xFFF5BB1B),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (goal['selected_option'] != null)
                                              Text(
                                                'Option: ${goal['selected_option']}',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Goal: KSh ${goal['goal_amount'].toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'Saved: KSh ${currentSavings.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'Days Left: $daysLeft',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            LinearProgressIndicator(
                                              value: progress,
                                              backgroundColor: Colors.grey[700],
                                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF5BB1B)),
                                              minHeight: 8,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Progress: ${(progress * 100).toStringAsFixed(1)}%',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'Probability of Success: ${probability.toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                color: probability < 50 ? Colors.red : Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Daily Savings Needed: KSh ${requiredDailySavings.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}