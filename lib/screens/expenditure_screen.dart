import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../services/sms_finance_service.dart';
import 'package:intl/intl.dart';

class ExpenditureScreen extends StatefulWidget {
  final String userId;
  const ExpenditureScreen({super.key, required this.userId});

  @override
  State<ExpenditureScreen> createState() => _ExpenditureScreenState();
}

class _ExpenditureScreenState extends State<ExpenditureScreen> {
  bool _loading = true;
  bool _smsGranted = false;
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  List<FinanceTransaction> _all = [];
  final fmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _smsGranted = await SmsFinanceService.checkPermission();
    if (_smsGranted) {
      await _load();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _requestAndLoad() async {
    final granted = await SmsFinanceService.requestPermission();
    setState(() => _smsGranted = granted);
    if (granted) await _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _loading = true);
    final txs = await SmsFinanceService.loadAll(forceRefresh: forceRefresh);
    setState(() {
      _all = txs;
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
    final set = _all.map((t) => '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}').toSet().toList();
    set.sort((a, b) => b.compareTo(a));
    return set;
  }

  double get _income => SmsFinanceService.totalIncome(_filtered);
  double get _expenses => SmsFinanceService.totalExpenses(_filtered);
  double get _balance => _income - _expenses;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.financeGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Expenditure', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (_smsGranted)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Refresh SMS',
              onPressed: () => _load(forceRefresh: true),
            ),
        ],
      ),
      body: !_smsGranted
          ? _buildPermissionGate()
          : _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.financeGreenV3))
              : _buildContent(),
    );
  }

  Widget _buildPermissionGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: AppColors.financeGreenV3.withValues(alpha:0.1), shape: BoxShape.circle),
              child: const Icon(Icons.sms_outlined, size: 40, color: AppColors.financeGreenV3),
            ),
            const SizedBox(height: 24),
            const Text('SMS Access Required',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              'We read your M-Pesa and bank SMS messages to automatically track your income and expenses across the last 6 months. Your messages never leave your device.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _requestAndLoad,
              icon: const Icon(Icons.lock_open_outlined, color: Colors.white),
              label: const Text('Allow SMS Access',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.financeGreen,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('🔒 Your data never leaves your device',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final filtered = _filtered;
    final categories = SmsFinanceService.expensesByCategory(filtered);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 6-month indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.financeGreenV3.withValues(alpha:0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.financeGreenV3.withValues(alpha:0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, size: 14, color: AppColors.financeGreenV3),
                const SizedBox(width: 6),
                Text(
                  '${_all.length} transactions loaded • Last 6 months',
                  style: const TextStyle(fontSize: 12, color: AppColors.financeGreenV3, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          _buildMonthSelector(),
          const SizedBox(height: 16),
          _buildSummaryCards(),
          const SizedBox(height: 16),

          if (_income > 0) ...[
            _buildSavingsRate(),
            const SizedBox(height: 20),
          ],

          if (categories.isNotEmpty) ...[
            const Text('Expenses by Category',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 12),
            ...categories.entries.map((e) => _buildCategoryRow(e.key, e.value, _expenses)),
            const SizedBox(height: 20),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Transactions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              Text('${filtered.length} found', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            ],
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFD1D5DB)),
                    const SizedBox(height: 12),
                    const Text('No M-Pesa or bank messages found for this month',
                        textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((t) => _buildTxRow(t)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    final months = _months;
    if (months.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: months.length,
        itemBuilder: (context, i) {
          final m = months[i];
          final label = DateFormat('MMM yyyy').format(DateFormat('yyyy-MM').parse(m));
          final selected = m == _selectedMonth;
          return GestureDetector(
            onTap: () => setState(() => _selectedMonth = m),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.financeGreen : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? AppColors.financeGreen : const Color(0xFFE5E7EB)),
              ),
              child: Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF374151),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(child: _card('Income', _income, const Color(0xFF059669), Icons.arrow_downward_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _card('Expenses', _expenses, const Color(0xFFDC2626), Icons.arrow_upward_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _card('Balance', _balance,
            _balance >= 0 ? AppColors.financeGreen : const Color(0xFFDC2626),
            Icons.account_balance_wallet_outlined)),
      ],
    );
  }

  Widget _card(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('KES ${fmt.format(amount)}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSavingsRate() {
    final rate = (_balance / _income * 100).clamp(0.0, 100.0);
    final color = rate >= 20 ? AppColors.financeGreenV3 : rate >= 10 ? Colors.orange : Colors.red;
    final label = rate >= 20 ? 'Great saving habit!' : rate >= 10 ? 'You can do better' : 'Try to save more';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Savings Rate',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
              Text('${rate.toStringAsFixed(1)}%',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rate / 100,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(String category, double amount, double total) {
    final pct = total > 0 ? amount / total : 0.0;
    final colorMap = {
      'Groceries': Colors.green, 'Electricity': Colors.amber, 'Water': Colors.blue,
      'Rent': Colors.purple, 'Airtime/Data': Colors.teal, 'Education': Colors.indigo,
      'Health': Colors.red, 'Transport': Colors.orange, 'Food & Dining': Colors.deepOrange,
      'Entertainment': Colors.pink, 'Bills': Colors.brown, 'Insurance': Colors.cyan,
      'Tax/Deductions': Colors.grey,
    };
    final color = colorMap[category] ?? AppColors.financeGreen;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 6)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF374151))),
              ]),
              Text('KES ${fmt.format(amount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTxRow(FinanceTransaction t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (t.isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626)).withValues(alpha:0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              t.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: t.isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.description,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF111827)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (t.isManual)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: Colors.purple.withValues(alpha:0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('manual', style: TextStyle(fontSize: 9, color: Colors.purple, fontWeight: FontWeight.bold)),
                      ),
                    Text('${t.category} • ${t.source} • ${DateFormat('d MMM').format(t.date)}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${t.isIncome ? '+' : '-'} KES ${fmt.format(t.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13,
              color: t.isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
}
