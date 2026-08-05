import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../services/sms_finance_service.dart';

class FinanceManagerScreen extends StatefulWidget {
  final String userId;
  const FinanceManagerScreen({super.key, required this.userId});

  @override
  State<FinanceManagerScreen> createState() => _FinanceManagerScreenState();
}

class _FinanceManagerScreenState extends State<FinanceManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<FinanceTransaction> _all = [];
  BalanceStatement? _statement;
  bool _loading = true;
  bool _smsGranted = false;
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  final fmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _smsGranted = await SmsFinanceService.checkPermission();
    await _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _loading = true);
    final txs = await SmsFinanceService.loadAll(forceRefresh: forceRefresh);
    setState(() {
      _all = txs;
      _statement = SmsFinanceService.buildStatement(txs);
      _loading = false;
    });
  }

  List<FinanceTransaction> get _filtered {
    return _all.where((t) {
      final m = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      return m == _selectedMonth;
    }).toList();
  }

  List<String> get _months {
    final set = _all
        .map((t) => '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}')
        .toSet()
        .toList();
    set.sort((a, b) => b.compareTo(a));
    return set;
  }

  MonthStatement? get _monthStmt {
    if (_statement == null) return null;
    try { return _statement!.months.firstWhere((m) => m.month == _selectedMonth); } catch (_) { return null; }
  }

  double get _income => _monthStmt?.totalIncome ?? SmsFinanceService.totalIncome(_filtered);
  double get _expenses => _monthStmt?.expenses ?? SmsFinanceService.totalExpenses(_filtered);
  // Real M-Pesa running account balance — NOT income minus expenses.
  double get _mpesaBalance => _monthStmt?.closingBalance ?? 0;
  // What was actually saved this period. Can be negative — a deficit
  // month is real and should be shown as such, not hidden as KES 0.
  double get _netSaved => _income - _expenses;

  void _showAddSheet({FinanceTransaction? editing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTransactionSheet(
        editing: editing,
        onSave: (tx) async {
          if (editing != null) {
            await SmsFinanceService.updateManual(tx);
          } else {
            await SmsFinanceService.addManual(tx);
          }
          await _load();
        },
      ),
    );
  }

  Future<void> _delete(FinanceTransaction tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete transaction?'),
        content: Text('Remove "${tx.description}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SmsFinanceService.deleteManual(tx.id);
      await _load();
    }
  }

  Future<void> _requestSms() async {
    final granted = await SmsFinanceService.requestPermission();
    setState(() => _smsGranted = granted);
    if (granted) await _load(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Finance Manager', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(forceRefresh: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.financeGreen,
          labelColor: AppColors.financeGreen,
          unselectedLabelColor: const Color(0xFF9CA3AF),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Transactions'),
            Tab(text: 'Budgets'),
            Tab(text: 'Personal'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(),
        backgroundColor: AppColors.financeGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.financeGreenV3))
          : TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(
                  all: _all,
                  filtered: _filtered,
                  months: _months,
                  selectedMonth: _selectedMonth,
                  onMonthChanged: (m) => setState(() => _selectedMonth = m),
                  income: _income,
                  expenses: _expenses,
                  mpesaBalance: _mpesaBalance,
                  netSaved: _netSaved,
                  smsGranted: _smsGranted,
                  onRequestSms: _requestSms,
                  fmt: fmt,
                ),
                _TransactionsTab(
                  filtered: _filtered,
                  months: _months,
                  selectedMonth: _selectedMonth,
                  onMonthChanged: (m) => setState(() => _selectedMonth = m),
                  onEdit: (tx) => _showAddSheet(editing: tx),
                  onDelete: _delete,
                  fmt: fmt,
                ),
                _BudgetTab(
                  filtered: _filtered,
                  income: _income,
                  expenses: _expenses,
                  fmt: fmt,
                ),
                _PersonalFinanceTab(
                  all: _all,
                  statement: _statement,
                  onAdd: () => _showAddSheet(),
                  onEdit: (tx) => _showAddSheet(editing: tx),
                  onDelete: _delete,
                  fmt: fmt,
                ),
              ],
            ),
    );
  }
}

// ── Overview Tab ────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final List<FinanceTransaction> all;
  final List<FinanceTransaction> filtered;
  final List<String> months;
  final String selectedMonth;
  final ValueChanged<String> onMonthChanged;
  final double income, expenses;
  // mpesaBalance = real running M-Pesa account balance.
  // netSaved = income - expenses for the period; can be negative.
  final double mpesaBalance, netSaved;
  final bool smsGranted;
  final VoidCallback onRequestSms;
  final NumberFormat fmt;

  const _OverviewTab({
    required this.all, required this.filtered, required this.months,
    required this.selectedMonth, required this.onMonthChanged,
    required this.income, required this.expenses,
    required this.mpesaBalance, required this.netSaved,
    required this.smsGranted, required this.onRequestSms, required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final categories = SmsFinanceService.expensesByCategory(filtered);
    final savingsRate = income > 0 ? ((netSaved / income) * 100).clamp(-100.0, 100.0) : 0.0;
    final byMonth = SmsFinanceService.groupByMonth(all);
    final sortedMonths = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SMS banner if not granted
          if (!smsGranted) _SmsBanner(onTap: onRequestSms),
          if (!smsGranted) const SizedBox(height: 12),

          // Stats strip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.financeGreenV3.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.financeGreenV3.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('${all.length}', 'Total txns', AppColors.financeGreen),
                _vDivider(),
                _stat('${all.where((t) => t.isManual).length}', 'Manual', Colors.purple),
                _vDivider(),
                _stat('${all.where((t) => !t.isManual).length}', 'From SMS', Colors.teal),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Month picker
          _MonthPicker(months: months, selected: selectedMonth, onChanged: onMonthChanged),
          const SizedBox(height: 16),

          // Summary cards — Income/Expenses are what happened; Net Saved is
          // income minus expenses (can be negative — a deficit is real and
          // shown honestly, not hidden as KES 0); M-Pesa Balance is the
          // separate, real running account balance, not a derived figure.
          Row(children: [
            Expanded(child: _SummaryCard('Income', income, const Color(0xFF059669), Icons.arrow_downward_rounded, fmt)),
            const SizedBox(width: 10),
            Expanded(child: _SummaryCard('Expenses', expenses, const Color(0xFFDC2626), Icons.arrow_upward_rounded, fmt)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _SummaryCard('Net Saved', netSaved,
                netSaved < 0 ? const Color(0xFFDC2626) : AppColors.financeGreen,
                netSaved < 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded, fmt)),
            const SizedBox(width: 10),
            Expanded(child: _SummaryCard('M-Pesa Balance', mpesaBalance,
                const Color(0xFF6366F1),
                Icons.account_balance_wallet_outlined, fmt)),
          ]),
          const SizedBox(height: 16),

          // Savings rate
          if (income > 0) ...[
            _SavingsRateCard(rate: savingsRate),
            const SizedBox(height: 20),
          ],

          // Category breakdown
          if (categories.isNotEmpty) ...[
            const Text('Spending Breakdown',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 10),
            ...categories.entries.take(6).map((e) => _CategoryBar(
                  label: e.key, amount: e.value, total: expenses, fmt: fmt)),
            const SizedBox(height: 20),
          ],

          // 6-month trend
          if (sortedMonths.length > 1) ...[
            const Text('6-Month Trend',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 10),
            ...sortedMonths.take(6).map((m) {
              final mTxs = byMonth[m]!;
              final mInc = SmsFinanceService.totalIncome(mTxs);
              final mExp = SmsFinanceService.totalExpenses(mTxs);
              // Net saved this month = income - expenses. Can be negative —
              // a deficit month is shown honestly, not clamped to 0.
              final mNet = mInc - mExp;
              final hasUnexplained = mInc > mExp + 0.01;
              final label = DateFormat('MMM yy').format(DateFormat('yyyy-MM').parse(m));
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(label,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF374151))),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _miniBar('In', mInc, const Color(0xFF059669)),
                          const SizedBox(height: 4),
                          _miniBar('Ex', mExp, const Color(0xFFDC2626)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(
                        mNet < 0 ? '-KES ${fmt.format(mNet.abs())}' : 'KES ${fmt.format(mNet)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11,
                          color: mNet < 0 ? const Color(0xFFDC2626) : AppColors.financeGreen,
                        ),
                      ),
                      Text('net', style: TextStyle(fontSize: 8, color: Colors.grey.shade400)),
                      if (hasUnexplained)
                        Text('bal txn', style: TextStyle(fontSize: 9, color: Colors.orange.shade700)),
                    ]),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color color) => Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
        ],
      );

  Widget _vDivider() => Container(width: 1, height: 32, color: const Color(0xFFE5E7EB));

  Widget _miniBar(String label, double amount, Color color) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF), fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: amount > 0 ? (amount / (amount + 1)).clamp(0.0, 1.0) : 0,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Transactions Tab ─────────────────────────────────────────────────────────

class _TransactionsTab extends StatefulWidget {
  final List<FinanceTransaction> filtered;
  final List<String> months;
  final String selectedMonth;
  final ValueChanged<String> onMonthChanged;
  final ValueChanged<FinanceTransaction> onEdit;
  final ValueChanged<FinanceTransaction> onDelete;
  final NumberFormat fmt;

  const _TransactionsTab({
    required this.filtered, required this.months, required this.selectedMonth,
    required this.onMonthChanged, required this.onEdit, required this.onDelete,
    required this.fmt,
  });

  @override
  State<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<_TransactionsTab> {
  String _filter = 'all'; // all, income, expense, manual

  List<FinanceTransaction> get _visible {
    return widget.filtered.where((t) {
      if (_filter == 'income') return t.isIncome;
      if (_filter == 'expense') return !t.isIncome;
      if (_filter == 'manual') return t.isManual;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            children: [
              _MonthPicker(months: widget.months, selected: widget.selectedMonth, onChanged: widget.onMonthChanged),
              const SizedBox(height: 10),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in [
                      ('all', 'All'),
                      ('income', 'Income'),
                      ('expense', 'Expenses'),
                      ('manual', 'Manual'),
                    ])
                      GestureDetector(
                        onTap: () => setState(() => _filter = f.$1),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _filter == f.$1 ? AppColors.financeGreen : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _filter == f.$1 ? AppColors.financeGreen : const Color(0xFFE5E7EB)),
                          ),
                          child: Text(f.$2,
                              style: TextStyle(
                                  color: _filter == f.$1 ? Colors.white : const Color(0xFF374151),
                                  fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: visible.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFD1D5DB)),
                      SizedBox(height: 12),
                      Text('No transactions found', style: TextStyle(color: Color(0xFF6B7280))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                  itemCount: visible.length,
                  itemBuilder: (_, i) => _TxTile(
                    tx: visible[i],
                    fmt: widget.fmt,
                    onEdit: widget.onEdit,
                    onDelete: widget.onDelete,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Budget Tab ───────────────────────────────────────────────────────────────

class _BudgetTab extends StatelessWidget {
  final List<FinanceTransaction> filtered;
  final double income, expenses;
  final NumberFormat fmt;

  const _BudgetTab({required this.filtered, required this.income, required this.expenses, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final categories = SmsFinanceService.expensesByCategory(filtered);
    // Real net saved this period — can be negative on a deficit month.
    final savedAmt = income - expenses;
    final savingsRate = income > 0 ? (savedAmt / income * 100).clamp(-100.0, 100.0) : 0.0;

    // 50/30/20 rule targets
    final needs = income * 0.50;
    final wants = income * 0.30;
    final savingsTarget = income * 0.20;

    // Classify categories
    const needsCats = {'Rent', 'Groceries', 'Electricity', 'Water', 'Health', 'Transport', 'Education', 'Insurance', 'Tax/Deductions'};
    double needsSpend = 0, wantsSpend = 0;
    for (final e in categories.entries) {
      if (needsCats.contains(e.key)) {
        needsSpend += e.value;
      } else {
        wantsSpend += e.value;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.financeGreen, AppColors.financeGreenV3],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('50/30/20 Budget Rule',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                const Text('Needs / Wants / Savings',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _budgetPill('Needs\n50%', needsSpend, needs, Colors.white, Colors.white30)),
                    const SizedBox(width: 8),
                    Expanded(child: _budgetPill('Wants\n30%', wantsSpend, wants, Colors.white, Colors.white30)),
                    const SizedBox(width: 8),
                    Expanded(child: _budgetPill('Savings\n20%', savedAmt, savingsTarget, Colors.white, Colors.white30, higherIsBetter: true)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Savings rate gauge
          const Text('Savings Rate',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 10),
          _SavingsRateCard(rate: savingsRate),
          const SizedBox(height: 20),

          // Per-category budget
          const Text('Category Spending',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 10),
          ...categories.entries.map((e) => _CategoryBudgetRow(
                label: e.key,
                spent: e.value,
                budget: needsCats.contains(e.key) ? needs / needsCats.length : wants / 5,
                fmt: fmt,
              )),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _budgetPill(String label, double actual, double target, Color fg, Color bg, {bool higherIsBetter = false}) {
    final ok = higherIsBetter ? actual >= target : actual <= target;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            actual < 0 ? '-KES ${(actual.abs() / 1000).toStringAsFixed(1)}k' : 'KES ${(actual / 1000).toStringAsFixed(1)}k',
            style: TextStyle(color: ok ? fg : Colors.orange, fontWeight: FontWeight.bold, fontSize: 11),
          ),
          Text('of KES ${(target / 1000).toStringAsFixed(1)}k',
              style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 9)),
        ],
      ),
    );
  }
}

class _CategoryBudgetRow extends StatelessWidget {
  final String label;
  final double spent, budget;
  final NumberFormat fmt;

  const _CategoryBudgetRow({required this.label, required this.spent, required this.budget, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final pct = budget > 0 ? (spent / budget).clamp(0.0, 1.5) : 0.0;
    final over = pct > 1.0;
    final color = over ? Colors.red : pct > 0.8 ? Colors.orange : AppColors.financeGreenV3;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF374151))),
              Row(children: [
                Text('KES ${fmt.format(spent)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
                if (over) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                ],
              ]),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(pct * 100).toStringAsFixed(0)}% of budget',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
              if (over)
                Text('Over by KES ${fmt.format(spent - budget)}',
                    style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add / Edit bottom sheet ──────────────────────────────────────────────────

class _AddTransactionSheet extends StatefulWidget {
  final FinanceTransaction? editing;
  final Future<void> Function(FinanceTransaction) onSave;

  const _AddTransactionSheet({this.editing, required this.onSave});

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isIncome = false;
  String _category = 'Payments';
  String _source = 'Manual';
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _incomeCategories = ['Salary', 'Income', 'Freelance', 'Business', 'Rental', 'Investment', 'Gift', 'Reversal'];
  static const _expenseCategories = ['Rent', 'Groceries', 'Electricity', 'Water', 'Transport', 'Food & Dining', 'Airtime/Data', 'Education', 'Health', 'Entertainment', 'Insurance', 'Bills', 'Payments', 'Withdrawal', 'Other'];
  static const _sources = ['Manual', 'M-Pesa', 'Equity Bank', 'KCB', 'Co-op Bank', 'NCBA', 'Absa', 'Family Bank', 'Cash'];

  List<String> get _cats => _isIncome ? _incomeCategories : _expenseCategories;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _amountCtrl.text = e.amount.toStringAsFixed(2);
      _descCtrl.text = e.description;
      _isIncome = e.isIncome;
      _category = e.category;
      _source = e.source;
      _date = e.date;
    } else {
      _category = _expenseCategories.first;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a description')));
      return;
    }

    setState(() => _saving = true);
    final tx = FinanceTransaction(
      id: widget.editing?.id ?? '${DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
      isIncome: _isIncome,
      category: _category,
      description: _descCtrl.text.trim(),
      date: _date,
      source: _source,
      isManual: true,
    );
    await widget.onSave(tx);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            Text(widget.editing != null ? 'Edit Transaction' : 'Add Transaction',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 20),

            // Income / Expense toggle
            Container(
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() { _isIncome = false; _category = _expenseCategories.first; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isIncome ? const Color(0xFFDC2626) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text('Expense',
                            style: TextStyle(fontWeight: FontWeight.bold, color: !_isIncome ? Colors.white : const Color(0xFF6B7280))),
                      ),
                    ),
                  )),
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() { _isIncome = true; _category = _incomeCategories.first; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isIncome ? const Color(0xFF059669) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text('Income',
                            style: TextStyle(fontWeight: FontWeight.bold, color: _isIncome ? Colors.white : const Color(0xFF6B7280))),
                      ),
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Amount
            _field(_amountCtrl, 'Amount (KES)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),

            // Description
            _field(_descCtrl, 'Description'),
            const SizedBox(height: 12),

            // Category
            DropdownButtonFormField<String>(
              initialValue: _cats.contains(_category) ? _category : _cats.first,
              decoration: _decor('Category'),
              items: _cats.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),

            // Source
            DropdownButtonFormField<String>(
              initialValue: _source,
              decoration: _decor('Source'),
              items: _sources.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: (v) => setState(() => _source = v!),
            ),
            const SizedBox(height: 12),

            // Date
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('d MMM yyyy').format(_date),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF111827))),
                    const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF6B7280)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.financeGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(widget.editing != null ? 'Update' : 'Save Transaction',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
      decoration: _decor(label),
    );
  }

  InputDecoration _decor(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.financeGreen)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _MonthPicker extends StatelessWidget {
  final List<String> months;
  final String selected;
  final ValueChanged<String> onChanged;
  const _MonthPicker({required this.months, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: months.length,
        itemBuilder: (_, i) {
          final m = months[i];
          final label = DateFormat('MMM yy').format(DateFormat('yyyy-MM').parse(m));
          final sel = m == selected;
          return GestureDetector(
            onTap: () => onChanged(m),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? AppColors.financeGreen : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: sel ? AppColors.financeGreen : const Color(0xFFE5E7EB)),
              ),
              child: Text(label,
                  style: TextStyle(color: sel ? Colors.white : const Color(0xFF374151), fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;
  final NumberFormat fmt;
  const _SummaryCard(this.title, this.amount, this.color, this.icon, this.fmt);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          amount < 0 ? '-KES ${fmt.format(amount.abs())}' : 'KES ${fmt.format(amount)}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ]),
    );
  }
}

class _SavingsRateCard extends StatelessWidget {
  final double rate;
  const _SavingsRateCard({required this.rate});

  @override
  Widget build(BuildContext context) {
    final color = rate >= 20 ? AppColors.financeGreenV3 : rate >= 10 ? Colors.orange : Colors.red;
    final label = rate >= 20 ? '🎉 Great saving habit!' : rate >= 10 ? '👍 You can do better' : '⚠️ Try to save more';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Savings Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
          Text('${rate.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: rate / 100, backgroundColor: const Color(0xFFF3F4F6), valueColor: AlwaysStoppedAnimation(color), minHeight: 10),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String label;
  final double amount, total;
  final NumberFormat fmt;
  const _CategoryBar({required this.label, required this.amount, required this.total, required this.fmt});

  static const _colors = {
    'Groceries': Colors.green, 'Electricity': Colors.amber, 'Water': Colors.blue,
    'Rent': Colors.purple, 'Airtime/Data': Colors.teal, 'Education': Colors.indigo,
    'Health': Colors.red, 'Transport': Colors.orange, 'Food & Dining': Colors.deepOrange,
    'Entertainment': Colors.pink, 'Bills': Colors.brown, 'Insurance': Colors.cyan,
  };

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? amount / total : 0.0;
    final color = _colors[label] ?? AppColors.financeGreen;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF374151))),
          ]),
          Text('KES ${fmt.format(amount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF111827))),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: pct, backgroundColor: const Color(0xFFF3F4F6), valueColor: AlwaysStoppedAnimation(color), minHeight: 5),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
        ]),
      ]),
    );
  }
}

class _TxTile extends StatelessWidget {
  final FinanceTransaction tx;
  final NumberFormat fmt;
  final ValueChanged<FinanceTransaction> onEdit;
  final ValueChanged<FinanceTransaction> onDelete;
  const _TxTile({required this.tx, required this.fmt, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: (tx.isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626)).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(tx.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: tx.isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626), size: 20),
        ),
        title: Text(tx.description,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF111827)),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${tx.category} • ${tx.source} • ${DateFormat('d MMM').format(tx.date)}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${tx.isIncome ? '+' : '-'} KES ${fmt.format(tx.amount)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                        color: tx.isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626))),
                if (tx.isManual)
                  const Text('manual', style: TextStyle(fontSize: 9, color: Colors.purple, fontWeight: FontWeight.bold)),
              ],
            ),
            if (tx.isManual) ...[
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF6B7280)),
                onSelected: (v) {
                  if (v == 'edit') onEdit(tx);
                  if (v == 'delete') onDelete(tx);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Personal Finance Tab ─────────────────────────────────────────────────────

class _PersonalFinanceTab extends StatefulWidget {
  final List<FinanceTransaction> all;
  final BalanceStatement? statement;
  final VoidCallback onAdd;
  final ValueChanged<FinanceTransaction> onEdit;
  final ValueChanged<FinanceTransaction> onDelete;
  final NumberFormat fmt;

  const _PersonalFinanceTab({
    required this.all,
    required this.statement,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.fmt,
  });

  @override
  State<_PersonalFinanceTab> createState() => _PersonalFinanceTabState();
}

class _PersonalFinanceTabState extends State<_PersonalFinanceTab> {
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  List<String> get _months {
    final set = widget.all
        .map((t) => '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}')
        .toSet()
        .toList();
    set.sort((a, b) => b.compareTo(a));
    if (!set.contains(_selectedMonth) && set.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedMonth = set.first);
      });
    }
    return set;
  }

  List<FinanceTransaction> get _monthAll {
    return widget.all.where((t) {
      final m = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      return m == _selectedMonth;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  List<FinanceTransaction> get _monthManual =>
      _monthAll.where((t) => t.isManual).toList();

  List<FinanceTransaction> get _monthSms =>
      _monthAll.where((t) => !t.isManual).toList();

  MonthStatement? get _niaMontStmt {
    if (widget.statement == null) return null;
    try {
      return widget.statement!.months.firstWhere((m) => m.month == _selectedMonth);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = _months;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month picker
          if (months.isNotEmpty) ...[
            _MonthPicker(
              months: months,
              selected: _selectedMonth,
              onChanged: (m) => setState(() => _selectedMonth = m),
            ),
            const SizedBox(height: 20),
          ],

          // ── Section 1: Nia AI (M-Pesa auto) ──
          _SectionHeader(
            icon: Icons.auto_awesome_rounded,
            iconColor: const Color(0xFF7C3AED),
            title: 'Nia Statement',
            subtitle: 'Auto-generated from M-Pesa',
          ),
          const SizedBox(height: 12),
          _StatementCard(
            txs: _monthSms,
            monthStmt: _niaMontStmt,
            fmt: widget.fmt,
            readOnly: true,
          ),
          const SizedBox(height: 28),

          // ── Section 2: My Statement (manual) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionHeader(
                icon: Icons.edit_note_rounded,
                iconColor: Color(0xFF059669),
                title: 'My Statement',
                subtitle: 'Your own entries',
              ),
              TextButton.icon(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.financeGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatementCard(
            txs: _monthManual,
            monthStmt: null,
            fmt: widget.fmt,
            readOnly: false,
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Statement Card (used by both Nia and Manual sections) ────────────────────

class _StatementCard extends StatefulWidget {
  final List<FinanceTransaction> txs;
  final MonthStatement? monthStmt;
  final NumberFormat fmt;
  final bool readOnly;
  final ValueChanged<FinanceTransaction>? onEdit;
  final ValueChanged<FinanceTransaction>? onDelete;

  const _StatementCard({
    required this.txs,
    required this.monthStmt,
    required this.fmt,
    required this.readOnly,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_StatementCard> createState() => _StatementCardState();
}

class _StatementCardState extends State<_StatementCard> {
  final _expandedCats = <String>{};

  @override
  Widget build(BuildContext context) {
    final txs = widget.txs;
    final fmt = widget.fmt;

    final double totalIncome = widget.monthStmt != null
        ? widget.monthStmt!.totalIncome.toDouble()
        : SmsFinanceService.totalIncome(txs);
    final double totalExpense = widget.monthStmt != null
        ? widget.monthStmt!.expenses.toDouble()
        : SmsFinanceService.totalExpenses(txs);
    // Real net for the period — can be negative on a deficit.
    final net = totalIncome - totalExpense;
    final double unexplained = widget.monthStmt != null
        ? widget.monthStmt!.unexplainedIncome.toDouble()
        : 0.0;

    // Group income by category
    final incCats = <String, List<FinanceTransaction>>{};
    for (final t in txs.where((t) => t.isIncome)) {
      incCats.putIfAbsent(t.category, () => []).add(t);
    }
    // Group expenses by category
    final expCats = <String, List<FinanceTransaction>>{};
    for (final t in txs.where((t) => !t.isIncome)) {
      expCats.putIfAbsent(t.category, () => []).add(t);
    }

    final sortedInc = incCats.entries.toList()
      ..sort((a, b) => b.value.fold(0.0, (s, t) => s + t.amount)
          .compareTo(a.value.fold(0.0, (s, t) => s + t.amount)));
    final sortedExp = expCats.entries.toList()
      ..sort((a, b) => b.value.fold(0.0, (s, t) => s + t.amount)
          .compareTo(a.value.fold(0.0, (s, t) => s + t.amount)));

    if (txs.isEmpty && widget.monthStmt == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Column(children: [
          Icon(
            widget.readOnly ? Icons.auto_awesome_outlined : Icons.receipt_long_outlined,
            size: 40, color: const Color(0xFFD1D5DB),
          ),
          const SizedBox(height: 10),
          Text(
            widget.readOnly ? 'No M-Pesa transactions this month' : 'No entries this month',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ]),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // ── INCOME section ──
          _StatementSectionHeader(label: 'INCOME', amount: totalIncome, color: const Color(0xFF059669), fmt: fmt),
          if (unexplained > 0)
            _StatementBalanceTxRow(amount: unexplained, fmt: fmt),
          ...sortedInc.map((e) {
            final catTotal = e.value.fold(0.0, (s, t) => s + t.amount);
            final key = 'inc_${e.key}';
            final expanded = _expandedCats.contains(key);
            return _StatementCategoryRow(
              label: e.key,
              amount: catTotal,
              color: const Color(0xFF059669),
              fmt: fmt,
              expanded: expanded,
              onToggle: () => setState(() => expanded ? _expandedCats.remove(key) : _expandedCats.add(key)),
              children: expanded
                  ? e.value.map((tx) => _StatementTxRow(
                        tx: tx, fmt: fmt, readOnly: widget.readOnly,
                        onEdit: widget.onEdit, onDelete: widget.onDelete,
                      )).toList()
                  : [],
            );
          }),

          // ── Divider ──
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // ── EXPENSES section ──
          _StatementSectionHeader(label: 'EXPENSES', amount: totalExpense, color: const Color(0xFFDC2626), fmt: fmt),
          ...sortedExp.map((e) {
            final catTotal = e.value.fold(0.0, (s, t) => s + t.amount);
            final key = 'exp_${e.key}';
            final expanded = _expandedCats.contains(key);
            return _StatementCategoryRow(
              label: e.key,
              amount: catTotal,
              color: const Color(0xFFDC2626),
              fmt: fmt,
              expanded: expanded,
              onToggle: () => setState(() => expanded ? _expandedCats.remove(key) : _expandedCats.add(key)),
              children: expanded
                  ? e.value.map((tx) => _StatementTxRow(
                        tx: tx, fmt: fmt, readOnly: widget.readOnly,
                        onEdit: widget.onEdit, onDelete: widget.onDelete,
                      )).toList()
                  : [],
            );
          }),

          // ── NET ──
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('NET BALANCE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827))),
                Text(
                  net < 0 ? '-KES ${fmt.format(net.abs())}' : 'KES ${fmt.format(net)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14,
                    color: net > 0 ? const Color(0xFF059669) : net < 0 ? const Color(0xFFDC2626) : const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
      ]),
    ]);
  }
}

class _StatementSectionHeader extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final NumberFormat fmt;

  const _StatementSectionHeader({
    required this.label, required this.amount, required this.color, required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color, letterSpacing: 0.8)),
          Text('KES ${fmt.format(amount)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        ],
      ),
    );
  }
}

class _StatementCategoryRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final NumberFormat fmt;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _StatementCategoryRow({
    required this.label, required this.amount, required this.color,
    required this.fmt, required this.expanded, required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: color.withValues(alpha: 0.6), shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                ),
                Text('KES ${fmt.format(amount)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                const SizedBox(width: 6),
                Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: const Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ),
        if (expanded) ...children,
        const Divider(height: 1, indent: 16, color: Color(0xFFF9FAFB)),
      ],
    );
  }
}

class _StatementTxRow extends StatelessWidget {
  final FinanceTransaction tx;
  final NumberFormat fmt;
  final bool readOnly;
  final ValueChanged<FinanceTransaction>? onEdit;
  final ValueChanged<FinanceTransaction>? onDelete;

  const _StatementTxRow({
    required this.tx, required this.fmt, required this.readOnly,
    this.onEdit, this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.fromLTRB(32, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tx.description,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(DateFormat('d MMM, h:mm a').format(tx.date),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
            ]),
          ),
          Text(
            '${tx.isIncome ? '+' : '-'} KES ${fmt.format(tx.amount)}',
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: tx.isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626),
            ),
          ),
          if (!readOnly && onEdit != null && onDelete != null) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF9CA3AF)),
              onSelected: (v) {
                if (v == 'edit') onEdit!(tx);
                if (v == 'delete') onDelete!(tx);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatementBalanceTxRow extends StatelessWidget {
  final double amount;
  final NumberFormat fmt;

  const _StatementBalanceTxRow({required this.amount, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.swap_horiz_rounded, size: 14, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Balance transaction',
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500)),
        ),
        Text('+ KES ${fmt.format(amount)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
      ]),
    );
  }
}

// ── SMS Grant Banner ──────────────────────────────────────────────────────────

class _SmsBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _SmsBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.sms_outlined, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Tap to enable SMS auto-import (M-Pesa)',
                style: TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
          ),
          const Icon(Icons.chevron_right, color: Colors.amber, size: 18),
        ]),
      ),
    );
  }
}
