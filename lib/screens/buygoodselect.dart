import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';
import 'dart:async';
import 'favourites.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/transaction_auth_service.dart';

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

  Map<String, dynamic>? userDetails;
  Map<String, dynamic>? roundupSettings;
  List<Map<String, dynamic>> roundupRules = [];
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
        roundupRules = List<Map<String, dynamic>>.from(d['rules'] ?? []);
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

  // Returns round-up savings amount based on active rules
  double _calcRoundUp(double amount, bool isBuyGoods) {
    if (roundupSettings == null) return 0;
    final enabled = roundupSettings!['is_enabled'] == true;
    final applies = isBuyGoods
        ? roundupSettings!['buy_goods_round_up'] == true
        : roundupSettings!['pay_bill_round_up'] == true;
    if (!enabled || !applies || amount <= 0) return 0;

    // Use rules if available
    final activeRules = roundupRules.where((r) {
      final a = r['applies_to']?.toString() ?? 'both';
      final active = r['is_active'] == true || r['active'] == true;
      return active && (a == 'both' || (isBuyGoods ? a == 'buy_goods' : a == 'pay_bill'));
    }).toList();

    if (activeRules.isNotEmpty) {
      double total = 0;
      for (final rule in activeRules) {
        final type = rule['rule_type']?.toString() ?? rule['type']?.toString() ?? 'fixed';
        final val = double.tryParse(rule['value']?.toString() ?? '0') ?? 0;
        if (val <= 0) continue;
        if (type == 'percentage') {
          total += amount * val / 100;
        } else {
          // fixed: round up to next multiple
          final rounded = amount % val == 0 ? amount + val : (amount / val).ceil() * val;
          total += rounded - amount;
        }
      }
      final maxRU = double.tryParse(roundupSettings!['max_round_up']?.toString() ?? '') ?? double.infinity;
      return total.clamp(0, maxRU);
    }

    // Legacy rounding_value fallback — only if explicitly set
    final rvRaw = roundupSettings!['rounding_value']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '';
    if (rvRaw.isEmpty) return 0;
    final rv = double.tryParse(rvRaw) ?? 0;
    if (rv <= 0) return 0;
    final maxRU = double.tryParse(roundupSettings!['max_round_up']?.toString() ?? '') ?? double.infinity;
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
                  roundupRules: roundupRules,
                ),
                _PayBillTab(
                  userId: widget.userId,
                  userPhone: _userPhone,
                  calcRoundUp: _calcRoundUp,
                  normalizePhone: _normalizePhone,
                  roundupSettings: roundupSettings,
                  roundupRules: roundupRules,
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
  final List<Map<String, dynamic>> roundupRules;
  const _BuyGoodsTab({
    required this.userId,
    required this.userPhone,
    required this.calcRoundUp,
    required this.normalizePhone,
    required this.roundupSettings,
    required this.roundupRules,
  });

  @override
  State<_BuyGoodsTab> createState() => _BuyGoodsTabState();
}

class _BuyGoodsTabState extends State<_BuyGoodsTab> {
  final _tillCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _amtFocus = FocusNode();
  bool _loading = false;
  double _roundUp = 0;
  bool _useMpesa = true;       // M-Pesa checked by default
  bool _useRoundSavings = false; // round savings opt-in

  List<Map<String, dynamic>> _favourites = [];

  @override
  void initState() {
    super.initState();
    _amtCtrl.addListener(_recalc);
    _loadFavourites();
    _useRoundSavings = widget.roundupSettings?['is_enabled'] == true &&
        widget.roundupSettings?['buy_goods_round_up'] == true;
  }

  @override
  void dispose() {
    _tillCtrl.dispose();
    _amtCtrl.dispose();
    _amtFocus.dispose();
    super.dispose();
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

  void _tapFavourite(Map<String, dynamic> f) {
    _tillCtrl.text = f['till_number']?.toString() ?? '';
    if (_amtCtrl.text.trim().isNotEmpty) {
      _confirm();
    } else {
      setState(() {});
      _amtFocus.requestFocus();
    }
  }

  void _recalc() {
    final amt = double.tryParse(_amtCtrl.text) ?? 0;
    final ru = _useRoundSavings ? widget.calcRoundUp(amt, true) : 0.0;
    setState(() => _roundUp = ru);
  }

  double get _payAmt => double.tryParse(_amtCtrl.text) ?? 0;
  double get _total => _payAmt + _roundUp;

  bool get _hasRoundupConfig =>
      widget.roundupSettings != null &&
      widget.roundupSettings!['is_enabled'] == true &&
      widget.roundupSettings!['buy_goods_round_up'] == true;

  Future<void> _confirm() async {
    final till = _tillCtrl.text.trim();
    final amt = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    if (till.isEmpty || amt <= 0) {
      _snack('Enter till number and amount');
      return;
    }
    final authed = await TransactionAuthService.authenticate(context);
    if (!authed) return;
    setState(() => _loading = true);
    try {
      if (_useMpesa) {
        // STK push flow: M-Pesa → wallet → till
        final r = await http.post(
          Uri.parse('${AppConstants.apiBaseUrl}/buy-goods-payment'),
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
          final txId = data['checkout_id']?.toString() ?? data['transactionId']?.toString() ?? '';
          if (mounted) setState(() => _loading = false);
          _showMpesaProcessing(txId: txId, amt: _total, label: 'Till $till');
          return;
        } else {
          _snack(_friendlyError(data['message']), error: true);
        }
      } else {
        // Wallet direct flow
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
          _snack(_friendlyError(data['message']), error: true);
        }
      }
    } catch (e) {
      _snack('Network error — check connection', error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  String _friendlyError(String? raw) {
    if (raw == null || raw.isEmpty) return 'Payment failed. Please try again.';
    if (raw.toLowerCase().contains('insufficient')) return raw;
    if (raw.toLowerCase().contains('balance')) return raw;
    return raw;
  }

  void _showMpesaProcessing({required String txId, required double amt, required String label}) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProcessingSheet(
        txId: txId,
        userId: widget.userId,
        amount: amt,
        isBuyGoods: true,
        till: label,
        account: '',
        onDone: () {
          _tillCtrl.clear();
          _amtCtrl.clear();
          setState(() => _roundUp = 0);
        },
      ),
    );
  }

  void _showSuccess({required double amt, required String label}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessSheet(amt: amt, label: label, fromWallet: true),
    );
  }

  Future<void> _saveFavourite() async {
    final till = _tillCtrl.text.trim();
    if (till.isEmpty) return;
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/favourites'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'name': 'Till $till',
          'till_number': till,
          'account_number': '',
          'type': 'buy_goods',
        }),
      );
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 || r.statusCode == 201) {
        _snack('Saved to favourites');
        _loadFavourites();
      } else {
        _snack(d['message'] ?? 'Failed to save', error: true);
      }
    } catch (_) {
      _snack('Network error — could not save', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : AppColors.financeGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, mq.padding.bottom + 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Saved favourites chips
          if (_favourites.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _favourites.map((f) => GestureDetector(
                  onTap: () => _tapFavourite(f),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.financeGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.2)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.store_rounded, color: AppColors.financeGreen, size: 13),
                      const SizedBox(width: 5),
                      Text(f['till_number']?.toString() ?? '',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.financeGreen)),
                    ]),
                  ),
                )).toList(),
              ),
            ),
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
              focusNode: _amtFocus,
              prefix: const Text('KES ', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
          const SizedBox(height: 20),

          // Payment source & round savings options
          _PaymentOptions(
            useMpesa: _useMpesa,
            useRoundSavings: _useRoundSavings,
            hasRoundupConfig: _hasRoundupConfig,
            onMpesaChanged: (v) => setState(() => _useMpesa = v),
            onRoundSavingsChanged: (v) {
              setState(() {
                _useRoundSavings = v;
                _recalc();
              });
            },
            roundupSettings: widget.roundupSettings,
            roundupRules: widget.roundupRules,
          ),

          const SizedBox(height: 16),
          _SummaryCard(
            payAmt: _payAmt,
            roundUp: _roundUp,
            total: _total,
            source: _useMpesa ? 'M-Pesa → Wallet → Till' : 'Wallet → Till',
          ),
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
  final List<Map<String, dynamic>> roundupRules;
  const _PayBillTab({
    required this.userId,
    required this.userPhone,
    required this.calcRoundUp,
    required this.normalizePhone,
    required this.roundupSettings,
    required this.roundupRules,
  });

  @override
  State<_PayBillTab> createState() => _PayBillTabState();
}

class _PayBillTabState extends State<_PayBillTab> {
  final _paybillCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _amtFocus = FocusNode();
  bool _loading = false;
  double _roundUp = 0;
  bool _useMpesa = true;
  bool _useRoundSavings = false;

  List<Map<String, dynamic>> _favourites = [];

  @override
  void initState() {
    super.initState();
    _amtCtrl.addListener(_recalc);
    _loadFavourites();
    _useRoundSavings = widget.roundupSettings?['is_enabled'] == true &&
        widget.roundupSettings?['pay_bill_round_up'] == true;
  }

  @override
  void dispose() {
    _paybillCtrl.dispose();
    _accountCtrl.dispose();
    _amtCtrl.dispose();
    _amtFocus.dispose();
    super.dispose();
  }

  void _tapFavourite(Map<String, dynamic> f) {
    _paybillCtrl.text = f['till_number']?.toString() ?? '';
    _accountCtrl.text = f['account_number']?.toString() ?? '';
    if (_amtCtrl.text.trim().isNotEmpty) {
      _confirm();
    } else {
      setState(() {});
      _amtFocus.requestFocus();
    }
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
    final ru = _useRoundSavings ? widget.calcRoundUp(amt, false) : 0.0;
    setState(() => _roundUp = ru);
  }

  double get _payAmt => double.tryParse(_amtCtrl.text) ?? 0;
  double get _total => _payAmt + _roundUp;

  bool get _hasRoundupConfig =>
      widget.roundupSettings != null &&
      widget.roundupSettings!['is_enabled'] == true &&
      widget.roundupSettings!['pay_bill_round_up'] == true;

  Future<void> _confirm() async {
    final paybill = _paybillCtrl.text.trim();
    final account = _accountCtrl.text.trim();
    final amt = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    if (paybill.isEmpty || amt <= 0) {
      _snack('Enter paybill number and amount');
      return;
    }
    final authed = await TransactionAuthService.authenticate(context);
    if (!authed) return;
    setState(() => _loading = true);
    try {
      if (_useMpesa) {
        // STK push: M-Pesa deposits to wallet, then wallet pays paybill
        // We use deposit endpoint then paybill — or a combined endpoint.
        // For now: STK push total (merchant + savings), then on callback it'll pay paybill.
        // Use buy-goods-payment pattern adapted for paybill:
        // Actually, call deposit STK for total, then on callback paybill is paid from wallet.
        // Simpler: just deposit total via STK, show processing, user re-confirms after.
        // Best UX: STK push amount, then once confirmed show "M-Pesa received, paying bill..."
        // We call /deposit for the total (amt + roundup), then after success call /process-paybill-payment.
        final totalToDeposit = _total;
        final depositR = await http.post(
          Uri.parse('${AppConstants.apiBaseUrl}/deposit'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': int.tryParse(widget.userId) ?? widget.userId,
            'amount': totalToDeposit,
          }),
        ).timeout(const Duration(seconds: 20));
        final depositData = jsonDecode(depositR.body);
        if (depositR.statusCode == 200 && depositData['status'] == 'success') {
          final txId = depositData['checkout_id']?.toString() ?? depositData['deposit_id']?.toString() ?? '';
          if (mounted) setState(() => _loading = false);
          _showMpesaProcessingPaybill(
            txId: txId,
            paybill: paybill,
            account: account,
            amt: amt,
            roundUp: _roundUp,
          );
          return;
        } else {
          _snack(_friendlyError(depositData['message']), error: true);
        }
      } else {
        // Wallet direct
        final r = await http.post(
          Uri.parse('${AppConstants.apiBaseUrl}/process-paybill-payment'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': int.tryParse(widget.userId) ?? widget.userId,
            'amount': amt,
            'merchant_paybill': paybill,
            'merchant_account': account,
            'round_up_savings': _roundUp,
          }),
        ).timeout(const Duration(seconds: 20));
        final data = jsonDecode(r.body);
        if (r.statusCode == 200 && data['status'] == 'success') {
          _showSuccess(amt: amt, roundUp: _roundUp, label: 'PayBill $paybill');
          _paybillCtrl.clear();
          _accountCtrl.clear();
          _amtCtrl.clear();
          setState(() => _roundUp = 0);
        } else {
          _snack(_friendlyError(data['message']), error: true);
        }
      }
    } catch (e) {
      _snack('Network error — check connection', error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  String _friendlyError(String? raw) {
    if (raw == null || raw.isEmpty) return 'Payment failed. Please try again.';
    return raw;
  }

  void _showMpesaProcessingPaybill({
    required String txId,
    required String paybill,
    required String account,
    required double amt,
    required double roundUp,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaybillMpesaSheet(
        txId: txId,
        userId: widget.userId,
        paybill: paybill,
        account: account,
        amt: amt,
        roundUp: roundUp,
        onDone: () {
          _paybillCtrl.clear();
          _accountCtrl.clear();
          _amtCtrl.clear();
          setState(() => _roundUp = 0);
        },
      ),
    );
  }

  void _showSuccess({required double amt, required double roundUp, required String label}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessSheet(amt: amt + roundUp, label: label, fromWallet: true),
    );
  }

  Future<void> _saveFavourite() async {
    final paybill = _paybillCtrl.text.trim();
    if (paybill.isEmpty) return;
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/favourites'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'name': 'Paybill $paybill',
          'till_number': paybill,
          'account_number': _accountCtrl.text.trim(),
          'type': 'pay_bill',
        }),
      );
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 || r.statusCode == 201) {
        _snack('Saved to favourites');
        _loadFavourites();
      } else {
        _snack(d['message'] ?? 'Failed to save', error: true);
      }
    } catch (_) {
      _snack('Network error — could not save', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : AppColors.financeGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _favourites.map((f) => GestureDetector(
                  onTap: () => _tapFavourite(f),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.financeGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.2)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.receipt_long_rounded, color: AppColors.financeGreen, size: 13),
                      const SizedBox(width: 5),
                      Text(f['till_number']?.toString() ?? '',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.financeGreen)),
                    ]),
                  ),
                )).toList(),
              ),
            ),
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
              focusNode: _amtFocus,
              prefix: const Text('KES ', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
          const SizedBox(height: 20),

          _PaymentOptions(
            useMpesa: _useMpesa,
            useRoundSavings: _useRoundSavings,
            hasRoundupConfig: _hasRoundupConfig,
            onMpesaChanged: (v) => setState(() => _useMpesa = v),
            onRoundSavingsChanged: (v) {
              setState(() {
                _useRoundSavings = v;
                _recalc();
              });
            },
            roundupSettings: widget.roundupSettings,
            roundupRules: widget.roundupRules,
          ),

          const SizedBox(height: 16),
          _SummaryCard(
            payAmt: _payAmt,
            roundUp: _roundUp,
            total: _total,
            source: _useMpesa ? 'M-Pesa → Wallet → PayBill' : 'Wallet → PayBill',
          ),
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

  List<Map<String, dynamic>> _recent = [];
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
    final authed = await TransactionAuthService.authenticate(context);
    if (!authed) return;
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
        _snack(data['message'] ?? 'Transfer failed. Please try again.', error: true);
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
          const Text('The recipient will receive an M-Pesa deposit shortly.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)), textAlign: TextAlign.center),
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
      backgroundColor: error ? Colors.red.shade700 : AppColors.financeGreen,
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

    if (_showContacts) {
      return Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
//  PAYMENT OPTIONS WIDGET (M-Pesa checkbox + Round Savings checkbox)
// ─────────────────────────────────────────────────────────────────

class _PaymentOptions extends StatelessWidget {
  final bool useMpesa;
  final bool useRoundSavings;
  final bool hasRoundupConfig;
  final ValueChanged<bool> onMpesaChanged;
  final ValueChanged<bool> onRoundSavingsChanged;
  final Map<String, dynamic>? roundupSettings;
  final List<Map<String, dynamic>> roundupRules;

  const _PaymentOptions({
    required this.useMpesa,
    required this.useRoundSavings,
    required this.hasRoundupConfig,
    required this.onMpesaChanged,
    required this.onRoundSavingsChanged,
    required this.roundupSettings,
    required this.roundupRules,
  });

  String get _roundupLabel {
    // Use rule description if available
    final activeRules = roundupRules.where((r) => r['is_active'] == true || r['active'] == true).toList();
    if (activeRules.isNotEmpty) {
      final r = activeRules.first;
      final type = r['rule_type']?.toString() ?? r['type']?.toString() ?? 'fixed';
      final val = r['value']?.toString() ?? '0';
      if (type == 'percentage') return 'Round Savings ($val% of amount)';
      return 'Round Savings (+ KES $val per transaction)';
    }
    if (roundupSettings == null) return 'Round Savings';
    final rv = roundupSettings!['rounding_value']?.toString() ?? '';
    final maxRu = roundupSettings!['max_round_up']?.toString() ?? '';
    if (rv.isNotEmpty && rv != 'null' && rv != '0') return 'Round Savings (round up to KES $rv)';
    if (maxRu.isNotEmpty && maxRu != 'null') return 'Round Savings (max KES $maxRu/txn)';
    return 'Round Savings';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Payment Options',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
        const SizedBox(height: 8),

        // M-Pesa checkbox
        InkWell(
          onTap: () => onMpesaChanged(!useMpesa),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              _checkbox(useMpesa),
              const SizedBox(width: 10),
              const Icon(Icons.phone_android_rounded, size: 16, color: Color(0xFF374151)),
              const SizedBox(width: 6),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pay via M-Pesa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                  Text('STK push to your phone — M-Pesa deposits to wallet first',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ]),
              ),
            ]),
          ),
        ),

        if (!useMpesa) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet_rounded, size: 14, color: AppColors.financeGreen),
              const SizedBox(width: 4),
              Text('Paying from wallet balance',
                  style: TextStyle(fontSize: 11, color: AppColors.financeGreen.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
            ]),
          ),
        ],

        // Round savings — only show if user has it configured
        if (hasRoundupConfig) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFF3F4F6)),
          ),
          InkWell(
            onTap: () => onRoundSavingsChanged(!useRoundSavings),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                _checkbox(useRoundSavings),
                const SizedBox(width: 10),
                const Icon(Icons.savings_rounded, size: 16, color: AppColors.financeGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_roundupLabel,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                    const Text('Extra amount added on top and saved to your goal',
                        style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _checkbox(bool checked) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: checked ? AppColors.financeGreen : Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: checked ? AppColors.financeGreen : const Color(0xFFD1D5DB),
            width: 1.5,
          ),
        ),
        child: checked
            ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
            : null,
      );
}

// ─────────────────────────────────────────────────────────────────
//  PROCESSING DIALOG — wallet-style centered card (Buy Goods STK)
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
      if (_elapsed >= 60) {
        setState(() { _polling = false; _failed = true; _error = 'Payment timed out. Please try again.'; });
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
          final errMsg = d['data']?['error_message'] ?? d['message'] ?? 'Payment failed. Please try again.';
          if (mounted) setState(() { _polling = false; _failed = true; _error = errMsg.toString(); });
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
      padding: EdgeInsets.fromLTRB(24, 20, 24, mq.viewInsets.bottom + mq.padding.bottom + 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 28),
        if (_success) ...[
          Container(width: 64, height: 64,
            decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.financeGreen, size: 40)),
          const SizedBox(height: 16),
          const Text('Payment Successful!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text('KES ${widget.amount.toStringAsFixed(2)} paid to ${widget.till}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _greenBtn('Done', () => Navigator.pop(context)),
        ] else if (_failed) ...[
          Container(width: 64, height: 64,
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.cancel_rounded, color: Colors.red, size: 40)),
          const SizedBox(height: 16),
          const Text('Payment Failed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text(_error ?? 'Something went wrong.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _greenBtn('Close', () => Navigator.pop(context)),
        ] else ...[
          SpinKitFadingCircle(color: AppColors.financeGreenV3, size: 56),
          const SizedBox(height: 24),
          const Text('Check your phone',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 8),
          const Text('Enter your SasaPay PIN to complete the payment',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          _StkCountdown(seconds: 60),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () { _polling = false; _timer?.cancel(); Navigator.pop(context); },
            child: const Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 14)),
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
//  PAYBILL PROCESSING SHEET
// ─────────────────────────────────────────────────────────────────

class _PaybillMpesaSheet extends StatefulWidget {
  final String txId, userId, paybill, account;
  final double amt, roundUp;
  final VoidCallback onDone;

  const _PaybillMpesaSheet({
    required this.txId,
    required this.userId,
    required this.paybill,
    required this.account,
    required this.amt,
    required this.roundUp,
    required this.onDone,
  });

  @override
  State<_PaybillMpesaSheet> createState() => _PaybillMpesaSheetState();
}

class _PaybillMpesaSheetState extends State<_PaybillMpesaSheet> {
  String _stage = 'waiting_pin';
  String? _error;
  int _elapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pollDeposit();
  }

  void _pollDeposit() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      _elapsed += 5;
      if (_elapsed >= 60) {
        _timer?.cancel();
        if (mounted) setState(() { _stage = 'failed'; _error = 'Payment timed out. Please try again.'; });
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
          if (mounted) setState(() => _stage = 'paying_paybill');
          await _payPaybill();
        } else if (status == 'failed' || status == 'cancelled') {
          _timer?.cancel();
          final errMsg = d['data']?['error_message'] ?? d['message'] ?? 'M-Pesa payment failed.';
          if (mounted) setState(() { _stage = 'failed'; _error = errMsg.toString(); });
        }
      } catch (_) {}
    });
  }

  Future<void> _payPaybill() async {
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/process-paybill-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': int.tryParse(widget.userId) ?? widget.userId,
          'amount': widget.amt,
          'merchant_paybill': widget.paybill,
          'merchant_account': widget.account,
          'round_up_savings': widget.roundUp,
        }),
      ).timeout(const Duration(seconds: 20));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['status'] == 'success') {
        if (mounted) setState(() => _stage = 'success');
        widget.onDone();
      } else {
        if (mounted) setState(() { _stage = 'failed'; _error = data['message'] ?? 'Failed to pay PayBill. Please try again.'; });
      }
    } catch (e) {
      if (mounted) setState(() { _stage = 'failed'; _error = 'Network error. Please try again.'; });
    }
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
      padding: EdgeInsets.fromLTRB(24, 20, 24, mq.viewInsets.bottom + mq.padding.bottom + 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 28),
        if (_stage == 'success') ...[
          Container(width: 64, height: 64,
            decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.financeGreen, size: 40)),
          const SizedBox(height: 16),
          const Text('Payment Successful!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text('KES ${widget.amt.toStringAsFixed(2)} paid to PayBill ${widget.paybill}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
          if (widget.roundUp > 0) ...[
            const SizedBox(height: 4),
            Text('+ KES ${widget.roundUp.toStringAsFixed(2)} saved',
                style: TextStyle(fontSize: 12, color: AppColors.financeGreen.withValues(alpha: 0.85))),
          ],
          const SizedBox(height: 24),
          _greenBtn('Done', () => Navigator.pop(context)),
        ] else if (_stage == 'failed') ...[
          Container(width: 64, height: 64,
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.cancel_rounded, color: Colors.red, size: 40)),
          const SizedBox(height: 16),
          const Text('Payment Failed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text(_error ?? 'Something went wrong.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _greenBtn('Close', () => Navigator.pop(context)),
        ] else ...[
          SpinKitFadingCircle(color: AppColors.financeGreenV3, size: 56),
          const SizedBox(height: 24),
          Text(
            _stage == 'paying_paybill' ? 'Paying PayBill...' : 'Check your phone',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          Text(
            _stage == 'paying_paybill'
                ? 'M-Pesa confirmed — paying PayBill ${widget.paybill} now'
                : 'Enter your SasaPay PIN to complete the payment',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
          if (_stage == 'waiting_pin') ...[
            const SizedBox(height: 20),
            _StkCountdown(seconds: 60),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () { _timer?.cancel(); Navigator.pop(context); },
              child: const Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 14)),
            ),
          ] else
            const SizedBox(height: 16),
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
//  SUCCESS SHEET (wallet-direct payments)
// ─────────────────────────────────────────────────────────────────

class _SuccessSheet extends StatelessWidget {
  final double amt;
  final String label;
  final bool fromWallet;

  const _SuccessSheet({required this.amt, required this.label, required this.fromWallet});

  @override
  Widget build(BuildContext context) {
    return Container(
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
        const Text('Payment Successful!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        const SizedBox(height: 6),
        Text('KES ${amt.toStringAsFixed(2)} paid to $label',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        const SizedBox(height: 8),
        Text(
          fromWallet ? 'Funds deducted from your Nebo wallet.' : 'Payment processed.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
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
    );
  }
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
  FocusNode? focusNode,
}) {
  return TextField(
    controller: ctrl,
    focusNode: focusNode,
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
  final String source;
  const _SummaryCard({required this.payAmt, required this.roundUp, required this.total, required this.source});

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
        if (roundUp > 0) ...[
          const SizedBox(height: 6),
          _row('Round Savings', '+ KES ${roundUp.toStringAsFixed(2)}', bold: false, accent: true),
        ],
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
        _row('Total', 'KES ${total.toStringAsFixed(2)}', bold: true),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.info_outline_rounded, size: 12, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 4),
          Expanded(child: Text(source, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))),
        ]),
      ]),
    );
  }

  Widget _row(String label, String value, {required bool bold, bool accent = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: 13,
            color: bold ? const Color(0xFF111827) : const Color(0xFF6B7280),
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(
            fontSize: 13,
            color: bold ? AppColors.financeGreen : (accent ? AppColors.financeGreen : const Color(0xFF374151)),
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
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

// ─────────────────────────────────────────────────────────────────
//  STK COUNTDOWN — circular progress + countdown number
// ─────────────────────────────────────────────────────────────────

class _StkCountdown extends StatefulWidget {
  final int seconds;
  const _StkCountdown({required this.seconds});

  @override
  State<_StkCountdown> createState() => _StkCountdownState();
}

class _StkCountdownState extends State<_StkCountdown> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = (_remaining - 1).clamp(0, widget.seconds));
      if (_remaining == 0) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remaining / widget.seconds;
    return SizedBox(
      width: 56, height: 56,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(
          value: progress,
          backgroundColor: const Color(0xFFE5E7EB),
          color: AppColors.financeGreenV3,
          strokeWidth: 3,
        ),
        Text(
          '$_remaining',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
        ),
      ]),
    );
  }
}
