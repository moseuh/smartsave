// wallet_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:smartsave/constants/app_theme.dart';
import '../constants/app_constants.dart';
import 'loan_products.dart';
// === YOUR PAGES ===
import 'buygoodselect.dart';
import 'modern_login_screen.dart' as signIn;
import 'loans_credit_score.dart';
import 'profile.dart';
import 'jobs_page.dart';
import 'till.dart';
import 'goals_dashboard.dart';
import '../widgets/graph.dart';

// Placeholder page
class LeaderboardPage extends StatelessWidget {
  final String userId;
  const LeaderboardPage({super.key, required this.userId});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Leaderboard')),
        body: const Center(child: Text('Coming Soon')),
      );
}

// ==================================================
// =============== MAIN WALLET PAGE =================
// ==================================================

class WalletPage extends StatefulWidget {
  final String userId;
  const WalletPage({super.key, required this.userId});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  Map<String, dynamic>? userDetails;
  Map<String, dynamic>? walletData;
  Map<String, dynamic>? savingsData;
  List<Map<String, dynamic>> userGoals = [];
  bool isLoading = true;
  bool _isPayBillMode = false;

  String get baseUrl => AppConstants.apiBaseUrl;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      fetchUserDetails(),
      fetchWalletData(),
      fetchSavingsBalance(),
      fetchUserGoals(),
    ]);
    setState(() => isLoading = false);
  }

  Future<void> fetchUserDetails() async {
    try {
      final res = await http.get(Uri.parse('${AppConstants.apiBaseUrl}/user-details/${widget.userId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          userDetails = data['data'];
          if (userDetails?['selfie_path'] != null) {
            userDetails!['selfie_path'] = userDetails!['selfie_path'].toString().replaceAll('\\', '/');
          }
        }
      }
    } catch (e) {}
  }

  Future<void> fetchWalletData() async {
    try {
      final res = await http.get(Uri.parse('${AppConstants.apiBaseUrl}/wallet/${widget.userId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') walletData = data['data'];
      }
    } catch (e) {
      walletData = {'balance': 12540.0};
    }
  }

  Future<void> fetchSavingsBalance() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/user-savings/${widget.userId}'));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'success') savingsData = json['data'];
      }
    } catch (e) {}
  }

  Future<void> fetchUserGoals() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/goalslist/${widget.userId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          userGoals = List<Map<String, dynamic>>.from(data['data'] ?? []);
        }
      }
    } catch (e) {
      userGoals = [];
    }
  }

  // ================== API HELPERS ==================
  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Network error'};
    }
  }

  Future<void> deposit(double amount, String phone, {int? goalId}) async {
    final body = {
      "user_id": int.parse(widget.userId),
      "amount": amount.toInt(),
      "phone": phone.startsWith('0') ? '254${phone.substring(1)}' : phone,
    };
    if (goalId != null) body["goal_id"] = goalId;

    final res = await _post('/deposit', body);
    _showResult(res['message'] ?? 'STK Push sent!');
  }

  Future<void> withdraw(double amount, String phone) async {
    final res = await _post('/withdraw', {
      "user_id": int.parse(widget.userId),
      "amount": amount.toInt(),
      "phone": phone.startsWith('0') ? '254${phone.substring(1)}' : phone,
    });
    _showResult(res['message'] ?? 'Withdrawal sent!');
    if (res['status'] == 'success') _loadData();
  }

  Future<void> buyGoods({
    required String till,
    required double amount,
    String account = '',
    double roundUp = 0,
    int? goalId,
  }) async {
    final body = {
      "user_id": int.parse(widget.userId),
      "till_number": till,
      "amount": amount.toInt(),
    };
    if (account.isNotEmpty) body["account_number"] = account;
    if (roundUp > 0) body["round_up_savings"] = roundUp.toInt();
    if (goalId != null && roundUp > 0) body["goal_id"] = goalId;

    final res = await _post('/buy-goods-payment', body);
    _showResult(res['message'] ?? 'Payment initiated!');
  }

  Future<void> payBill({required double amount, required String paybill, required String account, required String phone}) async {
    final res = await _post('/process-paybill-payment', {
      "user_id": int.parse(widget.userId),
      "phone_number": phone.startsWith('0') ? '254${phone.substring(1)}' : phone,
      "amount": amount.toInt(),
      "merchant_paybill": paybill,
      "merchant_account": account,
    });
    _showResult(res['message'] ?? 'PayBill STK sent!');
  }

  void _showResult(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: msg.contains('success') || msg.contains('sent') ? Colors.green : Colors.red,
      ),
    );
  }

  // ================== GOAL PICKER ==================
  Future<int?> showGoalPicker() async {
    if (userGoals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active goals found. Create one first!')),
      );
      return null;
    }

    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Save Toward a Goal',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...userGoals.map((goal) {
                final progress = goal['progress'] ?? 0.0;
                return Card(
                  color: const Color(0xFF374151),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(goal['goal_name'] ?? 'Unnamed Goal', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Target: KES ${goal['goal_amount'] ?? 0}', style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: progress / 100,
                          backgroundColor: Colors.grey[700],
                          valueColor: const AlwaysStoppedAnimation(Color(0xFFF5BB1B)),
                        ),
                        Text('$progress% complete', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54),
                    onTap: () => Navigator.pop(context, goal['id']),
                  ),
                );
              }).toList(),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ================== DIALOGS WITH GOAL SUPPORT ==================
  void _showDepositDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Add Money', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (KES)', filled: true, fillColor: Color(0xFF374151)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.flag, size: 18),
              label: const Text('Save to a Goal (Optional)'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5BB1B)),
              onPressed: () => showGoalPicker(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5BB1B)),
            onPressed: () async {
              final amt = double.tryParse(ctrl.text);
              if (amt != null && amt > 0) {
                Navigator.pop(context);
                final goalId = await showGoalPicker();
                deposit(amt, userDetails?['phone'] ?? '0712345678', goalId: goalId);
              }
            },
            child: const Text('Send STK', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Withdraw', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (KES)', filled: true, fillColor: Color(0xFF374151)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5BB1B)),
            onPressed: () {
              final amt = double.tryParse(ctrl.text);
              if (amt != null && amt > 0) {
                Navigator.pop(context);
                withdraw(amt, userDetails?['phone'] ?? '0712345678');
              }
            },
            child: const Text('Withdraw', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showPayMerchantDialog() {
    final tillCtrl = TextEditingController();
    final paybillCtrl = TextEditingController();
    final accountCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final roundCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pay Merchant', style: TextStyle(color: Colors.white)),
              Switch(
                value: _isPayBillMode,
                activeColor: const Color(0xFFF5BB1B),
                onChanged: (val) {
                  setDialogState(() => _isPayBillMode = val);
                  setState(() => _isPayBillMode = val);
                },
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedCrossFade(
                firstChild: Column(children: [
                  TextField(controller: tillCtrl, decoration: const InputDecoration(labelText: 'Till Number', filled: true, fillColor: Color(0xFF374151))),
                  const SizedBox(height: 12),
                  const Text('Buy Goods / Till', style: TextStyle(color: Colors.white70)),
                ]),
                secondChild: Column(children: [
                  TextField(controller: paybillCtrl, decoration: const InputDecoration(labelText: 'PayBill Number', filled: true, fillColor: Color(0xFF374151))),
                  const SizedBox(height: 12),
                  TextField(controller: accountCtrl, decoration: const InputDecoration(labelText: 'Account Number', filled: true, fillColor: Color(0xFF374151))),
                  const SizedBox(height: 12),
                  const Text('PayBill', style: TextStyle(color: Colors.white70)),
                ]),
                crossFadeState: _isPayBillMode ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (KES)', filled: true, fillColor: Color(0xFF374151)),
              ),
              const SizedBox(height: 12),
              if (!_isPayBillMode)
                TextField(
                  controller: roundCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Round-up Savings (Optional)', filled: true, fillColor: Color(0xFF374151)),
                ),
              if (!_isPayBillMode && (double.tryParse(roundCtrl.text) ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.flag, size: 18),
                    label: const Text('Save Round-up to Goal'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5BB1B)),
                    onPressed: () => showGoalPicker(),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5BB1B)),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0;
                final round = double.tryParse(roundCtrl.text) ?? 0;
                if (amt <= 0) return;

                int? selectedGoalId;
                if (!_isPayBillMode && round > 0) {
                  selectedGoalId = await showGoalPicker();
                }

                Navigator.pop(context);

                if (_isPayBillMode) {
                  if (paybillCtrl.text.isNotEmpty && accountCtrl.text.isNotEmpty) {
                    payBill(
                      amount: amt,
                      paybill: paybillCtrl.text,
                      account: accountCtrl.text,
                      phone: userDetails?['phone'] ?? '0712345678',
                    );
                  }
                } else {
                  if (tillCtrl.text.isNotEmpty) {
                    buyGoods(
                      till: tillCtrl.text,
                      amount: amt,
                      roundUp: round,
                      goalId: selectedGoalId,
                    );
                  }
                }
              },
              child: Text(_isPayBillMode ? 'Send STK' : 'Pay', style: const TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  void _startGlobalSendFlow() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GlobalSendFlow(
        userId: widget.userId,
        onSuccess: () => _loadData(),
      ),
    ));
  }

  // ================== UNIFORM QUICK LINK CARD ==================
  Widget _buildQuickLinkCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: (MediaQuery.of(context).size.width - 52) / 2,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balance = walletData?['balance']?.toDouble() ?? 0.0;
    final savings = savingsData?['total_savings']?.toDouble() ?? 0.0;
    final fullName = userDetails?['full_name'] ?? 'User';
    final firstName = fullName.split(' ').first;
    final profilePic = userDetails?['selfie_path'];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: SpinKitFadingCircle(color: Color(0xFFF5BB1B), size: 60))
          : Padding(
        padding: const EdgeInsets.only(top: 80),
            child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                ),
                child: Column(
                  children: [
                    // Wallet Balance Section - 25% of screen
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.25,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                    child: profilePic != null && profilePic.isNotEmpty
                                        ? ClipOval(child: CachedNetworkImage(imageUrl: profilePic, fit: BoxFit.cover, width: 40, height: 40))
                                        : const Icon(Icons.person, size: 24, color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text("Hello, $firstName", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                      const Text("Your money is growing", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    ]),
                                  ),
                                ]),
                                const SizedBox(height: 16),
                                const Text("Wallet Balance", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text("KES ${balance.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 28, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text("Savings: KES ${savings.toStringAsFixed(2)}", style: const TextStyle(color: Color(0xFFF5BB1B), fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Action Buttons Section - 15% of screen
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.12,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                              _buildActionButton(icon: Icons.add_circle_outline, label: 'Add', onTap: _showDepositDialog),
                              _buildActionButton(icon: Icons.arrow_downward, label: 'Withdraw', onTap: _showWithdrawDialog),
                              _buildActionButton(icon: Icons.send, label: 'Send', onTap: _startGlobalSendFlow),
                              _buildActionButton(icon: Icons.payment, label: 'Pay', onTap: _showPayMerchantDialog),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    // Quick Links Section - Remaining space
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Quick Links",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 10,
                              children: [
                                _buildQuickLinkCard(
                                  icon: Icons.work,
                                  title: "Jobs",
                                  color: Colors.green,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobsPage(userId: widget.userId))),
                                ),
                                _buildQuickLinkCard(
                                  icon: Icons.account_balance,
                                  title: "Loans",
                                  color: Colors.cyan,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoanProducts(userId: widget.userId))),
                                ),
                                _buildQuickLinkCard(
                                  icon: Icons.flag,
                                  title: "Goals",
                                  color: Colors.purpleAccent,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GoalsDashboard(userId: widget.userId))),
                                ),
                                _buildQuickLinkCard(
                                  icon: Icons.leaderboard,
                                  title: "Leaderboard",
                                  color: Colors.orangeAccent,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaderboardPage(userId: widget.userId))),
                                ),
                                _buildQuickLinkCard(
                                  icon: Icons.health_and_safety,
                                  title: "Credit Health",
                                  color: Colors.redAccent,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoansCreditScore(userId: widget.userId))),
                                ),
                                _buildQuickLinkCard(
                                  icon: Icons.bar_chart,
                                  title: "Analytics",
                                  color: Colors.blueAccent,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SavingsDashboard(userId: widget.userId))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) return;
          final routes = [
            null,
            MaterialPageRoute(builder: (context) => LoanProducts(userId: widget.userId)),
            MaterialPageRoute(builder: (context) => BuyGoodsSelect(userId: widget.userId)),
            MaterialPageRoute(builder: (context) => Profile(userId: widget.userId)),
          ];
          if (index < routes.length && routes[index] != null) {
            Navigator.push(context, routes[index]!);
          }
        },
        backgroundColor: const Color(0xFF1E293B).withOpacity(0.9),
        selectedItemColor: const Color(0xFFF5BB1B),
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: 'Loans'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Buy Goods'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ================== GLASS CARD ==================
class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({required this.child, super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), child: child),
      ),
    );
  }
}

// ================== GLOBAL SEND FLOW ==================
class GlobalSendFlow extends StatefulWidget {
  final String userId;
  final VoidCallback? onSuccess;
  const GlobalSendFlow({super.key, required this.userId, this.onSuccess});

  @override
  State<GlobalSendFlow> createState() => _GlobalSendFlowState();
}

class _GlobalSendFlowState extends State<GlobalSendFlow> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  String selectedCountry = 'Kenya';
  String selectedChannel = 'M-Pesa';
  String recipientPhone = '';
  String recipientName = '';
  String amount = '';
  String reason = '';
  String description = '';
  bool _isLoading = false;

  void _next() {
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _prev() {
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  bool _canProceedStep1() => true;

  bool _canProceedStep2() => recipientPhone.trim().length >= 9 && recipientName.trim().isNotEmpty;

  bool _canProceedStep3() => double.tryParse(amount) != null && double.tryParse(amount)! > 0;

  Future<void> _sendMoney() async {
    setState(() => _isLoading = true);
    final amt = double.tryParse(amount) ?? 0;
    if (amt <= 0) {
      setState(() => _isLoading = false);
      return;
    }

    final provider = selectedChannel == 'M-Pesa'
        ? 'm-pesa'
        : selectedChannel == 'Airtel Money'
            ? 'airtel-money'
            : selectedChannel == 'Bitcoin'
                ? 'bitlipa'
                : 'bank-ke';

    String phone = recipientPhone.trim();
    if (phone.startsWith('0')) phone = '254${phone.substring(1)}';
    if (!phone.startsWith('254')) phone = '254$phone';

    final nameParts = recipientName.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    try {
      final res = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/remittance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "user_id": int.parse(widget.userId),
          "amount": amt.toInt(),
          "currency": "KES",
          "provider": provider,
          "phone": phone,
          "first_name": firstName,
          "last_name": lastName,
          if (description.isNotEmpty) "description": description,
        }),
      );

      final json = jsonDecode(res.body);
      if (json['status'] == 'success') {
        widget.onSuccess?.call();
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(json['message'] ?? 'Transaction completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0F172A)),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Send Money Globally'),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1E293B),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => Container(
                  width: 40,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: i <= _currentStep ? const Color(0xFFF5BB1B) : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text('Where are you sending?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 32),
                        DropdownButtonFormField<String>(
                          value: selectedCountry,
                          decoration: const InputDecoration(labelText: 'Country', filled: true, fillColor: Color(0xFF374151)),
                          dropdownColor: const Color(0xFF374151),
                          style: const TextStyle(color: Colors.white),
                          items: ['Kenya', 'Uganda', 'Tanzania', 'Rwanda', 'USA'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => selectedCountry = v!),
                        ),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<String>(
                          value: selectedChannel,
                          decoration: const InputDecoration(labelText: 'Send via', filled: true, fillColor: Color(0xFF374151)),
                          dropdownColor: const Color(0xFF374151),
                          style: const TextStyle(color: Colors.white),
                          items: ['M-Pesa', 'Airtel Money', 'Bank Transfer', 'Bitcoin'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => selectedChannel = v!),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _canProceedStep1() ? _next : null,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5BB1B), minimumSize: const Size(double.infinity, 56)),
                          child: const Text('Continue', style: TextStyle(color: Colors.black)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text('Recipient Details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 32),
                        TextField(
                          onChanged: (v) => setState(() => recipientPhone = v),
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Phone', prefixText: '+254 ', filled: true, fillColor: Color(0xFF374151)),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (v) => setState(() => recipientName = v),
                          decoration: const InputDecoration(labelText: 'Full Name', filled: true, fillColor: Color(0xFF374151)),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: _prev, child: const Text('Back'))),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _canProceedStep2() ? _next : null,
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5BB1B)),
                                child: const Text('Continue', style: TextStyle(color: Colors.black)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text('Amount & Reason', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 32),
                        TextField(
                          onChanged: (v) => setState(() => amount = v),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Amount (KES)', filled: true, fillColor: Color(0xFF374151)),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (v) => reason = v,
                          decoration: const InputDecoration(labelText: 'Reason', filled: true, fillColor: Color(0xFF374151)),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (v) => description = v,
                          decoration: const InputDecoration(labelText: 'Note (Optional)', filled: true, fillColor: Color(0xFF374151)),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: _prev, child: const Text('Back'))),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _canProceedStep3() ? _next : null,
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5BB1B)),
                                child: const Text('Review', style: TextStyle(color: Colors.black)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text('Review & Send', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 32),
                        Card(
                          color: const Color(0xFF1E293B),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                _reviewRow('To', recipientName),
                                _reviewRow('Phone', '+254$recipientPhone'),
                                _reviewRow('Via', selectedChannel),
                                _reviewRow('Amount', 'KES ${double.tryParse(amount)?.toStringAsFixed(2) ?? amount}'),
                                _reviewRow('Reason', reason.isEmpty ? 'None' : reason),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        _isLoading
                            ? const CircularProgressIndicator(color: Color(0xFFF5BB1B))
                            : Row(
                                children: [
                                  Expanded(child: OutlinedButton(onPressed: _prev, child: const Text('Back'))),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _sendMoney,
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5BB1B)),
                                      child: const Text('Confirm & Send', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}