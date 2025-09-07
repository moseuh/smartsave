import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'graph.dart';

class GoalCreationScreen extends StatefulWidget {
  final String userId;
  const GoalCreationScreen({super.key, required this.userId});

  @override
  State<GoalCreationScreen> createState() => _GoalCreationScreenState();
}

class _GoalCreationScreenState extends State<GoalCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  String? selectedGoalType;
  String? selectedOption;
  double? goalAmount;
  String? goalName;
  int? durationDays;
  List<Map<String, dynamic>> leaderboard = [];
  List<Map<String, dynamic>> recentSavings = [];
  List<String> badges = [];
  bool isLoading = false;
  double currentSavings = 0.0;
  double savingsRate = 0.0;
  double probability = 0.0;

  final List<String> goalTypes = [
    'Save',
    'Save to Invest',
    'Pay Loan',
    'Pay for Event',
    'Pay School Fees',
    'Pay for Shamba',
  ];

  final List<Map<String, dynamic>> loanProviders = [
    {'name': 'HELB', 'description': 'Higher Education Loans Board', 'icon': Icons.school},
    {'name': 'Tala', 'description': 'Mobile-based loans', 'icon': Icons.phone_android},
    {'name': 'Branch', 'description': 'Quick digital loans', 'icon': Icons.account_balance},
    {'name': 'KCB M-Pesa', 'description': 'Bank-backed mobile loans', 'icon': Icons.account_balance_wallet},
  ];

  final List<Map<String, dynamic>> events = [
    {
      'name': 'Nairobi Tech Week',
      'date': '2025-09-10',
      'cost': 5000.0,
      'time': '09:00 AM',
      'image': 'assets/images/tech_week.jpg', // Use local asset or real URL
    },
    {
      'name': 'Charity Marathon',
      'date': '2025-10-15',
      'cost': 2000.0,
      'time': '07:00 AM',
      'image': 'assets/images/marathon.jpg', // Use local asset or real URL
    },
  ];

  final List<Map<String, dynamic>> investments = [
    {
      'name': 'Money Market Fund',
      'description': 'Low-risk, stable returns',
      'expected_return': '8-10% p.a.',
      'icon': Icons.savings,
    },
    {
      'name': 'High-Risk Investment',
      'description': 'Stocks and crypto, high returns',
      'expected_return': '15-25% p.a.',
      'icon': Icons.trending_up,
    },
  ];

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
      _retryApiCall(fetchLeaderboard),
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

  Future<void> fetchLeaderboard() async {
    try {
      final response = await http.get(
        Uri.parse('https://apis.gnmprimesource.co.ke/leaderboard/top-10-weekly'),
        headers: {
          "Content-Type": "application/json",
          // "Authorization": "Bearer your_api_token",
        },
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Leaderboard request timed out');
      });

      debugPrint('Leaderboard API Response Status: ${response.statusCode}');
      debugPrint('Leaderboard API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success' && data['data'] is List) {
          if (mounted) {
            setState(() {
              leaderboard = List<Map<String, dynamic>>.from(data['data']).map((entry) {
                return {
                  'user_name': entry['user_name']?.toString() ?? 'Unknown',
                  'total_savings': entry['total_savings'] is num
                      ? entry['total_savings'].toDouble()
                      : 0.0,
                };
              }).toList();
              debugPrint('Leaderboard fetched: $leaderboard');
            });
          }
        } else {
          if (mounted) {
            setState(() {
              leaderboard = [];
              debugPrint('No leaderboard data found: ${data['message']}');
            });
          }
        }
      } else {
        debugPrint('Failed to fetch leaderboard: ${response.statusCode}');
        if (mounted) {
          setState(() => leaderboard = []);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch leaderboard: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      if (mounted) {
        setState(() => leaderboard = []);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching leaderboard: $e')),
        );
      }
    }
  }

  Future<void> fetchRecentSavings() async {
    try {
      final response = await http.get(
        Uri.parse('https://apis.gnmprimesource.co.ke/savings-recent/${widget.userId}'),
        headers: {
          "Content-Type": "application/json",
          // "Authorization": "Bearer your_api_token",
        },
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Recent savings request timed out');
      });

      debugPrint('Recent Savings API Response Status: ${response.statusCode}');
      debugPrint('Recent Savings API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success' && data['data'] is List) {
          if (mounted) {
            setState(() {
              recentSavings = List<Map<String, dynamic>>.from(data['data']).map((entry) {
                return {
                  'amount': entry['amount'] is num ? entry['amount'].toDouble() : 0.0,
                  'created_at': entry['created_at']?.toString() ?? '',
                };
              }).toList();
              currentSavings = recentSavings.fold(0.0, (sum, item) => sum + item['amount']);
              final recent = recentSavings
                  .where((s) => DateTime.parse(s['created_at']).isAfter(
                        DateTime.now().subtract(const Duration(days: 2)),
                      ))
                  .toList();
              savingsRate = recent.isNotEmpty
                  ? recent.fold(0.0, (sum, item) => sum + item['amount']) / 2
                  : 0.0;
              debugPrint('Recent savings fetched: $recentSavings, Total: $currentSavings, Rate: $savingsRate');
            });
          }
        } else {
          if (mounted) {
            setState(() {
              recentSavings = [];
              currentSavings = 0.0;
              savingsRate = 0.0;
              debugPrint('No recent savings found: ${data['message']}');
            });
          }
        }
      } else {
        debugPrint('Failed to fetch recent savings: ${response.statusCode}');
        if (mounted) {
          setState(() {
            recentSavings = [];
            currentSavings = 0.0;
            savingsRate = 0.0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching recent savings: $e');
      if (mounted) {
        setState(() {
          recentSavings = [];
          currentSavings = 0.0;
          savingsRate = 0.0;
        });
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
          if (!badges.contains('Goal Starter')) {
            badges.add('Goal Starter');
            prefs.setStringList('badges_${widget.userId}', badges);
          }
          final savingsDates = recentSavings
              .map((s) => DateTime.parse(s['created_at']).toString().substring(0, 10))
              .toSet()
              .toList();
          if (savingsDates.length >= 3 && !badges.contains('Consistent Saver')) {
            badges.add('Consistent Saver');
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

  Future<void> showCatalogueDialog(String goalType) async {
    List<Map<String, dynamic>> items;
    String title;
    switch (goalType) {
      case 'Pay Loan':
        items = loanProviders;
        title = 'Select Loan Provider';
        break;
      case 'Pay for Event':
        items = events;
        title = 'Select Event';
        break;
      case 'Save to Invest':
        items = investments;
        title = 'Select Investment';
        break;
      default:
        return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == items.length) {
                return Card(
                  color: const Color(0xFF1F2937),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.add, color: Color(0xFFF5BB1B)),
                    title: const Text(
                      'Create New',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () => Navigator.pop(context, 'Create New'),
                  ),
                );
              }
              final item = items[index];
              return Card(
                color: const Color(0xFF1F2937),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: goalType == 'Pay for Event'
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item['image'],
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('Event image load error: $error');
                              return const Icon(
                                Icons.event,
                                color: Color(0xFFF5BB1B),
                              );
                            },
                          ),
                        )
                      : Icon(item['icon'], color: const Color(0xFFF5BB1B)),
                  title: Text(
                    item['name'],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    goalType == 'Pay for Event'
                        ? '${item['date']} • ${item['time']} • KSh ${item['cost'].toStringAsFixed(0)}'
                        : item['description'] ?? item['expected_return'],
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  onTap: () {
                    if (goalType == 'Pay for Event') {
                      if (mounted) {
                        setState(() {
                          goalName = item['name'];
                          goalAmount = item['cost'].toDouble();
                          durationDays = (DateTime.parse(item['date']).difference(DateTime.now()).inDays).clamp(1, 365);
                        });
                      }
                    }
                    Navigator.pop(context, item['name']);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFF5BB1B))),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        selectedOption = result;
        if (result != 'Create New') {
          goalName = result;
        } else {
          goalName = null;
        }
      });
    }
  }

  Future<void> createGoal() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();
    if (mounted) {
      setState(() => isLoading = true);
    }

    final requiredDailySavings = goalAmount! / durationDays!;
    final daysElapsed = 2;
    final expectedSavings = requiredDailySavings * daysElapsed;
    probability = currentSavings >= goalAmount!
        ? 100.0
        : (savingsRate / requiredDailySavings * 100).clamp(0.0, 100.0);

    if (probability > 80 && !badges.contains('Super Saver')) {
      final prefs = await SharedPreferences.getInstance();
      badges.add('Super Saver');
      await prefs.setStringList('badges_${widget.userId}', badges);
    }

    if (probability < 50 || currentSavings < expectedSavings) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            probability < 50
                ? 'Low probability (${probability.toStringAsFixed(1)}%) of reaching your goal!'
                : 'You are behind schedule! Save more to reach your goal.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }

    try {
      final response = await http.post(
        Uri.parse('https://apis.gnmprimesource.co.ke/goals/create'),
        headers: {
          "Content-Type": "application/json",
          // "Authorization": "Bearer your_api_token",
        },
        body: jsonEncode({
          'user_id': widget.userId,
          'goal_type': selectedGoalType,
          'goal_name': goalName,
          'goal_amount': goalAmount,
          'duration_days': durationDays,
          'selected_option': selectedOption,
        }),
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Create goal request timed out');
      });

      debugPrint('Create Goal API Response Status: ${response.statusCode}');
      debugPrint('Create Goal API Response Body: ${response.body}');

      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal created successfully')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SavingsDashboard(userId: widget.userId),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create goal: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Error creating goal: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating goal: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requiredDailySavings = goalAmount != null && durationDays != null
        ? goalAmount! / durationDays!
        : 0.0;
    final requiredWeeklySavings = requiredDailySavings * 7;
    final requiredMonthlySavings = requiredDailySavings * 30;
    final progress = goalAmount != null && goalAmount! > 0
        ? (currentSavings / goalAmount!).clamp(0.0, 1.0)
        : 0.0;
    final probabilityText = probability.toStringAsFixed(1);

    return Material(
      color: const Color(0xFF1F2937),
      child: Theme(
        data: Theme.of(context).copyWith(
          dropdownMenuTheme: DropdownMenuThemeData(
            textStyle: const TextStyle(color: Colors.white),
            menuStyle: MenuStyle(
              backgroundColor: WidgetStateProperty.all(const Color(0xFF374151)),
              elevation: WidgetStateProperty.all(4),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: const Color(0xFF374151),
            elevation: 4,
            title: const Text(
              'Create a Savings Goal',
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
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFF5BB1B)))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            color: const Color(0xFF374151),
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Goal Type',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFF1F2937),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    value: selectedGoalType,
                                    hint: const Text(
                                      'Select Goal Type',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    items: goalTypes.map((type) {
                                      return DropdownMenuItem(
                                        value: type,
                                        child: Text(
                                          type,
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (mounted) {
                                        setState(() {
                                          selectedGoalType = value;
                                          selectedOption = null;
                                          goalName = null;
                                          goalAmount = null;
                                          durationDays = null;
                                        });
                                      }
                                      if (value == 'Pay Loan' || value == 'Pay for Event' || value == 'Save to Invest') {
                                        showCatalogueDialog(value!);
                                      }
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Please select a goal type';
                                      }
                                      return null;
                                    },
                                  ),
                                  if (selectedGoalType == 'Pay Loan' ||
                                      selectedGoalType == 'Pay for Event' ||
                                      selectedGoalType == 'Save to Invest') ...[
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Selected Option',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      selectedOption ?? 'None selected',
                                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Goal Name',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFF1F2937),
                                      hintText: 'e.g., Vacation Fund',
                                      hintStyle: const TextStyle(color: Colors.white70),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    initialValue: goalName,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a goal name';
                                      }
                                      return null;
                                    },
                                    onSaved: (value) {
                                      goalName = value;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Goal Amount (KSh)',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFF1F2937),
                                      hintText: 'e.g., 10000',
                                      hintStyle: const TextStyle(color: Colors.white70),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                    initialValue: goalAmount?.toString(),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a goal amount';
                                      }
                                      if (double.tryParse(value) == null || double.parse(value) <= 0) {
                                        return 'Please enter a valid amount';
                                      }
                                      return null;
                                    },
                                    onSaved: (value) {
                                      goalAmount = double.parse(value!);
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Duration (Days)',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFF1F2937),
                                      hintText: 'e.g., 10',
                                      hintStyle: const TextStyle(color: Colors.white70),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                    initialValue: durationDays?.toString(),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a duration';
                                      }
                                      if (int.tryParse(value) == null || int.parse(value) <= 0) {
                                        return 'Please enter a valid number of days';
                                      }
                                      return null;
                                    },
                                    onSaved: (value) {
                                      durationDays = int.parse(value!);
                                    },
                                    onChanged: (value) {
                                      if (int.tryParse(value) != null && mounted) {
                                        setState(() {
                                          durationDays = int.parse(value);
                                        });
                                      }
                                    },
                                  ),
                                  if (goalAmount != null && durationDays != null) ...[
                                    const SizedBox(height: 16),
                                    Card(
                                      color: const Color(0xFF374151),
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Savings Plan',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Daily: KSh ${requiredDailySavings.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                                            ),
                                            Text(
                                              'Weekly: KSh ${requiredWeeklySavings.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                                            ),
                                            Text(
                                              'Monthly: KSh ${requiredMonthlySavings.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Goal Progress',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
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
                                              'Progress: ${(progress * 100).toStringAsFixed(1)}% (KSh ${currentSavings.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} / KSh ${goalAmount!.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')})',
                                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Probability of Success: $probabilityText%',
                                              style: TextStyle(
                                                color: probability < 50 ? Colors.red : Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: isLoading ? null : createGoal,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFF5BB1B),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation: 4,
                                      ),
                                      child: isLoading
                                          ? const CircularProgressIndicator(color: Colors.white)
                                          : const Text(
                                              'Create Goal',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
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
                                                      : Icons.trending_up,
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
                            'Weekly Top 10 Savers',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          isLoading
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFFF5BB1B)))
                              : leaderboard.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8.0),
                                      child: Text(
                                        'No leaderboard data available',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    )
                                  : Card(
                                      color: const Color(0xFF374151),
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          children: leaderboard.asMap().entries.map((entry) {
                                            final index = entry.key;
                                            final saver = entry.value;
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 20,
                                                        backgroundColor: Colors.grey[300],
                                                        child: Text(
                                                          '${index + 1}',
                                                          style: const TextStyle(
                                                            color: Colors.black,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Flexible(
                                                        child: Text(
                                                          saver['user_name'],
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    'KSh ${saver['total_savings'].toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                                    style: const TextStyle(
                                                      color: Color(0xFFF5BB1B),
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}