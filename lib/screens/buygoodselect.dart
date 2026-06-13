import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';
import 'dart:async';
import 'favourites.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

// ─────────────────────────────────────────────────────────────────
//  BuyGoodsSelect — Payment Screen (Buy Goods · Pay Bill · Send Money)
// ─────────────────────────────────────────────────────────────────

class BuyGoodsSelect extends StatefulWidget {
  final String userId;
  const BuyGoodsSelect({super.key, required this.userId});

  @override
  State<BuyGoodsSelect> createState() => _BuyGoodsSelectState();
}

class _BuyGoodsSelectState extends State<BuyGoodsSelect>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Shared state
  Map<String, dynamic>? userDetails;
  Map<String, dynamic>? roundupSettings;
  bool _loadingInit = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _init();
  }

  Future<void> _init() async {
    await Future.wait([_fetchUser(), _fetchRoundup()]);
    if (mounted) setState(() => _loadingInit = false);
  }

  Future<void> _fetchUser() async {
    try {
      final r = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/user-details/${widget.userId}'),
      );
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') userDetails = d['data'];
      }
    } catch (_) {}
  }

  Future<void> _fetchRoundup() async {
    try {
      final r = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/roundup-settings/${widget.userId}'),
      );
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        d['is_enabled'] = (d['is_enabled'] == 1 || d['is_enabled'] == true);
        d['pay_bill_round_up'] = (d['pay_bill_round_up'] == 1 || d['pay_bill_round_up'] == true);
        d['buy_goods_round_up'] = (d['buy_goods_round_up'] == 1 || d['buy_goods_round_up'] == true);
        roundupSettings = d;
      }
    } catch (_) {}
  }

  String get _userPhone {
    if (userDetails == null) return '';
    for (final k in ['phone_number', 'phone', 'msisdn', 'mobile']) {
      final v = userDetails?[k]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  double _calcRoundUp(double amount, bool isBuyGoods) {
    if (roundupSettings == null) return 0;
    final enabled = roundupSettings!['is_enabled'] == true;
    final applies = isBuyGoods
        ? roundupSettings!['buy_goods_round_up'] == true
        : roundupSettings!['pay_bill_round_up'] == true;
    if (!enabled || !applies || amount <= 0) return 0;
    final rv = double.tryParse(
            roundupSettings!['rounding_value']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '10') ??
        10.0;
    final maxRU = double.tryParse(roundupSettings!['max_round_up']?.toString() ?? '400') ?? 400.0;
    final rounded = amount % rv == 0 ? amount + rv : (amount / rv).ceil() * rv;
    return (rounded - amount).clamp(0, maxRU);
  }

  String _normalizePhone(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (s.startsWith('0') && s.length >= 9) s = '254${s.substring(1)}';
    if (s.startsWith('7') && s.length == 9) s = '254$s';
    return s;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          // Back → go to MainShell (home), not SavingsDashboard
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        title: const Text('Pay',
            style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_outline_rounded, color: AppColors.financeGreen),
            tooltip: 'Saved Payees',
            onPressed: () => Navigator.push(
              context,
              _slide(Favourites(userId: widget.userId)),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.financeGreen,
          indicatorWeight: 3,
          labelColor: AppColors.financeGreen,
          unselectedLabelColor: const Color(0xFF9CA3AF),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'Buy Goods'),
            Tab(text: 'Pay Bill'),
            Tab(text: 'Send Money'),
          ],
        ),
      ),
      body: _loadingInit
          ? const Center(child: CircularProgressIndicator(color: AppColors.financeGreen))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _BuyGoodsTab(
                  userId: widget.userId,
                  userPhone: _userPhone,
                  calcRoundUp: _calcRoundUp,
                  normalizePhone: _normalizePhone,
                  roundupSettings: roundupSettings,
                ),
                _PayBillTab(
                  userId: widget.userId,
                  userPhone: _userPhone,
                  calcRoundUp: _calcRoundUp,
                  normalizePhone: _normalizePhone,
                  roundupSettings: roundupSettings,
                ),
                _SendMoneyTab(
                  userId: widget.userId,
                  userPhone: _userPhone,
                  normalizePhone: _normalizePhone,
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  BUY GOODS TAB
// ─────────────────────────────────────────────────────────────────

class _BuyGoodsTab extends StatefulWidget {
  final String userId, userPhone;
  final double Function(double, bool) calcRoundUp;
  final String Function(String) normalizePhone;
  final Map<String, dynamic>? roundupSettings;
  const _BuyGoodsTab({
    required this.userId,
    required this.userPhone,
    required this.calcRoundUp,
    required this.normalizePhone,
    required this.roundupSettings,
  });

  @override
  State<_BuyGoodsTab> createState() => _BuyGoodsTabState();
}

class _BuyGoodsTabState extends State<_BuyGoodsTab> {
  final _tillCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  bool _loading = false;
  double _roundUp = 0;

  List<Map<String, dynamic>> _favourites = [];

  @override
  void initState() {
    super.initState();
    _amtCtrl.addListener(_recalc);
    _loadFavourites();
  }

  Future<void> _loadFavourites() async {
    try {
      final r = await http.get(
          Uri.parse('${AppConstants.apiBaseUrl}/favourites/${widget.userId}'));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') {
          setState(() {
            _favourites = List<Map<String, dynamic>>.from(
                (d['data'] as List).where((f) => f['type'] == 'buy_goods'));
          });
        }
      }
    } catch (_) {}
  }

  void _recalc() {
    final amt = double.tryParse(_amtCtrl.text) ?? 0;
    setState(() => _roundUp = widget.calcRoundUp(amt, true));
  }

  double get _payAmt => double.tryParse(_amtCtrl.text) ?? 0;
  double get _total => _payAmt + _roundUp;

  Future<void> _confirm() async {
    final till = _tillCtrl.text.trim();
    final amt = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    if (till.isEmpty || amt <= 0) {
      _snack('Enter till number and amount');
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/pay-merchant'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': int.tryParse(widget.userId) ?? widget.userId,
          'till_number': till,
          'amount': amt,
          'round_up_savings': _roundUp,
        }),
      ).timeout(const Duration(seconds: 20));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['status'] == 'success') {
        _showSuccess(amt: _total, label: 'Till $till');
        _tillCtrl.clear();
        _amtCtrl.clear();
        setState(() => _roundUp = 0);
      } else {
        _snack(data['message'] ?? 'Payment failed', error: true);
      }
    } catch (e) {
      _snack('Network error — check connection', error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showSuccess({required double amt, required String label}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.financeGreen, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Payment Successful!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text('KES ${amt.toStringAsFixed(2)} paid to $label', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          const Text('Funds deducted from your Nebo wallet.', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.financeGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _saveFavourite() async {
    if (_tillCtrl.text.trim().isEmpty) return;
    try {
      await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/favourites'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'name': 'Till ${_tillCtrl.text.trim()}',
          'till_number': _tillCtrl.text.trim(),
          'account_number': '',
          'type': 'buy_goods',
        }),
      );
      _snack('Saved to favourites ✓');
      _loadFavourites();
    } catch (_) {}
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : AppColors.financeGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void dispose() {
    _tillCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, mq.padding.bottom + 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Saved favourites row
          if (_favourites.isNotEmpty) ...[
            const Text('Saved', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 66,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _favourites.length,
                itemBuilder: (_, i) {
                  final f = _favourites[i];
                  return GestureDetector(
                    onTap: () => setState(() => _tillCtrl.text = f['till_number']?.toString() ?? ''),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.25)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.store_rounded, color: AppColors.financeGreen, size: 18),
                        const SizedBox(height: 4),
                        Text(f['till_number']?.toString() ?? '',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          _label('Till Number'),
          _field(_tillCtrl, 'e.g. 123456',
              keyboardType: TextInputType.number,
              suffix: GestureDetector(
                onTap: _saveFavourite,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.favorite_outline_rounded, color: AppColors.financeGreen.withValues(alpha: 0.7), size: 16),
                    const SizedBox(width: 4),
                    Text('Save', style: TextStyle(fontSize: 11, color: AppColors.financeGreen.withValues(alpha: 0.8))),
                  ]),
                ),
              )),
          const SizedBox(height: 14),

          _label('Amount (KES)'),
          _field(_amtCtrl, '0.00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefix: const Text('KES ', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
          const SizedBox(height: 20),

          _SummaryCard(payAmt: _payAmt, roundUp: _roundUp, total: _total),
        ]),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, mq.padding.bottom + 16),
        child: _ConfirmBtn(loading: _loading, onTap: _confirm, label: 'Confirm Payment'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  PAY BILL TAB
// ─────────────────────────────────────────────────────────────────

class _PayBillTab extends StatefulWidget {
  final String userId, userPhone;
  final double Function(double, bool) calcRoundUp;
  final String Function(String) normalizePhone;
  final Map<String, dynamic>? roundupSettings;
  const _PayBillTab({
    required this.userId,
    required this.userPhone,
    required this.calcRoundUp,
    required this.normalizePhone,
    required this.roundupSettings,
  });

  @override
  State<_PayBillTab> createState() => _PayBillTabState();
}

class _PayBillTabState extends State<_PayBillTab> {
  final _paybillCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  bool _loading = false;
  double _roundUp = 0;

  List<Map<String, dynamic>> _favourites = [];

  @override
  void initState() {
    super.initState();
    _amtCtrl.addListener(_recalc);
    _loadFavourites();
  }

  Future<void> _loadFavourites() async {
    try {
      final r = await http.get(
          Uri.parse('${AppConstants.apiBaseUrl}/favourites/${widget.userId}'));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') {
          setState(() {
            _favourites = List<Map<String, dynamic>>.from(
                (d['data'] as List).where((f) => f['type'] == 'pay_bill'));
          });
        }
      }
    } catch (_) {}
  }

  void _recalc() {
    final amt = double.tryParse(_amtCtrl.text) ?? 0;
    setState(() => _roundUp = widget.calcRoundUp(amt, false));
  }

  double get _payAmt => double.tryParse(_amtCtrl.text) ?? 0;
  double get _total => _payAmt + _roundUp;

  Future<void> _confirm() async {
    final paybill = _paybillCtrl.text.trim();
    final account = _accountCtrl.text.trim();
    final amt = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    if (paybill.isEmpty || amt <= 0) {
      _snack('Enter paybill number and amount');
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/process-paybill-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': int.tryParse(widget.userId) ?? widget.userId,
          'amount': amt,
          'merchant_paybill': paybill,
          'merchant_account': account,
        }),
      ).timeout(const Duration(seconds: 20));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['status'] == 'success') {
        _showSuccess(amt: amt, label: 'PayBill $paybill');
        _paybillCtrl.clear();
        _accountCtrl.clear();
        _amtCtrl.clear();
        setState(() => _roundUp = 0);
      } else {
        _snack(data['message'] ?? 'Payment failed', error: true);
      }
    } catch (e) {
      _snack('Network error — check connection', error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showSuccess({required double amt, required String label}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.financeGreen, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Payment Successful!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text('KES ${amt.toStringAsFixed(2)} paid to $label', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          const Text('Funds deducted from your Nebo wallet.', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.financeGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _saveFavourite() async {
    if (_paybillCtrl.text.trim().isEmpty) return;
    try {
      await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/favourites'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'name': 'Paybill ${_paybillCtrl.text.trim()}',
          'till_number': _paybillCtrl.text.trim(),
          'account_number': _accountCtrl.text.trim(),
          'type': 'pay_bill',
        }),
      );
      _snack('Saved to favourites ✓');
      _loadFavourites();
    } catch (_) {}
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : AppColors.financeGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void dispose() {
    _paybillCtrl.dispose();
    _accountCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, mq.padding.bottom + 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_favourites.isNotEmpty) ...[
            const Text('Saved', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 66,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _favourites.length,
                itemBuilder: (_, i) {
                  final f = _favourites[i];
                  return GestureDetector(
                    onTap: () => setState(() {
                      _paybillCtrl.text = f['till_number']?.toString() ?? '';
                      _accountCtrl.text = f['account_number']?.toString() ?? '';
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.25)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.receipt_long_rounded, color: AppColors.financeGreen, size: 18),
                        const SizedBox(height: 4),
                        Text(f['till_number']?.toString() ?? '',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          _label('Pay Bill Number'),
          _field(_paybillCtrl, 'e.g. 400200',
              keyboardType: TextInputType.number,
              suffix: GestureDetector(
                onTap: _saveFavourite,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.favorite_outline_rounded, color: AppColors.financeGreen.withValues(alpha: 0.7), size: 16),
                    const SizedBox(width: 4),
                    Text('Save', style: TextStyle(fontSize: 11, color: AppColors.financeGreen.withValues(alpha: 0.8))),
                  ]),
                ),
              )),
          const SizedBox(height: 14),

          _label('Account Number'),
          _field(_accountCtrl, 'e.g. your account / reference',
              keyboardType: TextInputType.text),
          const SizedBox(height: 14),

          _label('Amount (KES)'),
          _field(_amtCtrl, '0.00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefix: const Text('KES ', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
          const SizedBox(height: 20),

          _SummaryCard(payAmt: _payAmt, roundUp: _roundUp, total: _total),
        ]),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, mq.padding.bottom + 16),
        child: _ConfirmBtn(loading: _loading, onTap: _confirm, label: 'Confirm Payment'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  SEND MONEY TAB
// ─────────────────────────────────────────────────────────────────

class _SendMoneyTab extends StatefulWidget {
  final String userId, userPhone;
  final String Function(String) normalizePhone;
  const _SendMoneyTab({
    required this.userId,
    required this.userPhone,
    required this.normalizePhone,
  });

  @override
  State<_SendMoneyTab> createState() => _SendMoneyTabState();
}

class _SendMoneyTabState extends State<_SendMoneyTab> {
  final _phoneCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  bool _loading = false;

  // Recently sent (from favourites type=send_money)
  List<Map<String, dynamic>> _recent = [];
  // Contacts
  List<Contact> _contacts = [];
  List<Contact> _filtered = [];
  bool _loadingContacts = false;
  bool _showContacts = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _searchCtrl.addListener(_filterContacts);
  }

  Future<void> _loadRecent() async {
    try {
      final r = await http.get(
          Uri.parse('${AppConstants.apiBaseUrl}/favourites/${widget.userId}'));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') {
          setState(() {
            _recent = List<Map<String, dynamic>>.from(
                (d['data'] as List).where((f) => f['type'] == 'send_money'));
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _pickContact() async {
    setState(() => _loadingContacts = true);
    try {
      final granted = await FlutterContacts.requestPermission();
      if (!granted) {
        if (mounted) setState(() => _loadingContacts = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Contacts permission denied. Please enable it in Settings.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
      _contacts = await FlutterContacts.getContacts(withProperties: true);
      _filtered = List.from(_contacts);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _loadingContacts = false;
        _showContacts = true;
        _searchCtrl.clear();
      });
    }
  }

  void _filterContacts() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _contacts.where((c) {
        final name = c.displayName.toLowerCase();
        final phone = c.phones.map((p) => p.number).join(' ').toLowerCase();
        return name.contains(q) || phone.contains(q);
      }).toList();
    });
  }

  void _selectContact(Contact c) {
    final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
    setState(() {
      _phoneCtrl.text = phone;
      _showContacts = false;
    });
  }

  Future<void> _send() async {
    final phone = _phoneCtrl.text.trim();
    final amt = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    if (phone.isEmpty || amt <= 0) {
      _snack('Enter phone number and amount');
      return;
    }
    final normalized = widget.normalizePhone(phone);
    setState(() => _loading = true);
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/withdraw'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': int.tryParse(widget.userId) ?? widget.userId,
          'amount': amt.toInt(),
          'phone': normalized,
        }),
      ).timeout(const Duration(seconds: 20));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['status'] == 'success') {
        _saveRecent(phone, normalized);
        _showSuccess(amt, phone);
      } else {
        _snack(data['message'] ?? 'Transfer failed', error: true);
      }
    } catch (e) {
      _snack('Network error — check connection', error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveRecent(String displayPhone, String normalized) async {
    try {
      await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/favourites'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'name': displayPhone,
          'till_number': normalized,
          'account_number': '',
          'type': 'send_money',
        }),
      );
      _loadRecent();
    } catch (_) {}
  }

  void _showSuccess(double amt, String phone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
                color: AppColors.financeGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.financeGreen, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Transfer Initiated!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text('KES ${amt.toStringAsFixed(2)} → $phone',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          const Text('Check your M-Pesa for the PIN prompt.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _phoneCtrl.clear();
                _amtCtrl.clear();
                _noteCtrl.clear();
              },
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
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : AppColors.financeGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _amtCtrl.dispose();
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    // Show contacts picker overlay
    if (_showContacts) {
      return Column(children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            GestureDetector(
              onTap: () => setState(() => _showContacts = false),
              child: const Icon(Icons.close_rounded, color: Color(0xFF111827)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.financeGreen),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ]),
        ),
        Expanded(
          child: _loadingContacts
              ? const Center(child: CircularProgressIndicator(color: AppColors.financeGreen))
              : _filtered.isEmpty
                  ? const Center(child: Text('No contacts found', style: TextStyle(color: Color(0xFF9CA3AF))))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final c = _filtered[i];
                        final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.financeGreen.withValues(alpha: 0.1),
                            child: Text(
                              c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppColors.financeGreen, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(phone, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          onTap: () => _selectContact(c),
                        );
                      },
                    ),
        ),
      ]);
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, mq.padding.bottom + 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Recently sent
          if (_recent.isNotEmpty) ...[
            const Text('Recent', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 74,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recent.length,
                itemBuilder: (_, i) {
                  final f = _recent[i];
                  final num = f['name']?.toString() ?? f['till_number']?.toString() ?? '';
                  return GestureDetector(
                    onTap: () => setState(() => _phoneCtrl.text = num),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.25)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.person_rounded, color: AppColors.financeGreen, size: 18),
                        const SizedBox(height: 4),
                        Text(num.length > 10 ? num.substring(num.length - 9) : num,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          _label('Recipient Phone'),
          Row(children: [
            Expanded(
              child: _field(_phoneCtrl, 'e.g. 0712345678',
                  keyboardType: TextInputType.phone,
                  prefix: const Icon(Icons.phone_android_rounded, size: 18, color: AppColors.financeGreen)),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _loadingContacts ? null : _pickContact,
              child: Container(
                width: 48, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.financeGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.2)),
                ),
                child: _loadingContacts
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(color: AppColors.financeGreen, strokeWidth: 2),
                      )
                    : const Icon(Icons.contacts_rounded, color: AppColors.financeGreen, size: 22),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          _label('Amount (KES)'),
          _field(_amtCtrl, '0.00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefix: const Text('KES ', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
          const SizedBox(height: 14),

          _label('Note (optional)'),
          _field(_noteCtrl, 'e.g. Rent for June',
              keyboardType: TextInputType.text),
        ]),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, mq.padding.bottom + 16),
        child: _ConfirmBtn(loading: _loading, onTap: _send, label: 'Send Money'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  PROCESSING SHEET — polls transaction status
// ─────────────────────────────────────────────────────────────────

class _ProcessingSheet extends StatefulWidget {
  final String txId, userId;
  final double amount;
  final bool isBuyGoods;
  final String till, account;
  final VoidCallback onDone;
  const _ProcessingSheet({
    required this.txId,
    required this.amount,
    required this.isBuyGoods,
    required this.till,
    required this.account,
    required this.userId,
    required this.onDone,
  });

  @override
  State<_ProcessingSheet> createState() => _ProcessingSheetState();
}

class _ProcessingSheetState extends State<_ProcessingSheet> {
  bool _polling = true;
  bool _success = false;
  bool _failed = false;
  String? _error;
  int _elapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_polling || !mounted) return;
      _elapsed += 5;
      if (_elapsed >= 90) {
        setState(() { _polling = false; _failed = true; _error = 'Payment timed out. Try again.'; });
        _timer?.cancel();
        return;
      }
      try {
        final r = await http.get(
          Uri.parse('${AppConstants.apiBaseUrl}/transaction-status/${widget.txId}'),
        ).timeout(const Duration(seconds: 8));
        final d = jsonDecode(r.body);
        final status = ((d['data']?['transaction_status'] ?? d['payment_status'] ?? d['status'] ?? '')).toString().toLowerCase();
        if (status == 'completed' || status == 'success') {
          _timer?.cancel();
          if (mounted) setState(() { _polling = false; _success = true; });
          widget.onDone();
        } else if (status == 'failed' || status == 'cancelled') {
          _timer?.cancel();
          if (mounted) setState(() { _polling = false; _failed = true; _error = 'Payment failed. Try again.'; });
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, mq.padding.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 24),

        if (_success) ...[
          Container(width: 64, height: 64,
            decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.financeGreen, size: 40)),
          const SizedBox(height: 16),
          const Text('Payment Successful!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text('KES ${widget.amount.toStringAsFixed(2)} paid to ${widget.till}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 24),
          _greenBtn('Done', () { Navigator.pop(context); }),

        ] else if (_failed) ...[
          Container(width: 64, height: 64,
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.cancel_rounded, color: Colors.red, size: 40)),
          const SizedBox(height: 16),
          const Text('Payment Failed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text(_error ?? 'Something went wrong.', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _greenBtn('Try Again', () => Navigator.pop(context)),

        ] else ...[
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(color: AppColors.financeGreen, strokeWidth: 3))),
          const SizedBox(height: 16),
          const Text('Waiting for PIN', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          const Text('Enter your M-Pesa PIN to complete payment.\nChecking every 5 seconds...',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () { _polling = false; _timer?.cancel(); Navigator.pop(context); },
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ]),
    );
  }

  Widget _greenBtn(String label, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.financeGreen,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────

Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
    );

Widget _field(
  TextEditingController ctrl,
  String hint, {
  TextInputType keyboardType = TextInputType.text,
  Widget? prefix,
  Widget? suffix,
}) {
  return TextField(
    controller: ctrl,
    keyboardType: keyboardType,
    style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      prefixIcon: prefix != null
          ? Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: prefix)
          : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  final double payAmt, roundUp, total;
  const _SummaryCard({required this.payAmt, required this.roundUp, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        _row('Payment Amount', 'KES ${payAmt.toStringAsFixed(2)}', bold: false),
        const SizedBox(height: 6),
        _row('Round-up Savings', 'KES ${roundUp.toStringAsFixed(2)}', bold: false),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
        _row('Total', 'KES ${total.toStringAsFixed(2)}', bold: true),
      ]),
    );
  }

  Widget _row(String label, String value, {required bool bold}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: bold ? const Color(0xFF111827) : const Color(0xFF6B7280), fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 13, color: bold ? AppColors.financeGreen : const Color(0xFF374151), fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      );
}

class _ConfirmBtn extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  final String label;
  const _ConfirmBtn({required this.loading, required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.financeGreen,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }
}

Route _slide(Widget page) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 300),
    );
