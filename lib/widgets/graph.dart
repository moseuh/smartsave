import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';
import '../screens/goals_dashboard.dart';
import 'dart:io';
import 'dart:async';
import '../screens/modern_login_screen.dart';
import '../screens/SetSavingsGoalScreen.dart';
import '../screens/roundup.dart';
import '../screens/buygoodselect.dart';
import '../screens/profile.dart';
import '../screens/transactiohistory.dart';
import '../screens/wallet_page.dart';
import '../widgets/beautiful_app_bar.dart';
import '../constants/app_theme.dart';

class SavingsDashboard extends StatefulWidget {
  final String userId;
  const SavingsDashboard({super.key, required this.userId});

  @override
  State<SavingsDashboard> createState() => SavingsDashboardState();
}

class SavingsDashboardState extends State<SavingsDashboard> {
  String userName = "Loading...";
  String? selfiePath;
  Map<String, dynamic>? mpesaData;
  double? totalSavings;
  bool isRoundUpEnabled = false;
  List<Map<String, dynamic>> recentTransactions = [];
  List<double> savingsHistory = List.filled(7, 0.0);
  bool isLoading = true;

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
      _retryApiCall(fetchUserData),
      _retryApiCall(fetchMpesaData),
      _retryApiCall(fetchTotalSavings),
      _retryApiCall(fetchSavingsHistory),
      _retryApiCall(fetchRecentTransactions),
      _retryApiCall(_loadRoundUpSettings),
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

  Future<void> fetchUserData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? storedUserId = prefs.getString('user_id');
      debugPrint('User ID: SharedPreferences=$storedUserId, Widget=${widget.userId}');

      String userId = widget.userId.isNotEmpty ? widget.userId : (storedUserId ?? '');
      if (userId.isEmpty) {
        debugPrint("No valid user_id. Redirecting to SignInScreen.");
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ModernLoginScreen()),
          );
        }
        return;
      }
      String? storedUserName = prefs.getString('user_name');
      String? storedSelfiePath = prefs.getString('selfie_path');
      if (storedUserName != null && storedUserName.isNotEmpty) {
        if (mounted) {
          setState(() {
            userName = storedUserName;
            if (storedSelfiePath != null && storedSelfiePath.isNotEmpty) {
              selfiePath = storedSelfiePath;
            }
          });
        }
        if (storedSelfiePath != null) return;
      }

      final response = await http
          .get(
            Uri.parse('${AppConstants.apiBaseUrl}/user/$userId'),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('User data request timed out');
      });

      debugPrint('User Data Response Status: ${response.statusCode}');
      debugPrint('User Data Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        if (data?['status'] == 'success') {
          final fullName = data?['name']?.toString() ?? 'User';
          // Extract first name for greeting
          final firstName = fullName.split(' ').first;
          final selfiePathFromApi = data?['selfie_path']?.toString().replaceAll('\\', '/') ?? '';

          await prefs.setString('user_name', firstName);
          await prefs.setString('selfie_path', selfiePathFromApi);

          if (mounted) {
            setState(() {
              userName = firstName;
              selfiePath = selfiePathFromApi.isNotEmpty ? '${AppConstants.apiBaseUrl}/$selfiePathFromApi' : null;
            });
          }

          if (selfiePath != null) {
            final imageResponse = await http.get(Uri.parse(selfiePath!));
            if (imageResponse.statusCode != 200 || !imageResponse.headers['content-type']!.startsWith('image/')) {
              if (mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() => selfiePath = null);
                });
              }
            }
          }
        } else {
          throw Exception('API status not success: ${data?['message']}');
        }
      } else {
        throw Exception('Failed to fetch user data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (mounted) {
        setState(() {
          userName = "User";
          selfiePath = null;
        });
      }
      await SharedPreferences.getInstance().then((prefs) {
        prefs.setString('user_name', 'User');
        prefs.setString('selfie_path', '');
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching user data: $e')),
        );
      }
    }
  }

  Future<void> fetchMpesaData() async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.apiBaseUrl}/mpesa-usage/${widget.userId}'),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('M-Pesa request timed out');
      });

      debugPrint('M-Pesa Response Status: ${response.statusCode}');
      debugPrint('M-Pesa Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        if (data?['status'] == 'success') {
          if (mounted) {
            setState(() {
              mpesaData = data?['data'];
            });
          }
        } else {
          if (mounted) {
            setState(() => mpesaData = null);
          }
        }
      } else {
        debugPrint('Failed to fetch M-Pesa data: ${response.statusCode}');
        if (mounted) {
          setState(() => mpesaData = null);
        }
      }
    } catch (e) {
      debugPrint('Error fetching M-Pesa data: $e');
      if (mounted) {
        setState(() => mpesaData = null);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching M-Pesa data: $e')),
        );
      }
    }
  }

  Future<void> fetchTotalSavings() async {
    try {
      debugPrint('fetchTotalSavings: widget.userId=${widget.userId}');
      final response = await http
          .get(
            Uri.parse('${AppConstants.apiBaseUrl}/user-savings/${widget.userId}'),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Total savings request timed out');
      });

      debugPrint('Total Savings Response Status: ${response.statusCode}');
      debugPrint('Total Savings Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        debugPrint('Parsed total savings JSON: $data');

        dynamic rawTotal;
        if (data != null) {
          if (data['data'] is Map) {
            rawTotal = data['data']['total_savings'] ?? data['data']['totalSavings'] ?? data['data']['total'];
          } else {
            rawTotal = data['total_savings'] ?? data['totalSavings'] ?? data['data'];
          }
        }

        double parsedTotal = 0.0;
        if (rawTotal is num) {
          parsedTotal = rawTotal.toDouble();
        } else if (rawTotal is String && rawTotal.isNotEmpty) {
          parsedTotal = double.tryParse(rawTotal.replaceAll(',', '')) ?? 0.0;
        } else {
          parsedTotal = 0.0;
        }

        if (data?['status'] == 'success') {
          if (mounted) {
            setState(() {
              totalSavings = parsedTotal;
            });
          }
        } else {
          if (parsedTotal > 0 && mounted) {
            setState(() => totalSavings = parsedTotal);
          } else if (mounted) {
            setState(() => totalSavings = 0.0);
          }
        }
      } else {
        debugPrint('Failed to fetch total savings: ${response.statusCode}');
        if (mounted) {
          setState(() => totalSavings = 0.0);
        }
      }
    } catch (e) {
      debugPrint('Error fetching total savings: $e');
      if (mounted) {
        setState(() => totalSavings = 0.0);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching total savings: $e')),
        );
      }
    }
  }

  Future<void> fetchSavingsHistory() async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.apiBaseUrl}/savings-history/${widget.userId}'),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Savings history request timed out');
      });

      debugPrint('Savings History Response Status: ${response.statusCode}');
      debugPrint('Savings History Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        if (data?['status'] == 'success' && data?['data'] is List) {
          if (mounted) {
            setState(() {
              savingsHistory = (data!['data'] as List)
                  .asMap()
                  .entries
                  .where((entry) => entry.key < 7)
                  .map((entry) => (entry.value['savings'] as num?)?.toDouble() ?? 0.0)
                  .toList();
              while (savingsHistory.length < 7) {
                savingsHistory.add(0.0);
              }
            });
          }
        } else {
          if (mounted) {
            setState(() => savingsHistory = List.filled(7, 0.0));
          }
        }
      } else {
        debugPrint('Failed to fetch savings history: ${response.statusCode}');
        if (mounted) {
          setState(() => savingsHistory = List.filled(7, 0.0));
        }
      }
    } catch (e) {
      debugPrint('Error fetching savings history: $e');
      if (mounted) {
        setState(() => savingsHistory = List.filled(7, 0.0));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching savings history: $e')),
        );
      }
    }
  }

  Future<void> fetchRecentTransactions() async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.apiBaseUrl}/last-payment/${widget.userId}'),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Recent transactions request timed out');
      });

      debugPrint('Recent Transactions Response Status: ${response.statusCode}');
      debugPrint('Recent Transactions Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success' && data['data'] is List) {
          if (mounted) {
            setState(() {
              recentTransactions = (data['data'] as List).map((transaction) {
                return {
                  'account_number': null,
                  'till_number': transaction['business_name']?.toString() ?? 'Unknown',
                  'amount': (transaction['total_amount'] as num?)?.toDouble() ?? 0.0,
                  'created_at': transaction['created_at']?.toString() ?? '',
                };
              }).toList();
            });
          }
        } else {
          if (mounted) {
            setState(() => recentTransactions = []);
          }
        }
      } else {
        debugPrint('Failed to fetch recent transactions: ${response.statusCode}');
        if (mounted) {
          setState(() => recentTransactions = []);
        }
      }
    } catch (e) {
      debugPrint('Error fetching recent transactions: $e');
      if (mounted) {
        setState(() => recentTransactions = []);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error fetching recent transactions')),
        );
      }
    }
  }

  Future<void> _loadRoundUpSettings() async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.apiBaseUrl}/roundup-settings/${widget.userId}'),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Round-up settings request timed out');
      });

      debugPrint('Round-Up Settings Response Status: ${response.statusCode}');
      debugPrint('Round-Up Settings Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        if (mounted) {
          setState(() {
            isRoundUpEnabled = data?['is_enabled'] == true;
          });
        }
      } else {
        debugPrint('Failed to load round-up settings: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading round-up settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading round-up settings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // scaffoldBackgroundColor from theme
      appBar: BeautifulAppBar(
        userName: userName,
        profileImageUrl: selfiePath,
        userId: widget.userId,
        onNotificationTap: () {},
        onProfileTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Profile(userId: widget.userId)),
          );
          // Refresh user data after returning from profile
          fetchUserData();
        },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.financeGreenV3))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.financeGreenV3.withValues(alpha: 0.3), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'TOTAL SAVINGS',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  totalSavings != null
                                      ? 'KSh ${totalSavings!.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                                      : 'KSh 0',
                                  style: const TextStyle(
                                    color: AppColors.financeGreenV3,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 120,
                              child: CustomPaint(
                                painter: SavingsGraphPainter(savingsHistory: savingsHistory),
                                child: const Center(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Text('Mon', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                                Text('Tue', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                                Text('Wed', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                                Text('Thu', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                                Text('Fri', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                                Text('Sat', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                                Text('Sun', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSavingsCard(
                            children: [
                              const Text(
                                'DAILY SPEND',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                mpesaData?['total_spent'] != null
                                    ? 'KSh ${(mpesaData!['total_spent'] / 30).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                                    : 'KSh 0',
                                style: const TextStyle(
                                  color: AppColors.financeGreenV3,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: mpesaData?['total_spent'] != null ? (mpesaData!['total_spent'] / 30) / 1000 : 0.0,
                                backgroundColor: AppColors.coreWhiteW2,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.financeGreenV3),
                                minHeight: 3,
                              ),
                            ],
                          ),
                          _buildSavingsCard(
                            children: [
                              const Text(
                                'WEEKLY SPEND',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                mpesaData?['weekly_avg'] != null
                                    ? 'KSh ${mpesaData!['weekly_avg'].toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                                    : 'KSh 0',
                                style: const TextStyle(
                                  color: AppColors.financeGreenV3,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: mpesaData?['weekly_avg'] != null ? mpesaData!['weekly_avg'] / 7000 : 0.0,
                                backgroundColor: AppColors.coreWhiteW2,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.financeGreenV3),
                                minHeight: 3,
                              ),
                            ],
                          ),
                          _buildSavingsCard(
                            children: [
                              const Text(
                                'MONTHLY SPEND',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                mpesaData?['monthly_avg'] != null
                                    ? 'KSh ${mpesaData!['monthly_avg'].toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                                    : 'KSh 0',
                                style: const TextStyle(
                                  color: AppColors.financeGreenV3,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: mpesaData?['monthly_avg'] != null ? mpesaData!['monthly_avg'] / 30000 : 0.0,
                                backgroundColor: AppColors.coreWhiteW2,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.financeGreenV3),
                                minHeight: 3,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Transactions',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => TransactionHistory(userId: widget.userId)),
                                );
                              }
                            },
                            child: const Text(
                              'See All',
                              style: TextStyle(
                                color: AppColors.financeGreenV3,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (recentTransactions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'No recent transactions available',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          ),
                        )
                      else
                        ...recentTransactions.take(3).map((transaction) {
                          final title = transaction['till_number']?.isNotEmpty == true
                              ? 'Till: ${transaction['till_number']}'
                              : 'Unknown Transaction';
                          final amount = transaction['amount'] != null
                              ? '+KSh ${transaction['amount'].toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                              : '+KSh 0.00';
                          final time = transaction['created_at']?.toString() ?? '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      amount,
                                      style: const TextStyle(color: AppColors.financeGreenV3, fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      time,
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 20),
                      const Text(
                        'Round-Up Settings',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.financeGreenV3.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Enable Round-Up Savings\nRound up transactions to nearest KSh and save the difference',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            Switch(
                              value: isRoundUpEnabled,
                              onChanged: (value) {
                                if (mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const RoundUpSettings()),
                                  ).then((_) => _loadRoundUpSettings());
                                }
                              },
                              activeColor: AppColors.financeGreenV3,
                              activeTrackColor: AppColors.financeGreenV3.withValues(alpha: 0.5),
                              inactiveThumbColor: AppColors.coreDarkD2,
                              inactiveTrackColor: AppColors.coreWhiteW2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
          ),
        ),
      ),
      // CLEAN SINGLE FAB - ONLY "Create Goal"
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "createGoal",
        onPressed: () {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GoalCreationScreen(userId: widget.userId),
            ),
          );
        },
        label: const Text(
          'Create Goal',
          style: TextStyle(
            color: AppTheme.textLight,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        icon: const Icon(Icons.add, color: AppTheme.textLight),
        backgroundColor: AppColors.financeGreenV3,
        elevation: 4,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppTheme.cardLight,
        selectedItemColor: AppColors.financeGreenV3,
        unselectedItemColor: AppTheme.textSecondary,
        currentIndex: 0,
        onTap: (index) {
          if (!mounted || index == 0) return;
          final routes = [
            null,
            MaterialPageRoute(builder: (context) => WalletPage(userId: widget.userId)),
            MaterialPageRoute(builder: (context) => BuyGoodsSelect(userId: widget.userId)),
            MaterialPageRoute(builder: (context) => Profile(userId: widget.userId)),
          ];
          if (index < routes.length && routes[index] != null) {
            Navigator.push(context, routes[index]!);
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Pay'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildSavingsCard({required List<Widget> children}) {
    return Container(
      width: MediaQuery.of(context).size.width / 3.5,
      height: 95,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.financeGreenV3.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }
}

class SavingsGraphPainter extends CustomPainter {
  final List<double> savingsHistory;

  SavingsGraphPainter({required this.savingsHistory}) {
    debugPrint('SavingsGraphPainter: savingsHistory=$savingsHistory');
    if (savingsHistory.isEmpty || savingsHistory.length < 7) {
      savingsHistory.addAll(List.filled(7 - savingsHistory.length, 0.0));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.financeGreenV3
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = AppColors.financeGreenV3.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    const leftPadding = 40.0;
    const rightPadding = 20.0;
    final graphWidth = size.width - (leftPadding + rightPadding);
    final step = graphWidth / 6;
    final maxValue = savingsHistory.isNotEmpty && savingsHistory.any((v) => v > 0)
        ? savingsHistory.reduce((a, b) => a > b ? a : b) * 1.2
        : 1500.0;

    final points = List.generate(
      7,
      (index) => Offset(
        leftPadding + index * step,
        size.height * (1 - (savingsHistory[index] / maxValue).clamp(0.0, 1.0)),
      ),
    );

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const yLabels = ['1,500', '1,200', '900', '600', '300', '0'];
    for (var i = 0; i < yLabels.length; i++) {
      final yPosition = (size.height / (yLabels.length - 1)) * i;
      canvas.drawLine(
        Offset(leftPadding, yPosition),
        Offset(size.width - rightPadding, yPosition),
        gridPaint,
      );
    }

    final path = Path()
      ..moveTo(leftPadding, size.height)
      ..lineTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.lineTo(leftPadding + 6 * step, size.height);
    path.close();
    canvas.drawPath(path, fillPaint);

    final linePath = Path()..moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, paint);

    final dotPaint = Paint()
      ..color = AppColors.financeGreenV3
      ..style = PaintingStyle.fill;
    for (var point in points) {
      canvas.drawCircle(point, 3, dotPaint);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < yLabels.length; i++) {
      textPainter.text = TextSpan(
        text: yLabels[i],
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
      );
      textPainter.layout();
      final yPosition = (size.height / (yLabels.length - 1)) * i - (textPainter.height / 2);
      textPainter.paint(canvas, Offset(0, yPosition.clamp(0, size.height - textPainter.height)));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}