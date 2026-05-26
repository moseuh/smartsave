import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../config/api_config.dart';
import 'buygoodselect.dart';
import 'transactiohistory.dart';
import 'ask_nia_screen.dart';

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
      final r = await http.get(Uri.parse(ApiConfig.transactionsById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') {
          setState(() => _recent = List<Map<String, dynamic>>.from(d['data'] ?? []).take(5).toList());
        }
      }
    } catch (_) {}
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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F4023), Color(0xFF1B6631), Color(0xFF2D8A47)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, top > 0 ? 8 : 16, 20, 32),
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
                                  Text('Good ${_greeting()},', style: const TextStyle(color: Colors.white60, fontSize: 13)),
                                  Text(_firstName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                                ],
                              ),
                            ),
                            _IconBtn(
                              icon: Icons.notifications_none_rounded,
                              onTap: () {},
                              badge: true,
                            ),
                            const SizedBox(width: 8),
                            _IconBtn(
                              icon: Icons.smart_toy_outlined,
                              onTap: () => Navigator.push(context, _slide(AskNiaScreen(userId: widget.userId))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

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
                        const SizedBox(height: 24),

                        // Quick actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _QuickAction(icon: Icons.add_rounded, label: 'Add Money', onTap: () => _showDeposit()),
                            _QuickAction(icon: Icons.send_rounded, label: 'Pay', onTap: () => Navigator.push(context, _slide(BuyGoodsSelect(userId: widget.userId)))),
                            _QuickAction(icon: Icons.swap_horiz_rounded, label: 'Transfer', onTap: () {}),
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
    final phoneCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _Sheet(
        title: 'Add Money via M-Pesa',
        children: [
          _input(amtCtrl, 'Amount (KES)', isNumber: true),
          const SizedBox(height: 12),
          _input(phoneCtrl, 'M-Pesa Phone Number', isNumber: true),
          const SizedBox(height: 24),
          _GreenBtn(
            label: 'Send STK Push',
            onTap: () async {
              Navigator.pop(context);
              final amt = double.tryParse(amtCtrl.text);
              if (amt != null && phoneCtrl.text.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('STK Push sent — check your phone'), backgroundColor: AppColors.financeGreenV3),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _input(TextEditingController c, String hint, {bool isNumber = false}) {
    return TextField(
      controller: c,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
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
  final bool badge;
  const _IconBtn({required this.icon, required this.onTap, this.badge = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          if (badge)
            Positioned(
              top: -2, right: -2,
              child: Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(color: Color(0xFFFF4444), shape: BoxShape.circle),
              ),
            ),
        ],
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
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              GestureDetector(
                onTap: onToggle,
                child: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white60, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hidden ? '••••••' : 'KES ${fmt.format(balance)}',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
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
        Icon(icon, color: Colors.white60, size: 14),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
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
    final isIn = (tx['type']?.toString() ?? '').contains('deposit') || (tx['amount'] ?? 0) > 0;
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
    final date = tx['created_at'] ?? tx['date'] ?? '';
    String dateStr = '';
    try { dateStr = DateFormat('d MMM').format(DateTime.parse(date)); } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: (isIn ? const Color(0xFF059669) : const Color(0xFFDC2626)).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: isIn ? const Color(0xFF059669) : const Color(0xFFDC2626), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx['description'] ?? tx['type'] ?? 'Transaction',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF111827)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (dateStr.isNotEmpty)
                  Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          Text(
            '${isIn ? '+' : '-'} KES ${fmt.format(amount.abs())}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                color: isIn ? const Color(0xFF059669) : const Color(0xFFDC2626)),
          ),
        ],
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

class _Sheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Sheet({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _GreenBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GreenBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.financeGreen,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }
}
