import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants/app_theme.dart';
import '../config/api_config.dart';

const int _totalSteps = 12;

const List<String> _niaFocusOptions = [
  'Budgeting', 'Debt Repayment', 'Saving', 'Investing', 'Spending Insights', 'Financial Education', 'Reminders'
];

class OnboardingFlow extends StatefulWidget {
  final String userId;
  const OnboardingFlow({super.key, required this.userId});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final PageController _pageController;
  int _currentStep = 0;
  bool _loading = true;
  bool _saving = false;

  // Step 1
  String _incomeSource = '';
  String _incomeFrequency = 'monthly';
  final _incomeCtrl = TextEditingController();

  // Step 2 — living expenses (category -> amount)
  final Map<String, TextEditingController> _expenseCtrls = {
    for (final c in ['Rent', 'Food', 'Transport', 'Utilities', 'Airtime & Internet', 'School Fees', 'Healthcare', 'Entertainment', 'Shopping', 'Other'])
      c: TextEditingController(),
  };

  // Step 3 — debts
  List<Map<String, dynamic>> _debts = [];

  // Step 4 — money owed to user
  List<Map<String, dynamic>> _moneyOwed = [];

  // Step 5
  final _savingsAmtCtrl = TextEditingController();
  String _savingsFrequency = 'monthly';

  // Step 6 — goals (created directly, list just for display this session)
  List<Map<String, dynamic>> _goalsCreated = [];

  // Step 7 — bills
  final Map<String, TextEditingController> _billCtrls = {
    for (final c in ['Rent', 'Electricity', 'Water', 'Internet', 'Insurance', 'School Fees', 'Netflix', 'Spotify', 'DSTV'])
      c: TextEditingController(),
  };

  // Step 8
  String _emergencyFundMonths = '';

  // Step 9
  String _spendingStyle = '';
  String _biggestChallenge = '';

  // Step 10 — round ups
  bool _roundupEnabled = false;
  double _roundupAmount = 10;

  // Step 11
  bool? _wantsCreditReport;

  // Step 12
  final Set<String> _niaFocus = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _hydrate();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _incomeCtrl.dispose();
    _savingsAmtCtrl.dispose();
    for (final c in _expenseCtrls.values) c.dispose();
    for (final c in _billCtrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.getUrl('onboarding/${widget.userId}')));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body)['data'];
        final profile = d['profile'] ?? {};
        _incomeCtrl.text = profile['monthly_income'] != null ? '${double.tryParse(profile['monthly_income'].toString())?.round()}' : '';
        _incomeFrequency = profile['income_frequency']?.toString() ?? 'monthly';
        _incomeSource = profile['income_source']?.toString() ?? '';
        _savingsFrequency = profile['savings_frequency']?.toString() ?? 'monthly';
        _emergencyFundMonths = profile['emergency_fund_months']?.toString() ?? '';
        _spendingStyle = profile['spending_style']?.toString() ?? '';
        _biggestChallenge = profile['biggest_expense_category']?.toString() ?? '';
        _wantsCreditReport = profile['wants_credit_report'] as bool?;
        _debts = List<Map<String, dynamic>>.from(d['debts'] ?? []);
        _moneyOwed = List<Map<String, dynamic>>.from(d['money_owed_to_user'] ?? []);
        final living = List<Map<String, dynamic>>.from(d['expenses']?['living'] ?? []);
        for (final e in living) {
          final cat = e['category']?.toString();
          if (cat != null && _expenseCtrls.containsKey(cat)) {
            _expenseCtrls[cat]!.text = '${double.tryParse(e['amount'].toString())?.round()}';
          }
        }
        final bills = List<Map<String, dynamic>>.from(d['expenses']?['bills'] ?? []);
        for (final e in bills) {
          final cat = e['category']?.toString();
          if (cat != null && _billCtrls.containsKey(cat)) {
            _billCtrls[cat]!.text = '${double.tryParse(e['amount'].toString())?.round()}';
          }
        }
        final prefs = List<String>.from(d['preferences']?['nia_focus_areas'] ?? []);
        _niaFocus.addAll(prefs);

        // Live account state — always reflect what's actually true right now,
        // not a stale answer from an earlier onboarding pass.
        _goalsCreated = List<Map<String, dynamic>>.from(d['goals'] ?? []);

        // Current savings: derive from real goal balances (source of truth)
        // rather than a self-reported figure — the user shouldn't have to
        // re-type what Nebo already knows.
        final realSavings = _goalsCreated.fold<double>(
          0, (sum, g) => sum + (double.tryParse(g['current_amount']?.toString() ?? '0') ?? 0),
        );
        _savingsAmtCtrl.text = realSavings > 0
            ? realSavings.round().toString()
            : (profile['current_savings_amount'] != null ? '${double.tryParse(profile['current_savings_amount'].toString())?.round()}' : '');
        final roundupSettings = d['roundup']?['settings'];
        final roundupRules = List<Map<String, dynamic>>.from(d['roundup']?['rules'] ?? []);
        if (roundupSettings != null && roundupSettings['is_enabled'] == true) {
          _roundupEnabled = true;
          final activeFixed = roundupRules.firstWhere(
            (r) => r['is_active'] == true && r['rule_type'] == 'fixed',
            orElse: () => {},
          );
          if (activeFixed.isNotEmpty) {
            _roundupAmount = double.tryParse(activeFixed['value'].toString()) ?? 10;
          }
        }

        final resumeStep = (d['current_step'] as int? ?? 1).clamp(1, _totalSteps);
        _currentStep = resumeStep - 1;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
      if (_currentStep > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pageController.jumpToPage(_currentStep);
        });
      }
    }
    await http.post(Uri.parse(ApiConfig.getUrl('onboarding/${widget.userId}/start'))).catchError((_) => http.Response('', 500));
  }

  Future<void> _saveStep(int step, Map<String, dynamic> fields) async {
    try {
      await http.patch(
        Uri.parse(ApiConfig.getUrl('onboarding/${widget.userId}/step')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'step': step, 'fields': fields}),
      );
    } catch (_) {}
  }

  void _next() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
    }
  }

  void _prev() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
    }
  }

  Future<void> _handleContinue() async {
    setState(() => _saving = true);
    switch (_currentStep + 1) {
      case 1:
        await _saveStep(1, {
          'monthly_income': double.tryParse(_incomeCtrl.text.trim()),
          'income_frequency': _incomeFrequency,
          'income_source': _incomeSource,
        });
        break;
      case 2:
        double total = 0;
        for (final e in _expenseCtrls.entries) {
          final val = double.tryParse(e.value.text.trim());
          if (val != null && val > 0) {
            total += val;
            await http.post(
              Uri.parse(ApiConfig.getUrl('onboarding/${widget.userId}/expenses')),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'expense_kind': 'living', 'category': e.key, 'amount': val}),
            ).catchError((_) => http.Response('', 500));
          }
        }
        await _saveStep(2, {'total_monthly_expenses': total});
        break;
      case 5:
        await _saveStep(5, {
          'current_savings_amount': double.tryParse(_savingsAmtCtrl.text.trim()),
          'savings_frequency': _savingsFrequency,
        });
        break;
      case 6:
        await _saveStep(6, {});
        break;
      case 7:
        for (final e in _billCtrls.entries) {
          final val = double.tryParse(e.value.text.trim());
          if (val != null && val > 0) {
            await http.post(
              Uri.parse(ApiConfig.getUrl('onboarding/${widget.userId}/expenses')),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'expense_kind': 'bill', 'category': e.key, 'amount': val}),
            ).catchError((_) => http.Response('', 500));
          }
        }
        break;
      case 8:
        await _saveStep(8, {'emergency_fund_months': _emergencyFundMonths});
        break;
      case 9:
        await _saveStep(9, {'spending_style': _spendingStyle, 'biggest_expense_category': _biggestChallenge});
        break;
      case 10:
        if (_roundupEnabled) {
          await http.post(
            Uri.parse(ApiConfig.getUrl('roundup-settings')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': widget.userId,
              'is_enabled': true,
              'buy_goods_round_up': true,
              'pay_bill_round_up': true,
              'rules': [
                {'type': 'fixed', 'value': _roundupAmount, 'applies_to': 'all', 'active': true},
              ],
            }),
          ).catchError((_) => http.Response('', 500));
        }
        await _saveStep(10, {});
        break;
      case 11:
        await _saveStep(11, {'wants_credit_report': _wantsCreditReport ?? false});
        break;
      case 12:
        await http.post(
          Uri.parse(ApiConfig.getUrl('onboarding/${widget.userId}/preferences')),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'nia_focus_areas': _niaFocus.toList()}),
        ).catchError((_) => http.Response('', 500));
        break;
    }
    if (mounted) setState(() => _saving = false);

    if (_currentStep == _totalSteps - 1) {
      await _finish();
    } else {
      _next();
    }
  }

  Future<void> _finish() async {
    try {
      await http.post(Uri.parse(ApiConfig.getUrl('onboarding/${widget.userId}/complete')));
    } catch (_) {}
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _skip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Skip for now?'),
        content: const Text('You can finish this later from your Profile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep going')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Skip')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await http.post(Uri.parse(ApiConfig.getUrl('onboarding/${widget.userId}/skip')));
    } catch (_) {}
    if (mounted) Navigator.pop(context, true);
  }

  bool get _canProceed {
    if (_currentStep == 0) return double.tryParse(_incomeCtrl.text.trim()) != null && double.tryParse(_incomeCtrl.text.trim())! > 0;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.financeGreen)));
    }
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Step ${_currentStep + 1} of $_totalSteps',
            style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700, fontSize: 15)),
        centerTitle: true,
        actions: [
          TextButton(onPressed: _skip, child: const Text('Skip for now', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600))),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation(AppColors.financeGreen),
            minHeight: 4,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentStep = i),
        children: [
          _stepScaffold(_incomeStep()),
          _stepScaffold(_expensesStep()),
          _stepScaffold(_debtsStep()),
          _stepScaffold(_moneyOwedStep()),
          _stepScaffold(_savingsStep()),
          _stepScaffold(_goalsStep()),
          _stepScaffold(_billsStep()),
          _stepScaffold(_emergencyFundStep()),
          _stepScaffold(_spendingBehaviourStep()),
          _stepScaffold(_roundUpsStep()),
          _stepScaffold(_creditProfileStep()),
          _stepScaffold(_niaStep()),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 16),
        child: Row(children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _prev,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: (_saving || !_canProceed) ? null : _handleContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.financeGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_currentStep == _totalSteps - 1 ? 'Finish' : 'Continue',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _stepScaffold(Widget child) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: child,
      );

  Widget _title(String t, [String? sub]) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(sub, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ],
        ]),
      );

  InputDecoration _dec(String hint, {String? prefix}) => InputDecoration(
        hintText: hint,
        prefixText: prefix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap, {IconData? icon}) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.financeGreen.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.financeGreen : const Color(0xFFE5E7EB)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 16, color: selected ? AppColors.financeGreen : const Color(0xFF9CA3AF)), const SizedBox(width: 6)],
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? AppColors.financeGreen : const Color(0xFF374151))),
          ]),
        ),
      );

  // ── Step 1: Income ──────────────────────────────────────────
  Widget _incomeStep() {
    const sources = [
      ['Salary', Icons.work_rounded], ['Business', Icons.storefront_rounded], ['Casual / Freelance', Icons.handyman_rounded],
      ['Farming', Icons.agriculture_rounded], ['Pension', Icons.elderly_rounded], ['Student', Icons.school_rounded], ['Other', Icons.more_horiz_rounded],
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Tell us about your income', 'This helps us build a budget that works for you.'),
      const Text('What is your main source of income?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: sources.map((s) => _chip(s[0] as String, _incomeSource == s[0], () => setState(() => _incomeSource = s[0] as String), icon: s[1] as IconData)).toList()),
      const SizedBox(height: 20),
      const Text('How often do you get paid?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ['Weekly', 'weekly'], ['Every 2 weeks', 'fortnightly'], ['Monthly', 'monthly'], ['Irregular', 'irregular'],
      ].map((f) => _chip(f[0], _incomeFrequency == f[1], () => setState(() => _incomeFrequency = f[1]))).toList()),
      const SizedBox(height: 20),
      const Text('How much do you usually receive?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
      const SizedBox(height: 10),
      TextField(controller: _incomeCtrl, keyboardType: TextInputType.number, decoration: _dec('0', prefix: 'KES ')),
    ]);
  }

  // ── Step 2: Living Expenses ──────────────────────────────────
  Widget _expensesStep() {
    final total = _expenseCtrls.values.fold(0.0, (s, c) => s + (double.tryParse(c.text.trim()) ?? 0));
    return StatefulBuilder(builder: (context, setLocal) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('Your monthly living expenses', 'Enter your average monthly spending.'),
        ..._expenseCtrls.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Expanded(flex: 3, child: Text(e.key, style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: e.value,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    onChanged: (_) => setLocal(() {}),
                    decoration: _dec('0', prefix: 'KES '),
                  ),
                ),
              ]),
            )),
        const Divider(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total Expenses', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827))),
          Text('KES ${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.financeGreen)),
        ]),
      ]);
    });
  }

  // ── Step 3: Debts ────────────────────────────────────────────
  Widget _debtsStep() {
    return StatefulBuilder(builder: (context, setLocal) {
      Future<void> addDebt() async {
        final result = await showModalBottomSheet<Map<String, dynamic>>(
          context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => const _QuickDebtSheet(),
        );
        if (result != null) {
          final r = await http.post(
            Uri.parse(ApiConfig.getUrl('onboarding/${widget.userId}/debts')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({...result, 'user_id': widget.userId}),
          );
          if (r.statusCode == 200) {
            final d = jsonDecode(r.body)['data'];
            setLocal(() => _debts = [..._debts, d]);
          }
        }
      }

      Future<void> removeDebt(Map<String, dynamic> debt) async {
        await http.delete(
          Uri.parse(ApiConfig.getUrl('onboarding/debts/${debt['id']}')),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': widget.userId}),
        );
        setLocal(() => _debts.removeWhere((d) => d['id'] == debt['id']));
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('Tell us about your debts', 'Do you currently owe anyone money?'),
        ..._debts.map((d) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['creditor_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('KES ${double.tryParse(d['amount_owed'].toString())?.round()}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ])),
                IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20), onPressed: () => removeDebt(d)),
              ]),
            )),
        OutlinedButton.icon(
          onPressed: addDebt,
          icon: const Icon(Icons.add_rounded, color: AppColors.financeGreen),
          label: const Text('Add another debt', style: TextStyle(color: AppColors.financeGreen, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.financeGreen),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]);
    });
  }

  // ── Step 4: Money Owed To You ────────────────────────────────
  Widget _moneyOwedStep() {
    return StatefulBuilder(builder: (context, setLocal) {
      Future<void> addEntry() async {
        final result = await showModalBottomSheet<Map<String, dynamic>>(
          context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => const _QuickMoneyOwedSheet(),
        );
        if (result != null) {
          final r = await http.post(
            Uri.parse(ApiConfig.getUrl('onboarding/${widget.userId}/money-owed')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({...result, 'user_id': widget.userId}),
          );
          if (r.statusCode == 200) {
            final d = jsonDecode(r.body)['data'];
            setLocal(() => _moneyOwed = [..._moneyOwed, d]);
          }
        }
      }

      Future<void> removeEntry(Map<String, dynamic> entry) async {
        await http.delete(
          Uri.parse(ApiConfig.getUrl('onboarding/money-owed/${entry['id']}')),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': widget.userId}),
        );
        setLocal(() => _moneyOwed.removeWhere((d) => d['id'] == entry['id']));
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('People who owe you money', 'Does anyone owe you money?'),
        ..._moneyOwed.map((d) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['person_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('KES ${double.tryParse(d['amount'].toString())?.round()}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ])),
                IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20), onPressed: () => removeEntry(d)),
              ]),
            )),
        OutlinedButton.icon(
          onPressed: addEntry,
          icon: const Icon(Icons.add_rounded, color: AppColors.financeGreen),
          label: const Text('Add another person', style: TextStyle(color: AppColors.financeGreen, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.financeGreen),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: AppColors.financeGreen),
            SizedBox(width: 8),
            Expanded(child: Text("We'll help you track and get reminders without awkward conversations.", style: TextStyle(fontSize: 12, color: AppColors.financeGreen))),
          ]),
        ),
      ]);
    });
  }

  // ── Step 5: Savings ──────────────────────────────────────────
  Widget _savingsStep() {
    final hasRealSavings = _goalsCreated.fold<double>(
          0, (sum, g) => sum + (double.tryParse(g['current_amount']?.toString() ?? '0') ?? 0),
        ) >
        0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Savings', 'Do you currently have savings?'),
      const Text('Current Balance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
      const SizedBox(height: 10),
      TextField(controller: _savingsAmtCtrl, keyboardType: TextInputType.number, decoration: _dec('0', prefix: 'KES ')),
      if (hasRealSavings) ...[
        const SizedBox(height: 6),
        const Row(children: [
          Icon(Icons.verified_rounded, size: 14, color: AppColors.financeGreen),
          SizedBox(width: 4),
          Text('Detected from your Nebo goals', style: TextStyle(fontSize: 11, color: AppColors.financeGreen)),
        ]),
      ],
      const SizedBox(height: 20),
      const Text('How often do you save?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ['Weekly', 'weekly'], ['Monthly', 'monthly'], ['Irregular', 'irregular'], ['Never', 'never'],
      ].map((f) => _chip(f[0], _savingsFrequency == f[1], () => setState(() => _savingsFrequency = f[1]))).toList()),
    ]);
  }

  // ── Step 6: Financial Goals ──────────────────────────────────
  Widget _goalsStep() {
    return StatefulBuilder(builder: (context, setLocal) {
      Future<void> addGoal() async {
        final result = await showModalBottomSheet<Map<String, dynamic>>(
          context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => const _QuickGoalSheet(),
        );
        if (result != null) {
          final r = await http.post(
            Uri.parse(ApiConfig.getUrl('goalscreate')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': widget.userId,
              'title': result['title'],
              'target_amount': result['target_amount'],
              'duration_days': 90,
              'goal_type': result['goal_type'] ?? '',
            }),
          );
          if (r.statusCode == 200 || r.statusCode == 201) {
            final d = jsonDecode(r.body)['goal'];
            setLocal(() => _goalsCreated = [..._goalsCreated, d]);
          } else {
            final err = jsonDecode(r.body);
            if (!mounted) return;
            ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(err['message'] ?? 'Failed to create goal')));
          }
        }
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('Financial goals', 'What are you saving for?'),
        ..._goalsCreated.map((g) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Row(children: [
                const Icon(Icons.flag_rounded, color: AppColors.financeGreen, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(g['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                Text('KES ${double.tryParse(g['target_amount'].toString())?.round()}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ]),
            )),
        OutlinedButton.icon(
          onPressed: addGoal,
          icon: const Icon(Icons.add_rounded, color: AppColors.financeGreen),
          label: const Text('Add another goal', style: TextStyle(color: AppColors.financeGreen, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.financeGreen),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]);
    });
  }

  // ── Step 7: Bills & Subscriptions ────────────────────────────
  Widget _billsStep() {
    return StatefulBuilder(builder: (context, setLocal) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('Bills & subscriptions', 'Which bills do you pay regularly?'),
        ..._billCtrls.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Expanded(flex: 3, child: Text(e.key, style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: e.value,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    onChanged: (_) => setLocal(() {}),
                    decoration: _dec('0', prefix: 'KES '),
                  ),
                ),
              ]),
            )),
      ]);
    });
  }

  // ── Step 8: Emergency Fund ───────────────────────────────────
  Widget _emergencyFundStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Emergency fund', 'If you lost your income today, how long could you survive?'),
      ...['Less than 1 month', '1–3 months', '3–6 months', 'More than 6 months'].map((o) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() => _emergencyFundMonths = o),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _emergencyFundMonths == o ? AppColors.financeGreen.withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _emergencyFundMonths == o ? AppColors.financeGreen : const Color(0xFFE5E7EB)),
                ),
                child: Text(o, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _emergencyFundMonths == o ? AppColors.financeGreen : const Color(0xFF374151))),
              ),
            ),
          )),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFFD97706)),
          SizedBox(width: 8),
          Expanded(child: Text('We recommend building an emergency fund of at least 3 months of expenses.', style: TextStyle(fontSize: 12, color: Color(0xFFD97706)))),
        ]),
      ),
    ]);
  }

  // ── Step 9: Spending Behaviour ────────────────────────────────
  Widget _spendingBehaviourStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Spending behaviour', 'How would you describe yourself?'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        'I spend everything', 'I save occasionally', 'I save regularly', 'I invest regularly',
      ].map((s) => _chip(s, _spendingStyle == s, () => setState(() => _spendingStyle = s))).toList()),
      const SizedBox(height: 20),
      const Text('Biggest financial challenge', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        'Saving', 'Debt', 'Budgeting', 'Overspending', 'Low income', 'Unexpected expenses',
      ].map((s) => _chip(s, _biggestChallenge == s, () => setState(() => _biggestChallenge = s))).toList()),
    ]);
  }

  // ── Step 10: Round Ups ───────────────────────────────────────
  Widget _roundUpsStep() {
    return StatefulBuilder(builder: (context, setLocal) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('Round Ups', 'Would you like Nebo to automatically save your spare change?'),
        Row(children: [
          Expanded(child: _bigChoice('Yes, I\'m in!', _roundupEnabled, () => setLocal(() => _roundupEnabled = true))),
          const SizedBox(width: 10),
          Expanded(child: _bigChoice('Maybe later', !_roundupEnabled, () => setLocal(() => _roundupEnabled = false))),
        ]),
        if (_roundupEnabled) ...[
          const SizedBox(height: 20),
          const Text('Round up to the nearest', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [10.0, 20.0, 50.0, 100.0].map((v) => _chip(
                'KES ${v.round()}', _roundupAmount == v, () => setLocal(() => _roundupAmount = v),
              )).toList()),
        ],
      ]);
    });
  }

  Widget _bigChoice(String label, bool selected, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.financeGreen.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.financeGreen : const Color(0xFFE5E7EB)),
          ),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: selected ? AppColors.financeGreen : const Color(0xFF6B7280))),
        ),
      );

  // ── Step 11: Credit Profile ───────────────────────────────────
  Widget _creditProfileStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Credit profile', 'Would you like Nebo to retrieve your credit report?'),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('This helps us:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF111827))),
          SizedBox(height: 8),
          Row(children: [Icon(Icons.check_rounded, size: 16, color: AppColors.financeGreen), SizedBox(width: 6), Text('Find your existing loans', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)))]),
          SizedBox(height: 4),
          Row(children: [Icon(Icons.check_rounded, size: 16, color: AppColors.financeGreen), SizedBox(width: 6), Text('Improve your repayment plan', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)))]),
          SizedBox(height: 4),
          Row(children: [Icon(Icons.check_rounded, size: 16, color: AppColors.financeGreen), SizedBox(width: 6), Text('Build a personalised strategy', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)))]),
        ]),
      ),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _bigChoice('Yes, get my report', _wantsCreditReport == true, () => setState(() => _wantsCreditReport = true))),
        const SizedBox(width: 10),
        Expanded(child: _bigChoice('Maybe later', _wantsCreditReport == false, () => setState(() => _wantsCreditReport = false))),
      ]),
      if (_wantsCreditReport == true) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Icon(Icons.notifications_outlined, size: 16, color: AppColors.financeGreen),
            SizedBox(width: 8),
            Expanded(child: Text("We'll notify you when credit reports are available.", style: TextStyle(fontSize: 12, color: AppColors.financeGreen, fontWeight: FontWeight.w600))),
          ]),
        ),
      ],
    ]);
  }

  // ── Step 12: Nia AI ──────────────────────────────────────────
  Widget _niaStep() {
    return StatefulBuilder(builder: (context, setLocal) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('Meet Nia', 'What would you like Nia to help you with?'),
        Wrap(spacing: 8, runSpacing: 8, children: _niaFocusOptions.map((o) => _chip(
              o, _niaFocus.contains(o),
              () => setLocal(() => _niaFocus.contains(o) ? _niaFocus.remove(o) : _niaFocus.add(o)),
            )).toList()),
      ]);
    });
  }
}

// ── Small reusable add sheets ─────────────────────────────────────

class _QuickDebtSheet extends StatefulWidget {
  const _QuickDebtSheet();
  @override
  State<_QuickDebtSheet> createState() => _QuickDebtSheetState();
}

class _QuickDebtSheetState extends State<_QuickDebtSheet> {
  final _nameCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  String _type = 'bank_loan';

  static const _types = {
    'bank_loan': 'Bank', 'mobile_loan': 'Mobile Loan', 'sacco': 'SACCO', 'friend_family': 'Friend/Family', 'other': 'Other',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Add Debt', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Lender Name')),
        const SizedBox(height: 12),
        TextField(controller: _amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Outstanding Balance (KES)')),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: _types.entries.map((e) => ChoiceChip(
              label: Text(e.value), selected: _type == e.key, onSelected: (_) => setState(() => _type = e.key),
              selectedColor: AppColors.financeGreen.withValues(alpha: 0.15),
            )).toList()),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () {
            final amt = double.tryParse(_amtCtrl.text.trim());
            if (_nameCtrl.text.trim().isEmpty || amt == null || amt <= 0) return;
            Navigator.pop(context, {'creditor_name': _nameCtrl.text.trim(), 'amount_owed': amt, 'debt_type': _type});
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreen, padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('Save Debt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )),
      ]),
    );
  }
}

class _QuickMoneyOwedSheet extends StatefulWidget {
  const _QuickMoneyOwedSheet();
  @override
  State<_QuickMoneyOwedSheet> createState() => _QuickMoneyOwedSheetState();
}

class _QuickMoneyOwedSheetState extends State<_QuickMoneyOwedSheet> {
  final _nameCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  String _relationship = 'friend';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Money Owed To You', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Person's Name")),
        const SizedBox(height: 12),
        TextField(controller: _amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (KES)')),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: ['friend', 'family', 'customer', 'employee', 'other'].map((r) => ChoiceChip(
              label: Text(r[0].toUpperCase() + r.substring(1)), selected: _relationship == r, onSelected: (_) => setState(() => _relationship = r),
              selectedColor: AppColors.financeGreen.withValues(alpha: 0.15),
            )).toList()),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () {
            final amt = double.tryParse(_amtCtrl.text.trim());
            if (_nameCtrl.text.trim().isEmpty || amt == null || amt <= 0) return;
            Navigator.pop(context, {'person_name': _nameCtrl.text.trim(), 'amount': amt, 'relationship': _relationship});
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreen, padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )),
      ]),
    );
  }
}

class _QuickGoalSheet extends StatefulWidget {
  const _QuickGoalSheet();
  @override
  State<_QuickGoalSheet> createState() => _QuickGoalSheetState();
}

class _QuickGoalSheetState extends State<_QuickGoalSheet> {
  final _nameCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Financial Goal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Goal Name (e.g. Emergency Fund)')),
        const SizedBox(height: 12),
        TextField(controller: _amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target Amount (KES, min 100)')),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () {
            final amt = double.tryParse(_amtCtrl.text.trim());
            if (_nameCtrl.text.trim().isEmpty || amt == null || amt < 100) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a name and target of at least KES 100')));
              return;
            }
            Navigator.pop(context, {'title': _nameCtrl.text.trim(), 'target_amount': amt});
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreen, padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('Save Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )),
      ]),
    );
  }
}
