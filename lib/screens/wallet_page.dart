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
import 'loans_credit_score.dart';
import 'profile.dart';
import 'goals_dashboard.dart';
import 'ask_nia_screen.dart';
import 'expenditure_screen.dart';
import 'finance_manager_screen.dart';

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
  bool _paymentPending = false;
  String? _lastError;
  bool _retryCountdown = false;
  int _retrySecondsLeft = 60;

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
      walletData = {'balance': 0.0};
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
      "phone": phone,
    };
    if (goalId != null) body["goal_id"] = goalId;

    final res = await _post('/deposit', body);
    if (res['status'] == 'success') {
      final checkoutId = res['checkout_id']?.toString() ?? '';
      setState(() => _paymentPending = true);

      // Poll transaction status every 5s for up to 60s
      String paymentStatus = 'PENDING';
      for (int i = 0; i < 12; i++) {
        await Future.delayed(const Duration(seconds: 5));
        if (!mounted) return;
        try {
          final statusRes = await http.get(
            Uri.parse('$baseUrl/transaction-status/$checkoutId'),
          );
          if (statusRes.statusCode == 200) {
            final statusData = jsonDecode(statusRes.body);
            paymentStatus = statusData['payment_status'] ?? 'PENDING';
            if (paymentStatus == 'SUCCESS' || paymentStatus == 'FAILED') break;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _paymentPending = false);
        if (paymentStatus == 'SUCCESS') {
          setState(() => _lastError = null);
          await _loadData();
          _showResult('Deposit successful! Wallet updated.');
        } else if (paymentStatus == 'FAILED') {
          _triggerRetry('Payment was declined by the provider. You can retry in 60 seconds.');
        } else {
          await _loadData();
          _showResult('Payment sent — balance will update shortly.');
        }
      }
    } else {
      _triggerRetry(res['message'] ?? 'Payment failed — please try again');
    }
  }

  void _triggerRetry(String error) {
    setState(() {
      _lastError = error;
      _retryCountdown = true;
      _retrySecondsLeft = 60;
    });
    _showResult(error);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _retrySecondsLeft--);
      if (_retrySecondsLeft <= 0) {
        setState(() => _retryCountdown = false);
        return false;
      }
      return true;
    });
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

    final res = await _post('/pay-merchant', body);
    if (res['status'] == 'success') {
      await _loadData();
      _showResult(res['message'] ?? 'Payment successful!');
    } else {
      _triggerRetry(res['message'] ?? 'Payment failed — please try again');
    }
  }

  Future<void> payBill({required double amount, required String paybill, required String account}) async {
    final res = await _post('/process-paybill-payment', {
      "user_id": int.parse(widget.userId),
      "amount": amount.toInt(),
      "merchant_paybill": paybill,
      "merchant_account": account,
    });
    if (res['status'] == 'success') {
      await _loadData();
      _showResult(res['message'] ?? 'PayBill payment sent!');
    } else {
      _triggerRetry(res['message'] ?? 'PayBill failed — please try again');
    }
  }

  void _showResult(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: msg.contains('success') || msg.contains('sent')
            ? AppColors.financeGreenV3
            : AppTheme.errorColor,
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
      backgroundColor: AppTheme.cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final mq = MediaQuery.of(context);
        final bottomPadding = mq.viewInsets.bottom + mq.padding.bottom + 20;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Save Toward a Goal',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...userGoals.map((goal) {
                final progress = goal['progress'] ?? 0.0;
                return Card(
                  color: AppColors.coreWhiteW1,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(goal['goal_name'] ?? 'Unnamed Goal', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Target: KES ${goal['goal_amount'] ?? 0}', style: const TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: progress / 100,
                          backgroundColor: AppColors.coreWhiteW2,
                          valueColor: AlwaysStoppedAnimation(AppColors.financeGreenV3),
                        ),
                        Text('$progress% complete', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.textSecondary),
                    onTap: () => Navigator.pop(context, goal['id']),
                  ),
                );
              }),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ================== DIALOGS ==================
  void _showDepositDialog() {
    final defaultPhone = userDetails?['phone_number']?.toString() ?? '';
    final amtCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: defaultPhone);
    int? selectedGoalId;
    String? selectedGoalName;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B6631), Color(0xFF6BB046)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.add, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Money', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('M-Pesa STK Push', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount field
                      const Text('Amount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6b7280))),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFf8fdf8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFe8f5e2), width: 1.5),
                        ),
                        child: TextField(
                          controller: amtCtrl,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                          decoration: const InputDecoration(
                            prefixText: 'KES  ',
                            prefixStyle: TextStyle(fontSize: 16, color: Color(0xFF6b7280), fontWeight: FontWeight.w500),
                            hintText: '0',
                            hintStyle: TextStyle(fontSize: 22, color: Color(0xFFd1d5db)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Phone field — editable
                      const Text('Send STK to', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6b7280))),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFf8fdf8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFe8f5e2), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 14),
                              child: Icon(Icons.phone_android, size: 18, color: Color(0xFF6BB046)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: phoneCtrl,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(fontSize: 15, color: Color(0xFF111827), fontWeight: FontWeight.w500),
                                decoration: const InputDecoration(
                                  hintText: '+254700000000',
                                  hintStyle: TextStyle(color: Color(0xFFd1d5db)),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Text('edit', style: TextStyle(fontSize: 11, color: Color(0xFF6BB046), fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Goal selector
                      GestureDetector(
                        onTap: () async {
                          final id = await showGoalPicker();
                          if (id != null) {
                            final goal = userGoals.firstWhere((g) => g['id'] == id, orElse: () => {});
                            setLocal(() {
                              selectedGoalId = id;
                              selectedGoalName = goal['goal_name']?.toString() ?? 'Goal';
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedGoalId != null
                                ? const Color(0xFFf0fdf4)
                                : const Color(0xFFf8fdf8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedGoalId != null
                                  ? const Color(0xFF6BB046)
                                  : const Color(0xFFe8f5e2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selectedGoalId != null ? Icons.flag : Icons.flag_outlined,
                                size: 16,
                                color: const Color(0xFF6BB046),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedGoalId != null
                                      ? 'Saving to: $selectedGoalName'
                                      : 'Link to a savings goal (optional)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: selectedGoalId != null
                                        ? const Color(0xFF1B6631)
                                        : const Color(0xFF9ca3af),
                                    fontWeight: selectedGoalId != null ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right, size: 16, color: const Color(0xFF9ca3af)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: Color(0xFFe8f5e2), width: 1.5),
                          ),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF6b7280), fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: StatefulBuilder(
                          builder: (_, __) => Column(
                            children: [
                              if (_lastError != null) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Text(
                                    _lastError!,
                                    style: TextStyle(color: Colors.red.shade700, fontSize: 11),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                              ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B6631),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: _retryCountdown ? null : () {
                            final amt = double.tryParse(amtCtrl.text);
                            final phone = phoneCtrl.text.trim();
                            if (amt != null && amt > 0 && phone.isNotEmpty) {
                              Navigator.pop(ctx);
                              final normalizedPhone = phone.startsWith('0')
                                  ? '254${phone.substring(1)}'
                                  : phone.replaceFirst('+', '');
                              deposit(amt, normalizedPhone, goalId: selectedGoalId);
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_to_mobile, size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                _retryCountdown ? 'Retry in ${_retrySecondsLeft}s...' : 'Send STK',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWithdrawDialog() {
    final amtCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: userDetails?['phone_number'] ?? '');
    final balance = (walletData?['balance'] ?? 0).toDouble();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_downward_rounded, color: AppColors.financeGreen),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Withdraw to M-Pesa', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                Text('Wallet balance: KES ${balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ]),
            ]),
            const SizedBox(height: 24),
            const Text('Phone Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'e.g. 0712345678',
                prefixIcon: const Icon(Icons.phone_android_rounded, color: AppColors.financeGreen, size: 20),
                filled: true, fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Amount (KES)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            TextField(
              controller: amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('KES', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151), fontSize: 14)),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                filled: true, fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.financeGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final amt = double.tryParse(amtCtrl.text);
                    final phone = phoneCtrl.text.trim();
                    if (amt != null && amt > 0 && phone.isNotEmpty) {
                      Navigator.pop(context);
                      withdraw(amt, phone);
                    }
                  },
                  child: const Text('Withdraw', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ]),
        ),
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
          backgroundColor: AppTheme.cardLight,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pay Merchant', style: TextStyle(color: AppTheme.textPrimary)),
              Switch(
                value: _isPayBillMode,
                activeColor: AppColors.financeGreenV3,
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
                  TextField(controller: tillCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Till Number')),
                  const SizedBox(height: 12),
                  const Text('Buy Goods / Till', style: TextStyle(color: AppTheme.textSecondary)),
                ]),
                secondChild: Column(children: [
                  TextField(controller: paybillCtrl, decoration: const InputDecoration(labelText: 'PayBill Number')),
                  const SizedBox(height: 12),
                  TextField(controller: accountCtrl, decoration: const InputDecoration(labelText: 'Account Number')),
                  const SizedBox(height: 12),
                  const Text('PayBill', style: TextStyle(color: AppTheme.textSecondary)),
                ]),
                crossFadeState: _isPayBillMode ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (KES)'),
              ),
              const SizedBox(height: 12),
              if (!_isPayBillMode)
                TextField(
                  controller: roundCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Round-up Savings (Optional)'),
                ),
              if (!_isPayBillMode && (double.tryParse(roundCtrl.text) ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.flag, size: 18),
                    label: const Text('Save Round-up to Goal'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreenV3),
                    onPressed: () => showGoalPicker(),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreenV3),
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
              child: Text(_isPayBillMode ? 'Send STK' : 'Pay', style: const TextStyle(color: AppTheme.textLight)),
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

  // ================== QUICK LINK CARD ==================
  Widget _buildQuickLinkCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.cardLight,
          boxShadow: [BoxShadow(color: AppColors.financeGreen.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.financeGreen.withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
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
    final initials = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U';

    return Stack(
      children: [
        Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: isLoading
          ? Center(child: SpinKitFadingCircle(color: AppColors.financeGreenV3, size: 60))
          : Column(
              children: [
                // ── Hero Header ──
                Container(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.heroGradient,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: greeting left, avatar right
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Good day,', style: TextStyle(color: AppTheme.textLight.withValues(alpha: 0.75), fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(firstName, style: const TextStyle(color: AppTheme.textLight, fontSize: 22, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Profile(userId: widget.userId))),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.coreWhite.withValues(alpha: 0.4), width: 2),
                                  ),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: AppColors.financeGreenV2,
                                    child: profilePic != null && profilePic.isNotEmpty
                                        ? ClipOval(child: CachedNetworkImage(imageUrl: profilePic, fit: BoxFit.cover, width: 48, height: 48, errorWidget: (_, __, ___) => Text(initials, style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 16))))
                                        : Text(initials, style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Balance section — left aligned, clean
                          Text('Wallet Balance', style: TextStyle(color: AppTheme.textLight.withValues(alpha: 0.7), fontSize: 12, letterSpacing: 0.8)),
                          const SizedBox(height: 4),
                          Text(
                            'KES ${balance.toStringAsFixed(2)}',
                            style: const TextStyle(color: AppTheme.textLight, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 12),
                          // Savings row
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.coreWhite.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.trending_up_rounded, color: AppTheme.textLight, size: 14),
                                    const SizedBox(width: 5),
                                    Text('Savings  KES ${savings.toStringAsFixed(2)}',
                                      style: const TextStyle(color: AppTheme.textLight, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Action buttons card (overlaps the bottom of hero) ──
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardLight,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: AppColors.financeGreen.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 6))],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(icon: Icons.add_circle_outline, label: 'Add', onTap: _showDepositDialog),
                          _buildActionButton(icon: Icons.arrow_downward_rounded, label: 'Withdraw', onTap: _showWithdrawDialog),
                          _buildActionButton(icon: Icons.send_rounded, label: 'Send', onTap: _startGlobalSendFlow),
                          _buildActionButton(icon: Icons.payments_outlined, label: 'Pay', onTap: _showPayMerchantDialog),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Quick Links ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quick Links', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.1,
                          children: [
                            _buildQuickLinkCard(icon: Icons.smart_toy_outlined, title: 'Ask Nia', color: AppColors.financeGreenV2, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AskNiaScreen(userId: widget.userId)))),
                            _buildQuickLinkCard(icon: Icons.account_balance_outlined, title: 'Loans', color: AppColors.financeGreen, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoanProducts(userId: widget.userId)))),
                            _buildQuickLinkCard(icon: Icons.flag_outlined, title: 'Goals', color: AppColors.financeGreenV3, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GoalsDashboard(userId: widget.userId)))),
                            _buildQuickLinkCard(icon: Icons.leaderboard_outlined, title: 'Leaderboard', color: AppColors.financeGreenV2, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaderboardPage(userId: widget.userId)))),
                            _buildQuickLinkCard(icon: Icons.verified_user_outlined, title: 'Credit Health', color: AppColors.financeGreen, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoansCreditScore(userId: widget.userId)))),
                            _buildQuickLinkCard(icon: Icons.receipt_long_outlined, title: 'Expenditure', color: AppColors.financeGreenV3, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenditureScreen(userId: widget.userId)))),
                            _buildQuickLinkCard(icon: Icons.account_balance_wallet_outlined, title: 'Finance Manager', color: AppColors.financeGreen, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FinanceManagerScreen(userId: widget.userId)))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ),
        // Payment pending overlay
        if (_paymentPending)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SpinKitFadingCircle(color: AppColors.financeGreenV3, size: 56),
                      const SizedBox(height: 24),
                      const Text(
                        'Check your phone',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your SasaPay PIN to complete the payment',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF6b7280)),
                      ),
                      const SizedBox(height: 20),
                      _PaymentCountdown(
                        seconds: 60,
                        onDone: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ================== PAYMENT COUNTDOWN ==================
class _PaymentCountdown extends StatefulWidget {
  final int seconds;
  final VoidCallback onDone;
  const _PaymentCountdown({required this.seconds, required this.onDone});

  @override
  State<_PaymentCountdown> createState() => _PaymentCountdownState();
}

class _PaymentCountdownState extends State<_PaymentCountdown> {
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _tick();
  }

  void _tick() {
    if (!mounted) return;
    if (_remaining <= 0) { widget.onDone(); return; }
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _remaining--);
      _tick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remaining / widget.seconds;
    return Column(
      children: [
        SizedBox(
          width: 56, height: 56,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                backgroundColor: const Color(0xFFe8f5e2),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6BB046)),
              ),
              Center(
                child: Text(
                  '$_remaining',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B6631)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text('seconds remaining', style: TextStyle(fontSize: 11, color: Color(0xFF9ca3af))),
      ],
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
        color: AppColors.financeGreenV2.withValues(alpha: 0.3),
        border: Border.all(color: AppTheme.textLight.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
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

    String phone = recipientPhone.trim();
    if (phone.startsWith('0')) phone = '254${phone.substring(1)}';
    if (phone.startsWith('+')) phone = phone.substring(1);
    if (!phone.startsWith('254')) phone = '254$phone';

    try {
      final res = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/withdraw'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "user_id": int.parse(widget.userId),
          "amount": amt.toInt(),
          "phone": phone,
        }),
      );

      final json = jsonDecode(res.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(json['message'] ?? 'Transaction completed'),
            backgroundColor: json['status'] == 'success' ? const Color(0xFF059669) : const Color(0xFFDC2626),
          ),
        );
        if (json['status'] == 'success') {
          widget.onSuccess?.call();
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
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
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Send Money Globally'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.financeGreenV2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => Container(
                width: 40,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: i <= _currentStep ? AppColors.financeGreenV3 : AppColors.coreWhiteW2,
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
                      const Text('Where are you sending?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 32),
                      DropdownButtonFormField<String>(
                        value: selectedCountry,
                        decoration: const InputDecoration(labelText: 'Country'),
                        items: ['Kenya', 'Uganda', 'Tanzania', 'Rwanda', 'USA'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => selectedCountry = v!),
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        value: selectedChannel,
                        decoration: const InputDecoration(labelText: 'Send via'),
                        items: ['M-Pesa', 'Airtel Money', 'Bank Transfer', 'Bitcoin'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => selectedChannel = v!),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _canProceedStep1() ? _next : null,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreenV3, minimumSize: const Size(double.infinity, 56)),
                        child: const Text('Continue', style: TextStyle(color: AppTheme.textLight)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text('Recipient Details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 32),
                      TextField(
                        onChanged: (v) => setState(() => recipientPhone = v),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone', prefixText: '+254 '),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (v) => setState(() => recipientName = v),
                        decoration: const InputDecoration(labelText: 'Full Name'),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: _prev, child: const Text('Back'))),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _canProceedStep2() ? _next : null,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreenV3),
                              child: const Text('Continue', style: TextStyle(color: AppTheme.textLight)),
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
                      const Text('Amount & Reason', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 32),
                      TextField(
                        onChanged: (v) => setState(() => amount = v),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Amount (KES)'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (v) => reason = v,
                        decoration: const InputDecoration(labelText: 'Reason'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (v) => description = v,
                        decoration: const InputDecoration(labelText: 'Note (Optional)'),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: _prev, child: const Text('Back'))),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _canProceedStep3() ? _next : null,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreenV3),
                              child: const Text('Review', style: TextStyle(color: AppTheme.textLight)),
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
                      const Text('Review & Send', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 32),
                      Card(
                        color: AppTheme.cardLight,
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
                          ? CircularProgressIndicator(color: AppColors.financeGreenV3)
                          : Row(
                              children: [
                                Expanded(child: OutlinedButton(onPressed: _prev, child: const Text('Back'))),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _sendMoney,
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreenV3),
                                    child: const Text('Confirm & Send', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _reviewRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
            Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
