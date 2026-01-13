import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/graph.dart';

class GoalCreationScreen extends StatefulWidget {
  final String userId;

  const GoalCreationScreen({
    super.key,
    required this.userId,
  });

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

  // Gamified Challenges
  Map<String, dynamic> activeChallenges = {};
  String? selectedReminderFrequency;
  int selected52WeekStart = 100;

  // User's phone number fetched from API
  String userPhone = '';

  final List<int> startingAmounts = [50, 100, 200, 500];

  final List<Map<String, dynamic>> challenges = [
    {
      'id': '52_week',
      'title': '52-Week Money Challenge',
      'description': 'Double your savings every week for a year',
      'icon': Icons.trending_up,
      'color': Colors.deepPurple,
    },
    {
      'id': 'round_up',
      'title': 'Round-Up Challenge',
      'description': 'Round up every purchase and save the change',
      'icon': Icons.payments,
      'color': Colors.teal,
    },
    {
      'id': 'no_spend_weekend',
      'title': 'No-Spend Weekend Challenge',
      'description': 'Skip non-essential spending every weekend',
      'icon': Icons.block,
      'color': Colors.orange,
    },
    {
      'id': 'daily_100',
      'title': 'Daily KSh 100 Challenge',
      'description': 'Save at least KSh 100 every single day',
      'icon': Icons.local_fire_department,
      'color': Colors.red,
    },
  ];

  final List<String> reminderOptions = ['Daily', 'Weekly', 'Monthly', 'None'];

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
      'image': 'assets/images/tech_week.jpg',
    },
    {
      'name': 'Charity Marathon',
      'date': '2025-10-15',
      'cost': 2000.0,
      'time': '07:00 AM',
      'image': 'assets/images/marathon.jpg',
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
      _loadActiveChallenges();
      _fetchUserPhone();
    });
  }

  Future<void> _fetchUserPhone() async {
    try {
      final response = await http.get(
        Uri.parse('https://apis.nebo.co.ke/apis/user-details/${widget.userId}'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final rawPhone = data['data']['phone_number']?.toString() ?? '';
          if (rawPhone.isNotEmpty) {
            String cleaned = rawPhone.replaceAll(RegExp(r'\D'), '');
            if (cleaned.startsWith('0')) {
              cleaned = '254' + cleaned.substring(1);
            } else if (cleaned.length == 9) {
              cleaned = '254' + cleaned;
            }
            setState(() {
              userPhone = cleaned;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch user phone: $e');
      // Fallback - you can show a message or ask user to enter phone if needed
    }
  }

  Future<void> _loadActiveChallenges() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('active_challenges_${widget.userId}');
    if (saved != null && mounted) {
      setState(() {
        activeChallenges = jsonDecode(saved);
      });
    }
  }

  Future<void> _joinChallenge(String challengeId) async {
    if (selectedReminderFrequency == null || selectedReminderFrequency == 'None') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reminder frequency first')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://apis.nebo.co.ke/apis/challengesjoin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'challenge_id': challengeId,
          'starting_amount': challengeId == '52_week' ? selected52WeekStart : 0,
          'reminder': selectedReminderFrequency,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            activeChallenges[challengeId] = {
              'starting_amount': selected52WeekStart,
              'reminder': selectedReminderFrequency,
              'current_week': 0,
              'total_saved': 0.0,
            };
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('active_challenges_${widget.userId}', jsonEncode(activeChallenges));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Challenge joined successfully!'), backgroundColor: Colors.green),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${response.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  Future<void> _contributeToChallenge(String challengeId) async {
    if (userPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available. Please try again later.')),
      );
      return;
    }

    final controller = TextEditingController();

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Contribute to Challenge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How much do you want to contribute?', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g., 500',
                filled: true,
                fillColor: const Color(0xFF1F2937),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              final amount = double.tryParse(text);
              if (amount != null && amount > 0) {
                Navigator.pop(context, {'amount': amount});
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5BB1B)),
            child: const Text('Pay Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == null) return;

    final double amount = result['amount'];

    try {
      final response = await http.post(
        Uri.parse('https://apis.nebo.co.ke/apis/challengescontribute'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'challenge_id': challengeId,
          'amount': amount,
          'phone_number': userPhone,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('STK Push sent! Please complete payment on your phone.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 8),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to send STK Push')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showChallengeProgress(String challengeId) {
    final challenge = challenges.firstWhere((c) => c['id'] == challengeId);
    final data = activeChallenges[challengeId] ?? {};
    final currentWeek = data['current_week'] ?? 0;
    final totalSaved = data['total_saved']?.toDouble() ?? 0.0;
    final startingAmount = data['starting_amount'] ?? 100;

    double expectedThisWeek = 0.0;
    double totalExpected = 0.0;
    if (challengeId == '52_week') {
      expectedThisWeek = startingAmount * (currentWeek + 1);
      totalExpected = startingAmount * (52 * 53) / 2;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(challenge['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (challengeId == '52_week') ...[
                Text('Current Week: ${currentWeek + 1} / 52', style: const TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 12),
                Text('Amount due this week: KSh ${expectedThisWeek.toStringAsFixed(0)}',
                    style: const TextStyle(color: Color(0xFFF5BB1B), fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: currentWeek / 52,
                  backgroundColor: Colors.grey[700],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF5BB1B)),
                  minHeight: 10,
                ),
                const SizedBox(height: 8),
                Text('$currentWeek weeks completed', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),
                Text('Total saved: KSh ${totalSaved.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.green, fontSize: 18)),
                Text('Goal: KSh ${totalExpected.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70)),
              ] else ...[
                Text('Total saved so far: KSh ${totalSaved.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.green, fontSize: 20)),
                const SizedBox(height: 20),
                const Text('Keep up the great work!', style: TextStyle(color: Colors.white70)),
              ],
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => _contributeToChallenge(challengeId),
                icon: const Icon(Icons.payment, color: Colors.black),
                label: const Text('Contribute Now via M-PESA',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5BB1B),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
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
          debugPrint('Max retries reached');
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  Future<void> fetchLeaderboard() async {
    try {
      final response = await http.get(
        Uri.parse('http://apis.nebo.co.ke/apis/leaderboard/top-10-weekly'),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success' && data['data'] is List) {
          if (mounted) {
            setState(() {
              leaderboard = List<Map<String, dynamic>>.from(data['data']).map((entry) {
                return {
                  'user_name': entry['user_name']?.toString() ?? 'Unknown',
                  'total_savings': entry['total_savings'] is num ? entry['total_savings'].toDouble() : 0.0,
                };
              }).toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
    }
  }

  Future<void> fetchRecentSavings() async {
    try {
      final response = await http.get(
        Uri.parse('http://apis.nebo.co.ke/apis/savings-recent/${widget.userId}'),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 15));

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
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching recent savings: $e');
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
        });
      }
    } catch (e) {
      debugPrint('Error loading badges: $e');
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
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == items.length) {
                return Card(
                  color: const Color(0xFF1F2937),
                  child: ListTile(
                    leading: const Icon(Icons.add, color: Color(0xFFF5BB1B)),
                    title: const Text('Create New', style: TextStyle(color: Colors.white)),
                    onTap: () => Navigator.pop(context, 'Create New'),
                  ),
                );
              }
              final item = items[index];
              return Card(
                color: const Color(0xFF1F2937),
                child: ListTile(
                  leading: goalType == 'Pay for Event'
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item['image'],
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.event, color: Color(0xFFF5BB1B)),
                          ),
                        )
                      : Icon(item['icon'], color: const Color(0xFFF5BB1B)),
                  title: Text(item['name'], style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    goalType == 'Pay for Event'
                        ? '${item['date']} • ${item['time']} • KSh ${item['cost']}'
                        : item['description'] ?? item['expected_return'],
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  onTap: () {
                    if (goalType == 'Pay for Event') {
                      setState(() {
                        goalName = item['name'];
                        goalAmount = item['cost'].toDouble();
                        durationDays = DateTime.parse(item['date']).difference(DateTime.now()).inDays.clamp(1, 365);
                      });
                    }
                    Navigator.pop(context, item['name']);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xFFF5BB1B)))),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        selectedOption = result;
        if (result != 'Create New') goalName = result;
      });
    }
  }

  Future<void> createGoal() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (goalAmount == null || goalAmount! < 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Target amount must be at least KSh 100')));
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://apis.nebo.co.ke/apis/goalscreate'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.userId,
          "title": goalName?.trim() ?? "Untitled Goal",
          "target_amount": goalAmount,
          "duration_days": durationDays ?? 30,
          "goal_type": selectedGoalType ?? "Save",
          "selected_option": selectedOption,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goal created successfully!')));
        Navigator.pop(context);
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error['message'] ?? 'Server error')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requiredDailySavings = goalAmount != null && durationDays != null ? goalAmount! / durationDays! : 0.0;
    final requiredWeeklySavings = requiredDailySavings * 7;
    final requiredMonthlySavings = requiredDailySavings * 30;
    final progress = goalAmount != null && goalAmount! > 0 ? (currentSavings / goalAmount!).clamp(0.0, 1.0) : 0.0;

    return Material(
      color: const Color(0xFF1F2937),
      child: Theme(
        data: Theme.of(context).copyWith(
          dropdownMenuTheme: DropdownMenuThemeData(
            textStyle: const TextStyle(color: Colors.white),
            menuStyle: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(const Color(0xFF374151)),
              elevation: WidgetStatePropertyAll(4),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: const Color(0xFF374151),
            elevation: 4,
            title: const Text('Create a Savings Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFF5BB1B)))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Goal Creation Form
                        Card(
                          color: const Color(0xFF374151),
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Goal Type', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFF1F2937),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                    ),
                                    value: selectedGoalType,
                                    hint: const Text('Select Goal Type', style: TextStyle(color: Colors.white70)),
                                    dropdownColor: const Color(0xFF374151),
                                    iconEnabledColor: const Color(0xFFF5BB1B),
                                    style: const TextStyle(color: Color(0xFFF5BB1B), fontSize: 16),
                                    items: goalTypes.map((type) {
                                      return DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(color: Colors.white)));
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedGoalType = value;
                                        selectedOption = null;
                                        goalName = null;
                                        goalAmount = null;
                                        durationDays = null;
                                      });
                                      if (value == 'Pay Loan' || value == 'Pay for Event' || value == 'Save to Invest') {
                                        showCatalogueDialog(value!);
                                      }
                                    },
                                    validator: (value) => value == null ? 'Please select a goal type' : null,
                                  ),
                                  if (selectedGoalType == 'Pay Loan' || selectedGoalType == 'Pay for Event' || selectedGoalType == 'Save to Invest') ...[
                                    const SizedBox(height: 16),
                                    const Text('Selected Option', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 8),
                                    Text(selectedOption ?? 'None selected', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                  ],
                                  const SizedBox(height: 16),
                                  const Text('Goal Name', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFF1F2937),
                                      hintText: 'e.g., Vacation Fund',
                                      hintStyle: const TextStyle(color: Colors.white70),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    initialValue: goalName,
                                    validator: (value) => value == null || value.isEmpty ? 'Please enter a goal name' : null,
                                    onSaved: (value) => goalName = value,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Goal Amount (KSh)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFF1F2937),
                                      hintText: 'e.g., 10000',
                                      hintStyle: const TextStyle(color: Colors.white70),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                    initialValue: goalAmount?.toString(),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Please enter amount';
                                      final num = double.tryParse(value);
                                      if (num == null || num <= 0) return 'Invalid amount';
                                      return null;
                                    },
                                    onSaved: (value) => goalAmount = double.parse(value!),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Duration (Days)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFF1F2937),
                                      hintText: 'e.g., 30',
                                      hintStyle: const TextStyle(color: Colors.white70),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                    initialValue: durationDays?.toString(),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Please enter duration';
                                      final num = int.tryParse(value);
                                      if (num == null || num <= 0) return 'Invalid number of days';
                                      return null;
                                    },
                                    onSaved: (value) => durationDays = int.parse(value!),
                                    onChanged: (value) {
                                      if (int.tryParse(value) != null && mounted) {
                                        setState(() => durationDays = int.parse(value));
                                      }
                                    },
                                  ),
                                  if (goalAmount != null && durationDays != null) ...[
                                    const SizedBox(height: 16),
                                    Card(
                                      color: const Color(0xFF374151),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Savings Plan', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 8),
                                            Text('Daily: KSh ${requiredDailySavings.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70)),
                                            Text('Weekly: KSh ${requiredWeeklySavings.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70)),
                                            Text('Monthly: KSh ${requiredMonthlySavings.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70)),
                                            const SizedBox(height: 16),
                                            const Text('Progress', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                            LinearProgressIndicator(value: progress, backgroundColor: Colors.grey[700], valueColor: const AlwaysStoppedAnimation(Color(0xFFF5BB1B))),
                                            const SizedBox(height: 8),
                                            Text('${(progress * 100).toStringAsFixed(1)}% complete', style: const TextStyle(color: Colors.white70)),
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
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: isLoading
                                          ? const CircularProgressIndicator(color: Colors.black)
                                          : const Text('Create Goal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Badges
                        const SizedBox(height: 32),
                        const Text('Your Badges', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        badges.isEmpty
                            ? const Text('No badges earned yet', style: TextStyle(color: Colors.white70))
                            : SizedBox(
                                height: 70,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: badges.map((badge) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Chip(
                                        label: Text(badge, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                        backgroundColor: const Color(0xFFF5BB1B),
                                        avatar: Icon(
                                          badge == 'Goal Starter' ? Icons.star : badge == 'Consistent Saver' ? Icons.savings : Icons.trending_up,
                                          color: Colors.black,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),

                        // Leaderboard
                        const SizedBox(height: 32),
                        const Text('Weekly Top 10 Savers', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        leaderboard.isEmpty
                            ? const Text('No leaderboard data', style: TextStyle(color: Colors.white70))
                            : Card(
                                color: const Color(0xFF374151),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: leaderboard.asMap().entries.map((e) {
                                      final index = e.key;
                                      final saver = e.value;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(radius: 16, child: Text('${index + 1}', style: const TextStyle(fontSize: 12))),
                                                const SizedBox(width: 10),
                                                Text(saver['user_name'], style: const TextStyle(color: Colors.white)),
                                              ],
                                            ),
                                            Text('KSh ${saver['total_savings'].toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFF5BB1B), fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),

                        // Active Challenges
                        const SizedBox(height: 40),
                        const Text('Active Challenges', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        activeChallenges.isEmpty
                            ? const Text('No active challenges. Join one below!', style: TextStyle(color: Colors.white70))
                            : Column(
                                children: activeChallenges.keys.map((id) {
                                  final challenge = challenges.firstWhere((c) => c['id'] == id);
                                  final data = activeChallenges[id];
                                  final week = data['current_week'] ?? 0;
                                  final saved = data['total_saved']?.toDouble() ?? 0.0;
                                  return Card(
                                    color: const Color(0xFF374151),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: CircleAvatar(backgroundColor: challenge['color'], child: Icon(challenge['icon'], color: Colors.white)),
                                      title: Text(challenge['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      subtitle: Text(
                                        id == '52_week'
                                            ? 'Week $week • KSh ${saved.toStringAsFixed(0)} saved'
                                            : 'KSh ${saved.toStringAsFixed(0)} saved',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54),
                                      onTap: () => _showChallengeProgress(id),
                                    ),
                                  );
                                }).toList(),
                              ),

                        // Join New Challenge Section
                        const SizedBox(height: 30),
                        const Text('Join a New Challenge', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),

                        // Reminder Frequency
                        Card(
                          color: const Color(0xFF374151),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Reminder Frequency', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: selectedReminderFrequency,
                                  hint: const Text('Choose reminder', style: TextStyle(color: Colors.white70)),
                                  dropdownColor: const Color(0xFF374151),
                                  style: const TextStyle(color: Colors.white),
                                  items: reminderOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                                  onChanged: (val) => setState(() => selectedReminderFrequency = val),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFF1F2937),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 52-Week Starting Amount
                        Card(
                          color: const Color(0xFF374151),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('52-Week Challenge Starting Amount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<int>(
                                  value: selected52WeekStart,
                                  items: startingAmounts.map((amt) {
                                    final total = amt * (52 * 53) / 2;
                                    return DropdownMenuItem(value: amt, child: Text('KSh $amt/week → Total KSh ${total.toStringAsFixed(0)}'));
                                  }).toList(),
                                  onChanged: (val) => setState(() => selected52WeekStart = val!),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFF1F2937),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Available Challenges
                        ...challenges.map((challenge) {
                          final isJoined = activeChallenges.containsKey(challenge['id']);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Card(
                              color: const Color(0xFF374151),
                              elevation: 6,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(backgroundColor: challenge['color'], child: Icon(challenge['icon'], color: Colors.white)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(challenge['title'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                              Text(challenge['description'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                            ],
                                          ),
                                        ),
                                        if (isJoined)
                                          const Chip(label: Text('ACTIVE'), backgroundColor: Colors.green),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      challenge['id'] == '52_week'
                                          ? 'Week 1: KSh $selected52WeekStart → Week 52: KSh ${selected52WeekStart * 52}\nTotal after 52 weeks: KSh ${(selected52WeekStart * (52 * 53) / 2).toStringAsFixed(0)}'
                                          : challenge['description'],
                                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                                    ),
                                    const SizedBox(height: 16),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton(
                                        onPressed: isJoined ? null : () => _joinChallenge(challenge['id']),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isJoined ? Colors.grey : const Color(0xFFF5BB1B),
                                          foregroundColor: Colors.black,
                                        ),
                                        child: Text(isJoined ? 'Joined' : 'Join Challenge'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}