import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'sign_in_screen.dart';
import 'roundup.dart';
import 'buygoodselect.dart';
import 'profile.dart';
import 'transactiohistory.dart';

class SavingsDashboard extends StatefulWidget {
  final String userId;
  const SavingsDashboard({super.key, required this.userId});

  @override
  _SavingsDashboardState createState() => _SavingsDashboardState();
}

class _SavingsDashboardState extends State<SavingsDashboard> {
  String userName = "Loading...";
  String? selfiePath;
  Map<String, dynamic>? mpesaData;
  bool isRoundUpEnabled = false;
  List<Map<String, dynamic>> recentTransactions = [];

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchMpesaData();
    fetchRecentTransactions();
    _loadRoundUpSettings();
  }

  Future<void> fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedUserId = prefs.getString('user_id');
    debugPrint('User ID from SharedPreferences: $storedUserId, Widget userId: ${widget.userId}');

    String userId = widget.userId.isNotEmpty ? widget.userId : (storedUserId ?? '');

    if (userId.isEmpty) {
      debugPrint("No valid user_id found. Redirecting to SignInScreen.");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
      return;
    }

    try {
      String? storedUserName = prefs.getString('user_name');
      String? storedSelfiePath = prefs.getString('selfie_path');
      debugPrint('Stored User Name: $storedUserName');
      debugPrint('Stored Selfie Path: $storedSelfiePath');

      if (storedUserName != null && storedSelfiePath != null) {
        setState(() {
          userName = storedUserName;
          selfiePath = storedSelfiePath.isNotEmpty ? storedSelfiePath : null;
          debugPrint('Using SharedPreferences - Name: $userName, Selfie Path: $selfiePath');
        });
      } else {
        debugPrint('Fetching user data from API for userId: $userId');
        final response = await http.get(
          Uri.parse('https://apis.gnmprimesource.co.ke/user/$userId'),
          headers: {"Content-Type": "application/json"},
        );

        debugPrint('API Response Status: ${response.statusCode}');
        debugPrint('API Response Body: ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'success') {
            final fullName = data['name'] ?? 'User';
            final selfiePathFromApi = (data['selfie_path'] ?? '').replaceAll('\\', '/');

            await prefs.setString('user_name', fullName);
            await prefs.setString('selfie_path', selfiePathFromApi);

            setState(() {
              userName = fullName;
              selfiePath = selfiePathFromApi.isNotEmpty ? selfiePathFromApi : null;
              debugPrint('Set from API - Name: $userName, Selfie Path: $selfiePath');
            });
          } else {
            throw Exception('API returned unsuccessful status: ${data['message']}');
          }
        } else {
          throw Exception('Failed to fetch user data: ${response.statusCode}');
        }
      }

      if (selfiePath != null) {
        try {
          final imageResponse = await http.get(Uri.parse(selfiePath!));
          debugPrint('Selfie URL Status: ${imageResponse.statusCode}');
          debugPrint('Selfie URL Headers: ${imageResponse.headers}');
          debugPrint('Selfie URL Body (first 100 chars): ${imageResponse.body.substring(0, imageResponse.body.length > 100 ? 100 : imageResponse.body.length)}');
          if (imageResponse.statusCode != 200 || (imageResponse.headers['content-type'] != null && !imageResponse.headers['content-type']!.startsWith('image/'))) {
            debugPrint('Selfie URL is not a valid image: $selfiePath');
            setState(() {
              selfiePath = null;
            });
          }
        } catch (e) {
          debugPrint('Error checking selfie URL: $e');
          setState(() {
            selfiePath = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      setState(() {
        userName = "User";
        selfiePath = null;
      });
      await prefs.setString('user_name', 'User');
      await prefs.setString('selfie_path', '');
    }
  }

  Future<void> fetchMpesaData() async {
    try {
      final mpesaResponse = await http.get(
        Uri.parse("https://apis.gnmprimesource.co.ke/mpesa-usage/${widget.userId}"),
        headers: {"Content-Type": "application/json"},
      );

      debugPrint('M-Pesa API Response Status: ${mpesaResponse.statusCode}');
      debugPrint('M-Pesa API Response Body: ${mpesaResponse.body}');

      if (mpesaResponse.statusCode == 200) {
        final data = jsonDecode(mpesaResponse.body);
        setState(() {
          mpesaData = data is Map<String, dynamic> ? data : null;
        });
      } else {
        setState(() {
          mpesaData = null;
        });
        debugPrint('Failed to fetch M-Pesa data: ${mpesaResponse.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching M-Pesa data: $e");
      setState(() {
        mpesaData = null;
      });
    }
  }

  Future<void> fetchRecentTransactions() async {
    try {
      final response = await http.get(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/last-payment/${widget.userId}'),
        headers: {"Content-Type": "application/json"},
      );

      debugPrint('Recent Transactions API Response Status: ${response.statusCode}');
      debugPrint('Recent Transactions API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            recentTransactions = List<Map<String, dynamic>>.from(data['data']);
            debugPrint('Recent transactions fetched: $recentTransactions');
          });
        } else {
          setState(() {
            recentTransactions = [];
            debugPrint('No transactions found: ${data['message']}');
          });
        }
      } else if (response.statusCode == 404) {
        setState(() {
          recentTransactions = [];
          debugPrint('No transactions found: 404');
        });
      } else {
        debugPrint('Failed to fetch recent transactions: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch recent transactions: ${response.statusCode}')),
        );
        setState(() {
          recentTransactions = [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching recent transactions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching recent transactions')),
      );
      setState(() {
        recentTransactions = [];
      });
    }
  }

  Future<void> _loadRoundUpSettings() async {
    try {
      final response = await http.get(
        Uri.parse('https://apis.gnmprimesource.co.ke/roundup-settings/${widget.userId}'),
        headers: {"Content-Type": "application/json"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          isRoundUpEnabled = data['is_enabled'] ?? false;
        });
      } else {
        debugPrint('Failed to load round-up settings: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading round-up settings: $e');
    }
  }

  Future<void> _saveRoundUpSettings(bool enabled) async {
    try {
      final response = await http.post(
        Uri.parse('https://apis.gnmprimesource.co.ke/roundup-settings'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'user_id': widget.userId,
          'is_enabled': enabled,
        }),
      );
      if (response.statusCode == 200) {
        setState(() {
          isRoundUpEnabled = enabled;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Round-Up Settings saved!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save settings.')),
        );
      }
    } catch (e) {
      debugPrint('Error saving round-up settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving settings.')),
      );
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
                      backgroundImage: selfiePath != null && selfiePath!.isNotEmpty
                          ? NetworkImage(selfiePath!)
                          : const AssetImage('assets/Profile.png') as ImageProvider,
                      onBackgroundImageError: (exception, stackTrace) {
                        debugPrint('Error loading selfie from $selfiePath: $exception');
                        if (mounted) {
                          Future.microtask(() {
                            setState(() {
                              selfiePath = null;
                            });
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
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
                          mpesaData != null && mpesaData!['total_spent'] != null
                              ? 'KSh ${mpesaData!['total_spent'].toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
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
                        painter: SavingsGraphPainter(mpesaData: mpesaData),
                        child: const Center(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
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
                    'DAILY',
                    mpesaData != null && mpesaData!['total_spent'] != null
                        ? 'KSh ${(mpesaData!['total_spent'] / 30).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                        : 'KSh 0',
                    const Color(0xFFF5BB1B),
                    (mpesaData != null && mpesaData!['total_spent'] != null)
                        ? (mpesaData!['total_spent'] / 30) / 1000
                        : 0.0,
                  ),
                  _buildSavingsCard(
                    'WEEKLY',
                    mpesaData != null && mpesaData!['weekly_avg'] != null
                        ? 'KSh ${mpesaData!['weekly_avg'].toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                        : 'KSh 0',
                    const Color(0xFFF5BB1B),
                    (mpesaData != null && mpesaData!['weekly_avg'] != null)
                        ? mpesaData!['weekly_avg'] / 7000
                        : 0.0,
                  ),
                  _buildSavingsCard(
                    'MONTHLY',
                    mpesaData != null && mpesaData!['monthly_avg'] != null
                        ? 'KSh ${mpesaData!['monthly_avg'].toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                        : 'KSh 0',
                    const Color(0xFFF5BB1B),
                    (mpesaData != null && mpesaData!['monthly_avg'] != null)
                        ? mpesaData!['monthly_avg'] / 30000
                        : 0.0,
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
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => TransactionHistory(userId: widget.userId)),
                      );
                    },
                    child: const Text(
                      'See All',
                      style: TextStyle(
                        color: Color(0xFFF5BB1B),
                        fontSize: 14,
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
                    'No recent transactions',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                )
              else
                ...recentTransactions.take(3).map((transaction) {
                  final title = transaction['account_number'].isNotEmpty
                      ? '${transaction['account_number']}\nTill: ${transaction['till_number']}'
                      : 'Till: ${transaction['till_number']}';
                  final amount = '+KSh ${transaction['amount'].toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
                  final time = _formatDateTime(transaction['created_at']);
                  return _buildTransaction(title, amount, time);
                }).toList(),
              const SizedBox(height: 20),
              const Text(
                'Round-Up Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                    Switch(
                      value: isRoundUpEnabled,
                      onChanged: (value) {
                        debugPrint('Switch toggled to: $value - Navigating to RoundUpSettings');
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RoundUpSettings()),
                        ).then((_) async {
                          debugPrint('Returned from RoundUpSettings');
                          await _loadRoundUpSettings();
                        }).catchError((e) {
                          debugPrint('Navigation error: $e');
                        });
                      },
                      activeColor: const Color(0xFFF5BB1B),
                      activeTrackColor: const Color(0xFFF5BB1B).withOpacity(0.5),
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.grey[700],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
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
            onTap: (index) async {
              debugPrint('Tapped index: $index');

              if (index == 0) {
                // Stay on SavingsDashboard
              } else if (index == 1) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => TransactionHistory(userId: widget.userId)),
                );
              } else if (index == 2) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BuyGoodsSelect(userId: widget.userId),
                  ),
                );
              } else if (index == 3) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Profile(userId: widget.userId),
                  ),
                );
              }
            },
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart),
                label: 'Trans...',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.payment),
                label: 'Payments',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final transactionDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

      String time = dateTime.toString().split(' ')[1].substring(0, 5); // HH:MM
      if (transactionDay == today) {
        return 'Today, $time';
      } else if (transactionDay == today.subtract(const Duration(days: 1))) {
        return 'Yesterday, $time';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}, $time';
      }
    } catch (e) {
      debugPrint('Error parsing date: $e');
      return dateTimeStr;
    }
  }

  Widget _buildSavingsCard(String label, String amount, Color color, double progress) {
    return Container(
      width: MediaQuery.of(context).size.width / 3.5,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey[700],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF5BB1B)),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildTransaction(String title, String amount, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  color: Color(0xFFF5BB1B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SavingsGraphPainter extends CustomPainter {
  final Map<String, dynamic>? mpesaData;

  SavingsGraphPainter({this.mpesaData});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF5BB1B)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0xFFF5BB1B).withOpacity(0.2)
      ..style = PaintingStyle.fill;

    const double leftPadding = 40.0;
    const double rightPadding = 20.0;
    final double graphWidth = size.width - (leftPadding + rightPadding);
    final double step = graphWidth / 6;

    const double maxValue = 1500.0;

    final List<double> values = [
      600.0, 700.0, 800.0, 900.0, 1100.0, 1400.0, 1500.0
    ];

    final points = List.generate(
      7,
      (index) => Offset(
        leftPadding + index * step,
        size.height * (1 - (values[index] / maxValue).clamp(0.0, 1.0)),
      ),
    );

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const yLabels = ['1,500', '1,200', '900', '600', '300', '0'];
    for (int i = 0; i < yLabels.length; i++) {
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

    final linePath = Path()
      ..moveTo(points[0].dx, points[0].dy);
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

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < yLabels.length; i++) {
      textPainter.text = TextSpan(
        text: yLabels[i],
        style: const TextStyle(color: Colors.white70, fontSize: 10),
      );
      textPainter.layout();
      final yPosition = (size.height / (yLabels.length - 1)) * i - (textPainter.height / 2);
      textPainter.paint(canvas, Offset(0, yPosition.clamp(0, size.height - textPainter.height)));
    }
  }

  double _getValue(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}