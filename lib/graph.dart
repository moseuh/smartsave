import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'goals_dashboard.dart';
import 'dart:io';
import 'dart:async';
import 'sign_in_screen.dart';
import 'SetSavingsGoalScreen.dart';
import 'roundup.dart';
import 'buygoodselect.dart';
import 'profile.dart';
import 'transactiohistory.dart';

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
            MaterialPageRoute(builder: (context) => const SignInScreen()),
          );
        }
        return;
      }

      String? storedUserName = prefs.getString('user_name');
      String? storedSelfiePath = prefs.getString('selfie_path');
      if (storedUserName != null && storedSelfiePath != null) {
        if (mounted) {
          setState(() {
            userName = storedUserName;
            selfiePath = storedSelfiePath;
          });
        }
        return;
      }

      final response = await http
          .get(
            Uri.parse('http://apis.nebo.co.ke/apis/user/$userId'),
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
          final selfiePathFromApi = data?['selfie_path']?.toString().replaceAll('\\', '/') ?? '';

          await prefs.setString('user_name', fullName);
          await prefs.setString('selfie_path', selfiePathFromApi);

          if (mounted) {
            setState(() {
              userName = fullName;
              selfiePath = selfiePathFromApi.isNotEmpty ? 'http://apis.nebo.co.ke/apis/$selfiePathFromApi' : null;
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
            Uri.parse('http://apis.nebo.co.ke/apis/mpesa-usage/${widget.userId}'),
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
            Uri.parse('http://apis.nebo.co.ke/apis/user-savings/${widget.userId}'),
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
            Uri.parse('http://apis.nebo.co.ke/apis/savings-history/${widget.userId}'),
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
            Uri.parse('http://apis.nebo.co.ke/apis/last-payment/${widget.userId}'),
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
            Uri.parse('http://apis.nebo.co.ke/apis/roundup-settings/${widget.userId}'),
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
      backgroundColor: const Color(0xFF1F2937),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: Container(
          color: const Color(0xFF374151),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: selfiePath?.isNotEmpty == true
                          ? NetworkImage(selfiePath!)
                          : const AssetImage('assets/Profile.png') as ImageProvider,
                      onBackgroundImageError: (error, stackTrace) {
                        debugPrint('Image load error: $error');
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() => selfiePath = null);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back',
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w400),
                        ),
                        Text(
                          userName,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.notifications, color: Color(0xFFF5BB1B)),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF5BB1B)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF374151),
                          borderRadius: BorderRadius.circular(12),
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
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  totalSavings != null
                                      ? 'KSh ${totalSavings!.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                                      : 'KSh 0',
                                  style: const TextStyle(
                                    color: Color(0xFFF5BB1B),
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 150,
                              child: CustomPaint(
                                painter: SavingsGraphPainter(savingsHistory: savingsHistory),
                                child: const Center(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Text('Mon', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('Tue', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('Wed', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('Thu', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('Fri', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('Sat', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('Sun', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSavingsCard(
                            children: [
                              const Text(
                                'DAILY SPEND',
                                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1.2),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                mpesaData?['total_spent'] != null
                                    ? 'KSh ${(mpesaData!['total_spent'] / 30).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                                    : 'KSh 0',
                                style: const TextStyle(color: Color(0xFFF5BB1B), fontSize: 16, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: mpesaData?['total_spent'] != null ? (mpesaData!['total_spent'] / 30) / 1000 : 0.0,
                                backgroundColor: Colors.grey[700],
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF5BB1B)),
                                minHeight: 4,
                              ),
                            ],
                          ),
                          _buildSavingsCard(
                            children: [
                              const Text(
                                'WEEKLY SPEND',
                                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1.2),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                mpesaData?['weekly_avg'] != null
                                    ? 'KSh ${mpesaData!['weekly_avg'].toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                                    : 'KSh 0',
                                style: const TextStyle(color: Color(0xFFF5BB1B), fontSize: 16, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: mpesaData?['weekly_avg'] != null ? mpesaData!['weekly_avg'] / 7000 : 0.0,
                                backgroundColor: Colors.grey[700],
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF5BB1B)),
                                minHeight: 4,
                              ),
                            ],
                          ),
                          _buildSavingsCard(
                            children: [
                              const Text(
                                'MONTHLY SPEND',
                                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1.2),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                mpesaData?['monthly_avg'] != null
                                    ? 'KSh ${mpesaData!['monthly_avg'].toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                                    : 'KSh 0',
                                style: const TextStyle(color: Color(0xFFF5BB1B), fontSize: 16, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: mpesaData?['monthly_avg'] != null ? mpesaData!['monthly_avg'] / 30000 : 0.0,
                                backgroundColor: Colors.grey[700],
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF5BB1B)),
                                minHeight: 4,
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
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                              style: TextStyle(color: Color(0xFFF5BB1B), fontSize: 14, fontWeight: FontWeight.w500),
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
                            style: TextStyle(color: Colors.white70, fontSize: 14),
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
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      amount,
                                      style: const TextStyle(color: Color(0xFFF5BB1B), fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      time,
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF374151),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Enable Round-Up Savings\nRound up transactions to nearest KSh and save the difference',
                                style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
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
                              activeColor: const Color(0xFFF5BB1B),
                              activeTrackColor: const Color(0xFFF5BB1B).withValues(alpha: 0.5),
                              inactiveThumbColor: Colors.grey,
                              inactiveTrackColor: Colors.grey[700],
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
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.add, color: Colors.black),
        backgroundColor: const Color(0xFFF5BB1B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
          side: const BorderSide(color: Colors.white70, width: 2),
        ),
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFF374151),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            selectedItemColor: const Color(0xFFF5BB1B),
            unselectedItemColor: Colors.white54,
            currentIndex: 0,
            onTap: (index) {
              if (!mounted) return;
              if (index == 0) return;
              final routes = [
                null,
                MaterialPageRoute(builder: (context) => TransactionHistory(userId: widget.userId)),
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
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Trans...'),
              BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payments'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavingsCard({required List<Widget> children}) {
    return Container(
      width: MediaQuery.of(context).size.width / 3.5,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
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
      ..color = const Color(0xFFF5BB1B)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0xFFF5BB1B).withValues(alpha: 0.2)
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
      ..color = const Color(0xFFF5BB1B)
      ..style = PaintingStyle.fill;
    for (var point in points) {
      canvas.drawCircle(point, 3, dotPaint);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < yLabels.length; i++) {
      textPainter.text = TextSpan(
        text: yLabels[i],
        style: const TextStyle(color: Colors.white70, fontSize: 10),
      );
      textPainter.layout();
      final yPosition = (size.height / (yLabels.length - 1)) * i - (textPainter.height / 2);
      textPainter.paint(canvas, Offset(0, yPosition.clamp(0, size.height - textPainter.height)));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}