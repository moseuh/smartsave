import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';
import '../constants/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../widgets/graph.dart' as graph;
import 'buygoodselect.dart';
import 'modern_login_screen.dart';
import 'loans_page.dart';
import 'profile.dart';

class LoansCreditScore extends StatefulWidget {
  final String userId;
  const LoansCreditScore({super.key, required this.userId});

  @override
  State<LoansCreditScore> createState() => _LoansCreditScoreState();
}

class _LoansCreditScoreState extends State<LoansCreditScore> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? userDetails;
  Map<String, dynamic>? metropolCreditData;
  bool isLoading = true;
  int _selectedIndex = 1;

  // Form controllers
  final _idTypeController = TextEditingController(text: 'national_id');
  final _idNumberController = TextEditingController();
  final _loanAmountController = TextEditingController(text: '0');
  final _reportReasonController = TextEditingController(text: 'new_credit_app');
  final _formKey = GlobalKey<FormState>();

  // Animation controller for credit score circle
  late AnimationController _animationController;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scoreAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _validateAndFetchData();
  }

  @override
  void dispose() {
    _idTypeController.dispose();
    _idNumberController.dispose();
    _loanAmountController.dispose();
    _reportReasonController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _validateAndFetchData() async {
    if (widget.userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid user ID. Please log in again.')),
      );
      await _logout();
      return;
    }
    await fetchUserDetails();
    if (userDetails != null && userDetails!['national_id'] != null) {
      setState(() {
        _idNumberController.text = userDetails!['national_id'];
      });
      await fetchMetropolCreditData();
    } else {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('National ID not found. Please enter details below.')),
      );
    }
  }

  Future<void> fetchUserDetails() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/user-details/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            userDetails = data['data'];
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load user details');
        }
      } else if (response.statusCode == 404) {
        throw Exception('User not found. Please log in again.');
      } else {
        throw Exception('Failed to load user details: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: fetchUserDetails,
          ),
        ),
      );
    }
  }

  Future<void> fetchMetropolCreditData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://api.metropol.co.ke/api/v2_1/json_report'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_METROPOL_API_KEY', // Replace with actual API key
        },
        body: jsonEncode({
          'id_type': _idTypeController.text,
          'id_number': _idNumberController.text,
          'loan_amount': int.tryParse(_loanAmountController.text) ?? 0,
          'report_reason': _reportReasonController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            metropolCreditData = {
              'metropol_credit_score': data['data']['credit_score'] ?? 0,
              'credit_status': data['data']['credit_status'] ?? 'Unknown',
            };
            final score = (metropolCreditData!['metropol_credit_score'] as num).toDouble();
            _scoreAnimation = Tween<double>(
              begin: _scoreAnimation.value,
              end: score / 850, // Normalize to 0-1 for progress (Metropol max score ~850)
            ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
            _animationController.forward(from: 0);
            isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load Metropol credit data');
        }
      } else {
        throw Exception('Failed to load Metropol credit data: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading Metropol data: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: fetchMetropolCreditData,
          ),
        ),
      );
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ModernLoginScreen()),
    );
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => graph.SavingsDashboard(userId: widget.userId)),
      );
    } else if (index == 1) {
      // Stay on LoansCreditScore page
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BuyGoodsSelect(userId: widget.userId)),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Profile(userId: widget.userId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            boxShadow: [BoxShadow(color: AppColors.financeGreen.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: AppTheme.textLight),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          userDetails != null ? userDetails!['full_name'] ?? 'User' : 'Loading...',
                          style: const TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Member since 2022', style: TextStyle(color: AppTheme.textLight)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications, color: AppTheme.textLight),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: AppTheme.cardLight,
        width: 250,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.financeGreenV2,
                    child: userDetails != null && userDetails!['selfie_path'] != null
                        ? ClipOval(child: CachedNetworkImage(imageUrl: userDetails!['selfie_path'], fit: BoxFit.cover, width: 56, height: 56))
                        : const Icon(Icons.person, size: 28, color: AppTheme.textLight),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userDetails != null ? userDetails!['full_name'] ?? 'User' : 'Loading...',
                    style: const TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    userDetails != null ? userDetails!['email'] ?? '' : '',
                    style: const TextStyle(color: AppTheme.textLight),
                  ),
                ],
              ),
            ),
            ListTile(leading: const Icon(Icons.account_balance_wallet, color: AppColors.financeGreenV3), title: const Text('Wallet'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.work, color: AppColors.financeGreenV3), title: const Text('Jobs'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.school, color: AppColors.financeGreenV3), title: const Text('Scholarships & Funding'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.chat, color: AppColors.financeGreenV3), title: const Text('Chat'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.leaderboard, color: AppColors.financeGreenV3), title: const Text('Leaderboard'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.class_, color: AppColors.financeGreenV3), title: const Text('Classes'), onTap: () => Navigator.pop(context)),
            ListTile(
              leading: const Icon(Icons.account_balance, color: AppColors.financeGreenV3),
              title: const Text('Loans & Credit'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoansCreditScore(userId: widget.userId)));
              },
            ),
          ],
        ),
      ),
      drawerEnableOpenDragGesture: true,
      body: isLoading
          ? Center(child: SpinKitFadingCircle(color: AppColors.financeGreenV3, size: 50.0))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Credit Score Lookup', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Card(
                    color: AppTheme.cardLight,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _idTypeController.text,
                              decoration: const InputDecoration(labelText: 'ID Type'),
                              items: ['national_id', 'passport'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                              onChanged: (value) => setState(() => _idTypeController.text = value!),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _idNumberController,
                              decoration: const InputDecoration(labelText: 'ID Number'),
                              validator: (value) => (value == null || value.isEmpty) ? 'Please enter ID number' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _loanAmountController,
                              decoration: const InputDecoration(labelText: 'Loan Amount'),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter loan amount';
                                if (int.tryParse(value) == null) return 'Please enter a valid number';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _reportReasonController.text,
                              decoration: const InputDecoration(labelText: 'Report Reason'),
                              items: ['new_credit_app', 'loan_history'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                              onChanged: (value) => setState(() => _reportReasonController.text = value!),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: fetchMetropolCreditData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.financeGreenV3,
                                foregroundColor: AppTheme.textLight,
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Search Credit Score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Your Credit Score', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Center(
                    child: CreditScoreCircle(
                      score: metropolCreditData != null ? (metropolCreditData!['metropol_credit_score'] as num).toDouble() : 0,
                      animation: _scoreAnimation,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Credit Status: ${metropolCreditData != null ? metropolCreditData!['credit_status'] : 'Unknown'}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: AppTheme.backgroundLight,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (!mounted) return;
                      Navigator.push(context, MaterialPageRoute(builder: (context) => LoansPage(userId: widget.userId)));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.financeGreenV3,
                      foregroundColor: AppTheme.textLight,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('View Loans', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.financeGreenV2,
                      foregroundColor: AppTheme.textLight,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Improve Score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          BottomNavigationBar(
            backgroundColor: AppTheme.cardLight,
            selectedItemColor: AppColors.financeGreenV3,
            unselectedItemColor: AppTheme.textSecondary,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Trans...'),
              BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payments'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ],
      ),
    );
  }
}

class CreditScoreCircle extends StatelessWidget {
  final double score;
  final Animation<double> animation;

  const CreditScoreCircle({super.key, required this.score, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: CreditScorePainter(progress: animation.value, score: score),
        );
      },
    );
  }
}

class CreditScorePainter extends CustomPainter {
  final double progress;
  final double score;

  CreditScorePainter({required this.progress, required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.coreWhiteW2, AppColors.coreWhiteW1],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(center, radius - 6, bgPaint);

    final shadowPaint = Paint()
      ..color = AppColors.financeGreen.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius - 6, shadowPaint);

    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.financeGreen, AppColors.financeGreenV3],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      -3.14 / 2,
      2 * 3.14 * progress,
      false,
      progressPaint,
    );

    final innerPaint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.coreWhite, AppColors.coreWhiteW1],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius - 20));
    canvas.drawCircle(center, radius - 20, innerPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: score.toStringAsFixed(0),
        style: const TextStyle(color: AppColors.financeGreen, fontSize: 32, fontWeight: FontWeight.bold),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CreditScorePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.score != score;
}