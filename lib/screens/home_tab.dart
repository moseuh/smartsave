import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../config/api_config.dart';
import '../services/onesignal_service.dart';
import 'buygoodselect.dart';
import 'transactiohistory.dart';
import 'ask_nia_screen.dart';
import 'notifications_screen.dart';

class HomeTab extends StatefulWidget {
  final String userId;
  const HomeTab({super.key, required this.userId});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _savings;
  List<Map<String, dynamic>> _recent = [];
  bool _loading = true;
  bool _balanceHidden = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;
  final fmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _load();
    // Register this device with OneSignal linked to the user
    OneSignalService.registerUser(widget.userId);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.wait([_fetchUser(), _fetchWallet(), _fetchSavings(), _fetchRecent()]);
    setState(() => _loading = false);
    _fadeCtrl.forward(from: 0);
  }

  Future<void> _fetchUser() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.userDetailsById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') setState(() => _user = d['data']);
      }
    } catch (_) {}
  }

  Future<void> _fetchWallet() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.walletById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') setState(() => _wallet = d['data']);
      }
    } catch (_) {
      setState(() => _wallet = {'balance': 0.0});
    }
  }

  Future<void> _fetchSavings() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.userSavingsById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') setState(() => _savings = d['data']);
      }
    } catch (_) {}
  }

  Future<void> _fetchRecent() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.transactionsById(widget.userId.toString())));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') {
          final raw = List<Map<String, dynamic>>.from(d['data'] ?? []);
          setState(() => _recent = raw.take(5).toList());
        }
      }
    } catch (_) {}
  }

  void _showWithdraw() {
    final rawPhone = (_user?['phone_number'] ?? _user?['phone'] ?? '').toString();
    final phoneCtrl = TextEditingController(text: rawPhone);
    final amtCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WithdrawSheet(
        userId: widget.userId,
        phoneCtrl: phoneCtrl,
        amtCtrl: amtCtrl,
        onSuccess: () => _load(),
      ),
    );
  }

  String get _firstName {
    final name = _user?['full_name'] ?? _user?['user_name'] ?? 'there';
    return name.toString().split(' ').first;
  }

  String get _avatarUrl {
    final path = _user?['selfie_path']?.toString().replaceAll('\\', '/');
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl.replaceAll('/api', '')}/$path';
  }

  double get _balance => double.tryParse(_wallet?['balance']?.toString() ?? '0') ?? 0;
  double get _totalSaved => double.tryParse(_savings?['total_saved']?.toString() ?? '0') ?? 0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: RefreshIndicator(
        color: AppColors.financeGreenV3,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: AppTheme.backgroundLight,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, top > 0 ? 8 : 16, 20, 24),
                    child: Column(
                      children: [
                        // Top row
                        Row(
                          children: [
                            _Avatar(url: _avatarUrl, name: _firstName),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Good ${_greeting()},', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                                  Text(_firstName, style: const TextStyle(color: Color(0xFF111827), fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                                ],
                              ),
                            ),
                            _IconBtn(
                              icon: Icons.notifications_none_rounded,
                              onTap: () => Navigator.push(context, _slide(NotificationsScreen(userId: widget.userId))),
                            ),
                            const SizedBox(width: 8),
                            _IconBtn(
                              icon: Icons.smart_toy_outlined,
                              onTap: () => Navigator.push(context, _slide(AskNiaScreen(userId: widget.userId))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Balance card
                        _loading
                            ? const _Skeleton(height: 120)
                            : FadeTransition(
                                opacity: _fade,
                                child: _BalanceCard(
                                  balance: _balance,
                                  saved: _totalSaved,
                                  hidden: _balanceHidden,
                                  onToggle: () => setState(() => _balanceHidden = !_balanceHidden),
                                  fmt: fmt,
                                ),
                              ),
                        const SizedBox(height: 20),

                        // Quick actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _QuickAction(icon: Icons.add_rounded, label: 'Add Money', onTap: () => _showDeposit()),
                            _QuickAction(icon: Icons.send_rounded, label: 'Pay', onTap: () => Navigator.push(context, _slide(BuyGoodsSelect(userId: widget.userId)))),
                            _QuickAction(icon: Icons.arrow_upward_rounded, label: 'Withdraw', onTap: () => _showWithdraw()),
                            _QuickAction(icon: Icons.receipt_long_rounded, label: 'History', onTap: () => Navigator.push(context, _slide(TransactionHistory(userId: widget.userId)))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Nia AI banner
                  _NiaBanner(onTap: () => Navigator.push(context, _slide(AskNiaScreen(userId: widget.userId)))),
                  const SizedBox(height: 20),

                  // Recent transactions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      GestureDetector(
                        onTap: () => Navigator.push(context, _slide(TransactionHistory(userId: widget.userId))),
                        child: const Text('See all', style: TextStyle(fontSize: 13, color: AppColors.financeGreenV3, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_loading)
                    ...List.generate(3, (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: _Skeleton(height: 68),
                    ))
                  else if (_recent.isEmpty)
                    const _EmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: 'No transactions yet.\nStart saving today!',
                    )
                  else
                    ..._recent.map((t) => _TxTile(tx: t, fmt: fmt)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  void _showDeposit() {
    // Pre-fill phone — try multiple field names the API might return
    final rawPhone = (_user?['phone_number'] ?? _user?['phone'] ?? '').toString();
    final phoneCtrl = TextEditingController(text: rawPhone);
    final amtCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DepositSheet(
        userId: widget.userId,
        phoneCtrl: phoneCtrl,
        amtCtrl: amtCtrl,
        onSuccess: () => _load(), // refresh balance after deposit
      ),
    );
  }

  Route _slide(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      );
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String url;
  final String name;
  const _Avatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.3), width: 2),
      ),
      child: ClipOval(
        child: url.isNotEmpty
            ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initial())
            : _initial(),
      ),
    );
  }

  Widget _initial() => Container(
        color: AppColors.financeGreenV2,
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'N',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.financeGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.financeGreen, size: 22),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance, saved;
  final bool hidden;
  final VoidCallback onToggle;
  final NumberFormat fmt;
  const _BalanceCard({required this.balance, required this.saved, required this.hidden, required this.onToggle, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Wallet Balance', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500)),
              GestureDetector(
                onTap: onToggle,
                child: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.financeGreen, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hidden ? '••••••' : 'KES ${fmt.format(balance)}',
                style: const TextStyle(color: Color(0xFF111827), fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: const Color(0xFFF3F4F6)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BalanceStat(label: 'Total Saved', value: hidden ? '••••' : 'KES ${fmt.format(saved)}', icon: Icons.savings_rounded),
              _BalanceStat(label: 'Round-ups', value: 'Active', icon: Icons.loop_rounded, right: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool right;
  const _BalanceStat({required this.label, required this.value, required this.icon, this.right = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.financeGreen, size: 14),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
            Text(value, style: const TextStyle(color: Color(0xFF111827), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppColors.financeGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Color(0xFF374151), fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _NiaBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _NiaBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.smart_toy_outlined, color: AppColors.financeGreen, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ask Nia', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 3),
                  Text('Your AI financial assistant — analyses your SMS & spending', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB), size: 20),
          ],
        ),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  final NumberFormat fmt;
  const _TxTile({required this.tx, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final type = (tx['type']?.toString() ?? '').toLowerCase();
    final isIn = type.contains('deposit');
    // backend returns total_amount; fallback to amount for safety
    final amount = double.tryParse(
            (tx['total_amount'] ?? tx['amount'] ?? 0).toString()) ??
        0;
    final title = tx['business_name']?.toString().isNotEmpty == true
        ? tx['business_name'].toString()
        : type.contains('deposit')
            ? 'Deposit'
            : type.contains('pay_bill')
                ? 'Pay Bill'
                : type.contains('buy_goods')
                    ? 'Buy Goods'
                    : 'Transaction';
    final date = tx['created_at'] ?? '';
    String dateStr = '';
    try {
      final dt = DateTime.parse(date).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        dateStr = 'Today ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      } else {
        dateStr = DateFormat('d MMM, HH:mm').format(dt);
      }
    } catch (_) {}

    final iconData = isIn
        ? Icons.arrow_downward_rounded
        : type.contains('pay_bill')
            ? Icons.account_balance_rounded
            : type.contains('buy_goods')
                ? Icons.shopping_bag_rounded
                : Icons.arrow_upward_rounded;
    final color = isIn ? const Color(0xFF059669) : const Color(0xFFDC2626);

    return GestureDetector(
      onTap: () => showTransactionDetail(context, tx, fmt),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(iconData, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF111827)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (dateStr.isNotEmpty)
                  Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIn ? '+' : '-'}KES ${fmt.format(amount.abs())}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
              ),
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Completed', style: TextStyle(fontSize: 9, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: const Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}

// ── Deposit Sheet ─────────────────────────────────────────────────────────────

class _DepositSheet extends StatefulWidget {
  final String userId;
  final TextEditingController phoneCtrl;
  final TextEditingController amtCtrl;
  final VoidCallback onSuccess;
  const _DepositSheet({
    required this.userId,
    required this.phoneCtrl,
    required this.amtCtrl,
    required this.onSuccess,
  });

  @override
  State<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends State<_DepositSheet> {
  bool _loading = false;
  String? _error;
  // After STK sent — poll for status
  String? _checkoutRef;
  bool _polling = false;
  bool _paid = false;
  int _pollCount = 0; // incremented each poll cycle
  static const int _maxPolls = 22; // ~90 seconds (22 × 4s)

  @override
  void dispose() {
    _polling = false;
    super.dispose();
  }

  Future<void> _sendSTK() async {
    final amt = double.tryParse(widget.amtCtrl.text.replaceAll(',', ''));
    if (amt == null || amt < 1) {
      setState(() => _error = 'Enter a valid amount (min KES 1)');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final res = await http.post(
        Uri.parse(ApiConfig.getUrl('deposit')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'amount': amt,
          'phone': widget.phoneCtrl.text.trim(),
        }),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          _loading = false;
          _checkoutRef = data['checkout_id']?.toString() ?? '';
        });
        // Start polling for completion
        _startPolling();
      } else {
        setState(() {
          _loading = false;
          _error = data['message'] ?? 'Failed to send STK Push';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Network error — check your connection';
      });
    }
  }

  void _startPolling() {
    _polling = true;
    _pollCount = 0;
    Future.doWhile(() async {
      if (!_polling || !mounted) return false;
      await Future.delayed(const Duration(seconds: 4));
      if (!_polling || !mounted) return false;

      _pollCount++;

      // Timeout after ~90 seconds — tell user to check manually
      if (_pollCount >= _maxPolls) {
        if (mounted) {
          setState(() {
            _polling = false;
            _checkoutRef = null;
            _error = 'Timed out waiting for confirmation. If debited, your balance will update shortly.';
          });
        }
        return false;
      }

      try {
        final ref = _checkoutRef ?? '';
        if (ref.isEmpty) return false;
        final res = await http.get(
          Uri.parse(ApiConfig.transactionStatus(ref)),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        final data = jsonDecode(res.body);
        final status = (data['payment_status'] ?? data['status'] ?? '').toString().toUpperCase();

        if (status == 'SUCCESS' || status == 'COMPLETE' || status == 'COMPLETED') {
          if (mounted) {
            setState(() { _paid = true; _polling = false; });
            widget.onSuccess();
          }
          return false;
        } else if (status == 'FAILED' || status == 'CANCELLED' || status == 'EXPIRED') {
          if (mounted) {
            setState(() {
              _polling = false;
              _checkoutRef = null;
              _error = 'Payment ${status.toLowerCase()} — please try again';
            });
          }
          return false;
        }
      } catch (_) {}
      return true; // keep polling
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPadding = mq.viewInsets.bottom + mq.padding.bottom + 24;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          // ── Success state ──
          if (_paid) ...[
            const SizedBox(height: 8),
            Center(
              child: Column(children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.financeGreen, size: 40),
                ),
                const SizedBox(height: 16),
                const Text('Deposit Successful!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                const SizedBox(height: 6),
                Text('KES ${widget.amtCtrl.text} added to your wallet',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.financeGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),

          // ── Waiting for payment (STK sent) ──
          ] else if (_checkoutRef != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Column(children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: AppColors.financeGreenV3.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const CircularProgressIndicator(color: AppColors.financeGreen, strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                const Text('Check your phone',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                const SizedBox(height: 6),
                const Text('Enter your M-Pesa PIN to complete the deposit.\nWaiting for confirmation...',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => setState(() { _checkoutRef = null; _polling = false; }),
                  child: const Text('Cancel / Try again', style: TextStyle(color: Colors.red)),
                ),
              ]),
            ),
            const SizedBox(height: 8),

          // ── Input state ──
          ] else ...[
            const Text('Add Money via M-Pesa',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 20),

            // Amount
            _field(widget.amtCtrl, 'Amount (KES)', isNumber: true,
                prefix: const Text('KES ', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
            const SizedBox(height: 12),

            // Phone
            _field(widget.phoneCtrl, 'M-Pesa Phone Number', isNumber: true,
                prefix: const Icon(Icons.phone_android_rounded, size: 18, color: AppColors.financeGreen)),
            const SizedBox(height: 6),
            const Text('Your registered M-Pesa number',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red))),
                ]),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendSTK,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.financeGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Send STK Push',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint,
      {bool isNumber = false, Widget? prefix}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        prefixIcon: prefix != null ? Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: prefix) : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ── Withdraw Sheet ────────────────────────────────────────────────────────────

class _WithdrawSheet extends StatefulWidget {
  final String userId;
  final TextEditingController phoneCtrl;
  final TextEditingController amtCtrl;
  final VoidCallback onSuccess;
  const _WithdrawSheet({
    required this.userId,
    required this.phoneCtrl,
    required this.amtCtrl,
    required this.onSuccess,
  });

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  bool _loading = false;
  String? _error;
  bool _done = false;

  Future<void> _withdraw() async {
    final amt = double.tryParse(widget.amtCtrl.text.replaceAll(',', ''));
    if (amt == null || amt < 10) {
      setState(() => _error = 'Enter a valid amount (min KES 10)');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      String phone = widget.phoneCtrl.text.trim();
      if (phone.startsWith('0')) phone = '254${phone.substring(1)}';
      if (phone.startsWith('+')) phone = phone.substring(1);

      final res = await http.post(
        Uri.parse(ApiConfig.getUrl('withdraw')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'amount': amt.toInt(),
          'phone': phone,
        }),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['status'] == 'success') {
        setState(() { _loading = false; _done = true; });
        widget.onSuccess();
      } else {
        setState(() { _loading = false; _error = data['message'] ?? 'Withdrawal failed'; });
      }
    } catch (e) {
      setState(() { _loading = false; _error = 'Network error — check your connection'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPadding = mq.viewInsets.bottom + mq.padding.bottom + 24;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          if (_done) ...[
            Center(
              child: Column(children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.financeGreen, size: 40),
                ),
                const SizedBox(height: 16),
                const Text('Withdrawal Sent!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                const SizedBox(height: 6),
                const Text('M-Pesa will confirm shortly.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.financeGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
          ] else ...[
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: const Color(0xFFDC2626).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Withdraw to M-Pesa', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  Text('Funds sent directly to your phone', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ]),
            const SizedBox(height: 20),

            _wField(widget.amtCtrl, 'Amount (KES)', isNumber: true,
                prefix: const Text('KES ', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
            const SizedBox(height: 12),
            _wField(widget.phoneCtrl, 'M-Pesa Phone Number', isNumber: true,
                prefix: const Icon(Icons.phone_android_rounded, size: 18, color: Color(0xFFDC2626))),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red))),
                ]),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _withdraw,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Withdraw', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _wField(TextEditingController ctrl, String hint,
      {bool isNumber = false, Widget? prefix}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        prefixIcon: prefix != null ? Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: prefix) : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true, fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
