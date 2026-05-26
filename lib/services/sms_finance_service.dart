import 'dart:convert';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FinanceTransaction {
  final String id;
  final double amount;
  final bool isIncome;
  final String category;
  final String description;
  final DateTime date;
  final String source; // 'M-Pesa', 'Equity', 'KCB', etc.
  final String raw;
  final bool isManual; // user-entered vs SMS-parsed

  FinanceTransaction({
    required this.id,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.description,
    required this.date,
    required this.source,
    this.raw = '',
    this.isManual = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'isIncome': isIncome,
        'category': category,
        'description': description,
        'date': date.toIso8601String(),
        'source': source,
        'raw': raw,
        'isManual': isManual,
      };

  factory FinanceTransaction.fromJson(Map<String, dynamic> j) =>
      FinanceTransaction(
        id: j['id'],
        amount: (j['amount'] as num).toDouble(),
        isIncome: j['isIncome'],
        category: j['category'],
        description: j['description'],
        date: DateTime.parse(j['date']),
        source: j['source'],
        raw: j['raw'] ?? '',
        isManual: j['isManual'] ?? false,
      );
}

class SmsFinanceService {
  static const _cacheKey = 'sms_finance_cache';
  static const _manualKey = 'manual_finance_transactions';
  static const _lastLoadKey = 'sms_finance_last_load';

  // Request SMS permission and load 6 months of transactions
  static Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  static bool _hasPermission = false;
  static Future<bool> checkPermission() async {
    _hasPermission = await Permission.sms.isGranted;
    return _hasPermission;
  }

  // Load from SMS (last 6 months) + merge with manual entries
  static Future<List<FinanceTransaction>> loadAll({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final sms = await _loadSmsTransactions(prefs, forceRefresh: forceRefresh);
    final manual = _loadManual(prefs);
    final all = [...sms, ...manual];
    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }

  static Future<List<FinanceTransaction>> _loadSmsTransactions(
      SharedPreferences prefs, {bool forceRefresh = false}) async {
    // Use cache unless forced refresh or cache is older than 1 hour
    final lastLoad = prefs.getInt(_lastLoadKey) ?? 0;
    final cacheAge = DateTime.now().millisecondsSinceEpoch - lastLoad;
    final cacheStale = cacheAge > 3600000; // 1 hour

    if (!forceRefresh && !cacheStale) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        try {
          final list = (jsonDecode(cached) as List)
              .map((e) => FinanceTransaction.fromJson(e))
              .toList();
          return list;
        } catch (_) {}
      }
    }

    // Check permission
    final granted = await Permission.sms.isGranted;
    if (!granted) return [];

    try {
      final query = SmsQuery();
      final cutoff = DateTime.now().subtract(const Duration(days: 183)); // ~6 months

      // Load enough messages to cover 6 months (adjust count as needed)
      final messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 2000,
      );

      final parsed = <FinanceTransaction>[];
      for (final msg in messages) {
        // Skip messages older than 6 months
        final date = msg.date ?? DateTime.now();
        if (date.isBefore(cutoff)) continue;

        final tx = _parseSms(msg);
        if (tx != null) parsed.add(tx);
      }

      parsed.sort((a, b) => b.date.compareTo(a.date));

      // Cache results
      prefs.setString(_cacheKey, jsonEncode(parsed.map((t) => t.toJson()).toList()));
      prefs.setInt(_lastLoadKey, DateTime.now().millisecondsSinceEpoch);

      return parsed;
    } catch (_) {
      return [];
    }
  }

  static FinanceTransaction? _parseSms(SmsMessage msg) {
    final body = msg.body ?? '';
    final date = msg.date ?? DateTime.now();
    final sender = (msg.sender ?? '').toUpperCase();

    final isMpesa = sender.contains('MPESA') || body.contains('M-Pesa') || body.contains('MPESA');
    final source = _detectSource(sender, body);
    if (source == null) return null;

    // Extract amount — handle Ksh, KES, both with optional space
    final amountRegex = RegExp(r'(?:Ksh|KES)\s*([\d,]+(?:\.\d{2})?)', caseSensitive: false);
    final match = amountRegex.firstMatch(body);
    if (match == null) return null;
    final amountStr = (match.group(1) ?? '0').replaceAll(',', '');
    final amount = double.tryParse(amountStr) ?? 0;
    if (amount <= 0) return null;

    final lowerBody = body.toLowerCase();
    bool isIncome = false;
    String category = 'Other';

    if (lowerBody.contains('you have received') ||
        lowerBody.contains('received from') ||
        (lowerBody.contains('received') && !lowerBody.contains('not received'))) {
      isIncome = true;
      category = 'Income';
    } else if (lowerBody.contains('salary') || lowerBody.contains('payroll')) {
      isIncome = true;
      category = 'Salary';
    } else if (lowerBody.contains('reversal')) {
      isIncome = true;
      category = 'Reversal';
    } else if (lowerBody.contains('sent to') || lowerBody.contains('paid to')) {
      category = _categorizeExpense(body);
    } else if (lowerBody.contains('withdraw') || lowerBody.contains('withdrawn')) {
      category = 'Withdrawal';
    } else if (lowerBody.contains('buy goods') || lowerBody.contains('paybill') || lowerBody.contains('pay bill')) {
      category = _categorizePaybill(body);
    } else if (lowerBody.contains('airtime') || lowerBody.contains('data bundle')) {
      category = 'Airtime/Data';
    } else if (lowerBody.contains('debit') || lowerBody.contains('debited')) {
      category = _categorizeExpense(body);
    } else if (lowerBody.contains('credit') || lowerBody.contains('credited')) {
      isIncome = true;
      category = 'Income';
    } else {
      return null;
    }

    final description = _extractDescription(body, isMpesa, source);

    return FinanceTransaction(
      id: '${date.millisecondsSinceEpoch}_${amount.toInt()}',
      amount: amount,
      isIncome: isIncome,
      category: category,
      description: description,
      date: date,
      source: source,
      raw: body,
    );
  }

  static String? _detectSource(String sender, String body) {
    if (sender.contains('MPESA') || body.contains('M-Pesa') || body.contains('MPESA')) return 'M-Pesa';
    if (sender.contains('EQUITY') || body.contains('Equity Bank')) return 'Equity Bank';
    if (sender.contains('KCB') || body.contains('KCB Bank')) return 'KCB';
    if (sender.contains('COOP') || body.contains('Co-op Bank') || body.contains('Cooperative Bank')) return 'Co-op Bank';
    if (sender.contains('NCBA') || body.contains('NCBA Bank')) return 'NCBA';
    if (sender.contains('DTB') || body.contains('Diamond Trust')) return 'DTB';
    if (sender.contains('ABSA') || body.contains('Absa Bank')) return 'Absa';
    if (sender.contains('STANBIC') || body.contains('Stanbic Bank')) return 'Stanbic';
    if (sender.contains('FAMILY') || body.contains('Family Bank')) return 'Family Bank';
    if (sender.contains('SIDIAN') || body.contains('Sidian Bank')) return 'Sidian';
    return null;
  }

  static String _categorizeExpense(String body) {
    final b = body.toLowerCase();
    if (b.contains('supermarket') || b.contains('naivas') || b.contains('quickmart') ||
        b.contains('carrefour') || b.contains('tuskys') || b.contains('game ')) return 'Groceries';
    if (b.contains('kplc') || b.contains('kenya power') || b.contains('electricity') || b.contains('888880')) return 'Electricity';
    if (b.contains('water') || b.contains('nairobi water') || b.contains('nawasco')) return 'Water';
    if (b.contains('rent') || b.contains('housing')) return 'Rent';
    if (b.contains('safaricom') || b.contains('airtel') || b.contains('telkom')) return 'Airtime/Data';
    if (b.contains('school') || b.contains('college') || b.contains('university') || b.contains('fees') || b.contains('tuition')) return 'Education';
    if (b.contains('hospital') || b.contains('pharmacy') || b.contains('clinic') || b.contains('nhif') || b.contains('health')) return 'Health';
    if (b.contains('fuel') || b.contains('petrol') || b.contains('uber') || b.contains('bolt') || b.contains('matatu') || b.contains('parking')) return 'Transport';
    if (b.contains('restaurant') || b.contains('hotel') || b.contains('cafe') || b.contains('food') || b.contains('kfc') || b.contains('java')) return 'Food & Dining';
    if (b.contains('dstv') || b.contains('gotv') || b.contains('showmax') || b.contains('netflix') || b.contains('spotify')) return 'Entertainment';
    if (b.contains('insurance') || b.contains('britam') || b.contains('jubilee') || b.contains('aar')) return 'Insurance';
    if (b.contains('nssf') || b.contains('nhif')) return 'Tax/Deductions';
    return 'Payments';
  }

  static String _categorizePaybill(String body) {
    final b = body.toLowerCase();
    if (b.contains('kplc') || b.contains('888880') || b.contains('electricity')) return 'Electricity';
    if (b.contains('dstv') || b.contains('gotv') || b.contains('showmax') || b.contains('netflix')) return 'Entertainment';
    if (b.contains('water')) return 'Water';
    if (b.contains('safaricom') || b.contains('airtel')) return 'Airtime/Data';
    if (b.contains('school') || b.contains('fees')) return 'Education';
    if (b.contains('insurance')) return 'Insurance';
    if (b.contains('rent') || b.contains('house')) return 'Rent';
    return 'Bills';
  }

  static String _extractDescription(String body, bool isMpesa, String source) {
    if (isMpesa) {
      final patterns = [
        RegExp(r'sent to ([^0-9\.]+?)(?:\.|on|\d)', caseSensitive: false),
        RegExp(r'paid to ([^0-9\.]+?)(?:\.|on|\d)', caseSensitive: false),
        RegExp(r'from ([A-Z][^0-9\.]+?)(?:\.|on|\d)', caseSensitive: false),
        RegExp(r'received from ([^0-9\.]+?)(?:\.|on|\d)', caseSensitive: false),
        RegExp(r'Buy Goods ([^0-9\.]+?)(?:\.|on|\d)', caseSensitive: false),
        RegExp(r'Pay Bill ([^0-9\.]+?)(?:\.|on|\d)', caseSensitive: false),
      ];
      for (final p in patterns) {
        final m = p.firstMatch(body);
        if (m != null) {
          final desc = m.group(1)?.trim();
          if (desc != null && desc.length > 2) return desc;
        }
      }
    }
    return '$source Transaction';
  }

  // ── Manual transaction CRUD ────────────────────────────────────────

  static List<FinanceTransaction> _loadManual(SharedPreferences prefs) {
    final raw = prefs.getString(_manualKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => FinanceTransaction.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addManual(FinanceTransaction tx) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _loadManual(prefs);
    list.insert(0, tx);
    await prefs.setString(_manualKey, jsonEncode(list.map((t) => t.toJson()).toList()));
  }

  static Future<void> updateManual(FinanceTransaction tx) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _loadManual(prefs);
    final idx = list.indexWhere((t) => t.id == tx.id);
    if (idx != -1) list[idx] = tx;
    await prefs.setString(_manualKey, jsonEncode(list.map((t) => t.toJson()).toList()));
  }

  static Future<void> deleteManual(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _loadManual(prefs);
    list.removeWhere((t) => t.id == id);
    await prefs.setString(_manualKey, jsonEncode(list.map((t) => t.toJson()).toList()));
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_lastLoadKey);
  }

  // ── Summary helpers ────────────────────────────────────────────────

  static Map<String, List<FinanceTransaction>> groupByMonth(List<FinanceTransaction> txs) {
    final map = <String, List<FinanceTransaction>>{};
    for (final t in txs) {
      final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  static double totalIncome(List<FinanceTransaction> txs) =>
      txs.where((t) => t.isIncome).fold(0, (s, t) => s + t.amount);

  static double totalExpenses(List<FinanceTransaction> txs) =>
      txs.where((t) => !t.isIncome).fold(0, (s, t) => s + t.amount);

  static Map<String, double> expensesByCategory(List<FinanceTransaction> txs) {
    final map = <String, double>{};
    for (final t in txs.where((t) => !t.isIncome)) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  // Build a text summary for Nia AI context
  static String buildNiaContext(List<FinanceTransaction> txs) {
    if (txs.isEmpty) return 'No financial data available.';

    final income = totalIncome(txs);
    final expenses = totalExpenses(txs);
    final savings = income - expenses;
    final savingsRate = income > 0 ? (savings / income * 100) : 0;
    final categories = expensesByCategory(txs);

    final sb = StringBuffer();
    sb.writeln('USER FINANCIAL SUMMARY (last 6 months):');
    sb.writeln('Total Income: KES ${income.toStringAsFixed(2)}');
    sb.writeln('Total Expenses: KES ${expenses.toStringAsFixed(2)}');
    sb.writeln('Net Savings: KES ${savings.toStringAsFixed(2)}');
    sb.writeln('Savings Rate: ${savingsRate.toStringAsFixed(1)}%');
    sb.writeln('Total Transactions: ${txs.length}');
    sb.writeln('');
    sb.writeln('TOP EXPENSE CATEGORIES:');
    int i = 0;
    for (final e in categories.entries) {
      if (i++ >= 5) break;
      sb.writeln('  ${e.key}: KES ${e.value.toStringAsFixed(2)}');
    }

    // Monthly breakdown
    final byMonth = groupByMonth(txs);
    sb.writeln('');
    sb.writeln('MONTHLY BREAKDOWN:');
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final m in months.take(6)) {
      final mTxs = byMonth[m]!;
      final mInc = totalIncome(mTxs);
      final mExp = totalExpenses(mTxs);
      sb.writeln('  $m → Income: KES ${mInc.toStringAsFixed(0)}, Expenses: KES ${mExp.toStringAsFixed(0)}, Saved: KES ${(mInc - mExp).toStringAsFixed(0)}');
    }

    return sb.toString();
  }
}
