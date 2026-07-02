import 'dart:convert';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// M-Pesa transaction types
enum MpesaType {
  received,       // You have received KES X from Y
  sentTo,         // KES X sent to Y
  paybill,        // KES X paid to paybill XXXXXX account YYYY
  buyGoods,       // KES X paid to BUSINESS for account YYYY (Till)
  withdraw,       // KES X withdrawn from Agent XXXXX
  airtime,        // KES X airtime purchased
  fuliza,         // Fuliza M-PESA – KES X
  reversal,       // Transaction reversal
  salary,         // Salary / payroll credit
  unknown,
}

class FinanceTransaction {
  final String id;
  final double amount;
  final bool isIncome;
  final String category;
  final String description;
  final DateTime date;
  final String source; // Always 'M-Pesa' now
  final String raw;
  final bool isManual;
  final String? reference;   // e.g. QJK2X1234A
  final double? balanceAfter;
  final MpesaType mpesaType;

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
    this.reference,
    this.balanceAfter,
    this.mpesaType = MpesaType.unknown,
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
        'reference': reference,
        'balanceAfter': balanceAfter,
        'mpesaType': mpesaType.name,
      };

  factory FinanceTransaction.fromJson(Map<String, dynamic> j) =>
      FinanceTransaction(
        id: j['id'],
        amount: (j['amount'] as num).toDouble(),
        isIncome: j['isIncome'],
        category: j['category'],
        description: j['description'],
        date: DateTime.parse(j['date']),
        source: j['source'] ?? 'M-Pesa',
        raw: j['raw'] ?? '',
        isManual: j['isManual'] ?? false,
        reference: j['reference'],
        balanceAfter: j['balanceAfter'] != null
            ? (j['balanceAfter'] as num).toDouble()
            : null,
        mpesaType: MpesaType.values.firstWhere(
          (e) => e.name == j['mpesaType'],
          orElse: () => MpesaType.unknown,
        ),
      );
}

class SmsFinanceService {
  static const _cacheKey = 'sms_finance_cache';
  static const _manualKey = 'manual_finance_transactions';
  static const _lastLoadKey = 'sms_finance_last_load';

  // ── Permission ─────────────────────────────────────────────────────
  static Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  static bool _hasPermission = false;
  static Future<bool> checkPermission() async {
    _hasPermission = await Permission.sms.isGranted;
    return _hasPermission;
  }

  // ── Load ────────────────────────────────────────────────────────────
  /// Load M-Pesa SMS (last 6 months) + merge with manual entries
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

    final granted = await Permission.sms.isGranted;
    if (!granted) return [];

    try {
      final query = SmsQuery();
      final cutoff = DateTime.now().subtract(const Duration(days: 183));

      final messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 2000,
      );

      final parsed = <FinanceTransaction>[];
      for (final msg in messages) {
        final date = msg.date ?? DateTime.now();
        if (date.isBefore(cutoff)) continue;

        final tx = _parseMpesaSms(msg);
        if (tx != null) parsed.add(tx);
      }

      parsed.sort((a, b) => b.date.compareTo(a.date));

      prefs.setString(_cacheKey, jsonEncode(parsed.map((t) => t.toJson()).toList()));
      prefs.setInt(_lastLoadKey, DateTime.now().millisecondsSinceEpoch);

      return parsed;
    } catch (_) {
      return [];
    }
  }

  // ── M-Pesa SMS Parser ───────────────────────────────────────────────
  /// Returns a transaction only if the SMS is from M-Pesa.
  /// Handles all real Safaricom M-Pesa message formats.
  static FinanceTransaction? _parseMpesaSms(SmsMessage msg) {
    final body = msg.body ?? '';
    final date = msg.date ?? DateTime.now();
    final sender = (msg.sender ?? '').toUpperCase();

    // ── 1. STRICT M-Pesa gate ──────────────────────────────────────
    final isMpesa = sender.contains('MPESA') ||
        sender == 'MPESA' ||
        body.contains('M-Pesa') ||
        body.contains('MPESA');
    if (!isMpesa) return null;

    final b = body.toLowerCase();

    // ── 2. Extract transaction reference (e.g. QJK2X1234A) ─────────
    // M-Pesa refs are 10 alphanumeric chars starting with letters
    final refMatch = RegExp(r'\b([A-Z]{2,3}[A-Z0-9]{7,8})\b').firstMatch(body);
    final reference = refMatch?.group(1);

    // ── 3. Extract amount ───────────────────────────────────────────
    // M-Pesa messages have multiple Ksh values (amount, fee, balance).
    // The TRANSACTION amount is always stated first (before "Transaction cost"
    // or "New M-PESA balance"). Extract ALL amounts then pick the right one.
    final allAmounts = RegExp(
      r'(?:Ksh|KES)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).allMatches(body).map((m) {
      final s = (m.group(1) ?? '0').replaceAll(',', '');
      return double.tryParse(s) ?? 0;
    }).where((v) => v > 0).toList();

    if (allAmounts.isEmpty) return null;

    // The transaction amount is the FIRST Ksh value in the message.
    // Fee is labelled "Transaction cost" and balance is labelled "New M-PESA balance" —
    // so the first amount is always the actual transaction amount.
    final amount = allAmounts.first;
    if (amount <= 0) return null;

    // ── 4. Extract balance after transaction ────────────────────────
    // "New M-PESA balance is Ksh2,500.00"
    final balMatch = RegExp(
      r'(?:balance is|balance:)\s*(?:Ksh|KES)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(body);
    final balanceAfter = balMatch != null
        ? double.tryParse((balMatch.group(1) ?? '').replaceAll(',', ''))
        : null;

    // ── 5. Detect transaction type & classify ───────────────────────
    // IMPORTANT: income checks come FIRST; expense checks follow.
    // Each branch uses the tightest possible keyword to avoid false positives.
    MpesaType mpesaType = MpesaType.unknown;
    bool isIncome = false;
    String category = 'M-Pesa';
    String description = 'M-Pesa Transaction';

    // ── INCOME ─────────────────────────────────────────────────────

    // RECEIVED – "You have received Ksh500.00 from ..."
    // Must contain explicit "received" + a sender — never triggered by sends
    if (b.contains('you have received') ||
        (b.contains('received') && b.contains('from') && !b.contains('sent') && !b.contains('paid to') && !b.contains('pay bill'))) {
      mpesaType = MpesaType.received;
      isIncome = true;
      category = 'Income';
      description = _extractSender(body);
    }

    // SALARY / PAYROLL – explicit payroll credit
    else if ((b.contains('salary') || b.contains('payroll')) &&
             (b.contains('received') || b.contains('credited') || b.contains('from'))) {
      mpesaType = MpesaType.salary;
      isIncome = true;
      category = 'Salary';
      description = _extractSender(body);
    }

    // REVERSAL – money returned to you; only count if "your" money came back
    // "Your transaction of Ksh X to Y has been reversed"
    else if ((b.contains('reversal') || b.contains('reversed')) &&
             (b.contains('your transaction') || b.contains('has been reversed'))) {
      mpesaType = MpesaType.reversal;
      isIncome = true;
      category = 'Reversal';
      description = 'M-Pesa Reversal';
    }

    // ── EXPENSES ───────────────────────────────────────────────────

    // FULIZA – only when you actually borrowed (not informational Safaricom messages
    // like "Your Fuliza limit is Ksh X" which don't represent a real transaction)
    else if (b.contains('fuliza') &&
        (b.contains('you have used') ||
         b.contains('fuliza mpesa') ||
         b.contains('borrowed') ||
         b.contains('repay'))) {
      mpesaType = MpesaType.fuliza;
      isIncome = false;
      category = 'Fuliza';
      description = 'Fuliza M-Pesa';
    }

    // PAYBILL – "Pay Bill" or "paybill" — check BEFORE "sent to" since
    // some paybill confirmations also say "sent to paybill number"
    else if (b.contains('pay bill') || b.contains('paybill')) {
      mpesaType = MpesaType.paybill;
      isIncome = false;
      category = _categorizePaybill(body);
      description = _extractPaybillName(body);
    }

    // BUY GOODS (Till) – "Buy Goods" keyword
    else if (b.contains('buy goods')) {
      mpesaType = MpesaType.buyGoods;
      isIncome = false;
      category = _categorizeMerchant(body);
      description = _extractMerchantName(body);
    }

    // SENT TO PERSON – "sent to" a mobile number (person-to-person)
    else if (b.contains('sent to')) {
      mpesaType = MpesaType.sentTo;
      isIncome = false;
      category = 'Send Money';
      description = _extractRecipient(body);
    }

    // WITHDRAW – must explicitly say "withdrawn" (not just "agent")
    else if (b.contains('withdrawn') || b.contains('withdraw at') || b.contains('withdraw from agent')) {
      mpesaType = MpesaType.withdraw;
      isIncome = false;
      category = 'Withdrawal';
      description = _extractAgentName(body);
    }

    // AIRTIME / DATA – "airtime" or "data bundle"
    else if (b.contains('airtime') || b.contains('data bundle') || b.contains('data pack')) {
      mpesaType = MpesaType.airtime;
      isIncome = false;
      category = 'Airtime/Data';
      description = 'Airtime/Data Purchase';
    }

    // Fallback – unrecognised M-Pesa message, skip it
    else {
      return null;
    }

    return FinanceTransaction(
      id: '${date.millisecondsSinceEpoch}_${amount.toInt()}_${reference ?? ""}',
      amount: amount,
      isIncome: isIncome,
      category: category,
      description: description,
      date: date,
      source: 'M-Pesa',
      raw: body,
      reference: reference,
      balanceAfter: balanceAfter,
      mpesaType: mpesaType,
    );
  }

  // ── Description extractors ──────────────────────────────────────────

  /// Extracts sender name from a "received from X" message
  static String _extractSender(String body) {
    final patterns = [
      RegExp(r'received\s+(?:Ksh|KES)[\d,\.]+\s+from\s+([A-Za-z][^0-9\n\.]{2,30}?)(?:\s+\d|\s+on|\.|$)', caseSensitive: false),
      RegExp(r'from\s+([A-Z][A-Z\s]{2,30}?)(?:\s+\d{10}|\s+on|\.|$)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(body);
      final name = m?.group(1)?.trim();
      if (name != null && name.length > 2) return _titleCase(name);
    }
    return 'M-Pesa Received';
  }

  /// Extracts recipient name from a "sent to X" message
  static String _extractRecipient(String body) {
    final patterns = [
      RegExp(r'sent to\s+([A-Za-z][^0-9\n\.]{2,30}?)(?:\s+\d{10}|\s+on|\.|$)', caseSensitive: false),
      RegExp(r'paid to\s+([A-Za-z][^0-9\n\.]{2,30}?)(?:\s+\d{10}|\s+on|\.|$)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(body);
      final name = m?.group(1)?.trim();
      if (name != null && name.length > 2) return _titleCase(name);
    }
    return 'M-Pesa Sent';
  }

  /// Extracts paybill business name
  static String _extractPaybillName(String body) {
    final patterns = [
      RegExp(r'Pay Bill to\s+([A-Za-z][^\n\.]{2,40}?)(?:\s+Account|\.|$)', caseSensitive: false),
      RegExp(r'paid to\s+([A-Za-z][^\n\.]{2,40}?)(?:\s+Account|\.|$)', caseSensitive: false),
      RegExp(r'paybill\s+(?:number\s+)?(\d{5,7})', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(body);
      final name = m?.group(1)?.trim();
      if (name != null && name.length > 2) return _titleCase(name);
    }
    return 'Paybill Payment';
  }

  /// Extracts till/merchant name from Buy Goods message
  static String _extractMerchantName(String body) {
    final patterns = [
      RegExp(r'Buy Goods to\s+([A-Za-z][^\n\.]{2,40}?)(?:\s+for|\.|$)', caseSensitive: false),
      RegExp(r'paid to\s+([A-Za-z][^\n\.]{2,40}?)(?:\s+for|\.|$)', caseSensitive: false),
      RegExp(r'Buy Goods and Services\s+([A-Za-z][^\n\.]{2,40}?)(?:\.|$)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(body);
      final name = m?.group(1)?.trim();
      if (name != null && name.length > 2) return _titleCase(name);
    }
    return 'Buy Goods';
  }

  /// Extracts agent name from withdrawal message
  static String _extractAgentName(String body) {
    final m = RegExp(r'(?:from|at)\s+Agent\s+([A-Za-z0-9][^\n\.]{2,30}?)(?:\.|$)', caseSensitive: false).firstMatch(body);
    final name = m?.group(1)?.trim();
    if (name != null && name.length > 2) return 'Withdrawal – $name';
    return 'M-Pesa Withdrawal';
  }

  // ── Category helpers ───────────────────────────────────────────────

  static String _categorizePaybill(String body) {
    final b = body.toLowerCase();
    if (b.contains('kplc') || b.contains('888880') || b.contains('electricity') || b.contains('kenya power')) return 'Electricity';
    if (b.contains('dstv') || b.contains('gotv') || b.contains('showmax') || b.contains('netflix') || b.contains('zuku')) return 'Entertainment';
    if (b.contains('water') || b.contains('nairobi water') || b.contains('nawasco') || b.contains('nwsc')) return 'Water';
    if (b.contains('safaricom') || b.contains('airtel') || b.contains('telkom')) return 'Airtime/Data';
    if (b.contains('school') || b.contains('college') || b.contains('university') || b.contains('fees') || b.contains('tuition')) return 'Education';
    if (b.contains('insurance') || b.contains('britam') || b.contains('jubilee') || b.contains('aar') || b.contains('nhif')) return 'Insurance';
    if (b.contains('rent') || b.contains('landlord') || b.contains('housing')) return 'Rent';
    if (b.contains('hospital') || b.contains('clinic') || b.contains('pharmacy') || b.contains('health')) return 'Health';
    if (b.contains('nssf')) return 'Tax/Deductions';
    return 'Bills';
  }

  static String _categorizeMerchant(String body) {
    final b = body.toLowerCase();
    if (b.contains('naivas') || b.contains('quickmart') || b.contains('carrefour') ||
        b.contains('tuskys') || b.contains('supermarket') || b.contains('game ')) {
      return 'Groceries';
    }
    if (b.contains('kfc') || b.contains('java') || b.contains('restaurant') ||
        b.contains('cafe') || b.contains('food') || b.contains('hotel')) {
      return 'Food & Dining';
    }
    if (b.contains('petrol') || b.contains('fuel') || b.contains('total') ||
        b.contains('shell') || b.contains('kenol') || b.contains('rubis')) {
      return 'Transport';
    }
    if (b.contains('pharmacy') || b.contains('hospital') || b.contains('clinic')) {
      return 'Health';
    }
    if (b.contains('school') || b.contains('college') || b.contains('university')) {
      return 'Education';
    }
    return 'Shopping';
  }

  // ── String helper ──────────────────────────────────────────────────
  static String _titleCase(String s) {
    return s.trim().split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
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

  // ── Balance-driven income/expenditure statement ────────────────────
  /// Builds a month-by-month statement where:
  /// - Opening balance = balanceAfter of the earliest transaction with a known balance
  /// - Unexplained balance increases are treated as income
  /// - Balance can never go negative
  static BalanceStatement buildStatement(List<FinanceTransaction> txs) {
    // Work oldest-first, only include txs that have a recorded balance
    final withBalance = txs.where((t) => t.balanceAfter != null).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (withBalance.isEmpty) {
      return BalanceStatement(months: [], openingBalance: 0);
    }

    final double openingBalance = withBalance.first.balanceAfter!;
    double runningBalance = openingBalance;

    // Group into months
    final Map<String, _MonthAccum> months = {};
    for (final tx in withBalance) {
      final key = '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      months.putIfAbsent(key, () => _MonthAccum(key, runningBalance));

      final accum = months[key]!;
      final actual = tx.balanceAfter!;

      double expected;
      if (tx.isIncome) {
        expected = (runningBalance + tx.amount).clamp(0, double.infinity);
      } else {
        expected = (runningBalance - tx.amount).clamp(0, double.infinity);
      }

      // Unexplained increase = income (e.g. SIM swap, manual top-up, unknown credit)
      final unexplained = (actual - expected).clamp(0, double.infinity);
      if (unexplained > 1) {
        accum.unexplainedIncome += unexplained;
      }

      if (tx.isIncome) {
        accum.income += tx.amount;
      } else {
        accum.expenses += tx.amount;
      }

      accum.closingBalance = actual.clamp(0, double.infinity);
      runningBalance = accum.closingBalance;
    }

    final sortedKeys = months.keys.toList()..sort((a, b) => b.compareTo(a));
    return BalanceStatement(
      months: sortedKeys.map((k) {
        final a = months[k]!;
        return MonthStatement(
          month: k,
          openingBalance: a.openingBalance,
          closingBalance: a.closingBalance,
          income: a.income,
          unexplainedIncome: a.unexplainedIncome,
          expenses: a.expenses,
          // net = closing - opening, never negative
          net: (a.closingBalance - a.openingBalance).clamp(-a.expenses, double.infinity),
        );
      }).toList(),
      openingBalance: openingBalance,
    );
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
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  /// Build a text summary for Nia AI context — uses balance statement
  static String buildNiaContext(List<FinanceTransaction> txs) {
    if (txs.isEmpty) return 'No M-Pesa transaction data available.';

    final stmt = buildStatement(txs);
    final income = stmt.totalIncome;
    final expenses = stmt.totalExpenses;
    final savings = (income - expenses).clamp(0.0, double.infinity);
    final savingsRate = income > 0 ? (savings / income * 100) : 0;
    final categories = expensesByCategory(txs);

    final sb = StringBuffer();
    sb.writeln('USER M-PESA FINANCIAL SUMMARY (last 6 months, balance-based):');
    sb.writeln('Current M-Pesa Balance: KES ${stmt.currentBalance.toStringAsFixed(0)}');
    sb.writeln('Total Income (incl. balance transactions): KES ${income.toStringAsFixed(0)}');
    sb.writeln('Total Expenses: KES ${expenses.toStringAsFixed(0)}');
    sb.writeln('Net Savings: KES ${savings.toStringAsFixed(0)}');
    sb.writeln('Savings Rate: ${savingsRate.toStringAsFixed(1)}%');
    sb.writeln('Total M-Pesa Transactions: ${txs.length}');
    sb.writeln('');
    sb.writeln('TOP EXPENSE CATEGORIES:');
    int i = 0;
    for (final e in categories.entries) {
      if (i++ >= 5) break;
      sb.writeln('  ${e.key}: KES ${e.value.toStringAsFixed(0)}');
    }

    sb.writeln('');
    sb.writeln('MONTHLY BALANCE STATEMENT:');
    for (final m in stmt.months.take(6)) {
      sb.write('  ${m.month} → income KES ${m.totalIncome.toStringAsFixed(0)}, '
          'expenses KES ${m.expenses.toStringAsFixed(0)}, '
          'closing bal KES ${m.closingBalance.toStringAsFixed(0)}');
      if (m.unexplainedIncome > 1) {
        sb.write(' (incl. KES ${m.unexplainedIncome.toStringAsFixed(0)} balance txn)');
      }
      sb.writeln();
    }

    return sb.toString();
  }
}

// ── Balance statement models ───────────────────────────────────────────────

class MonthStatement {
  final String month;
  final double openingBalance;
  final double closingBalance;
  final double income;
  final double unexplainedIncome;
  final double expenses;
  final double net;

  const MonthStatement({
    required this.month,
    required this.openingBalance,
    required this.closingBalance,
    required this.income,
    required this.unexplainedIncome,
    required this.expenses,
    required this.net,
  });

  double get totalIncome => income + unexplainedIncome;
}

class BalanceStatement {
  final List<MonthStatement> months;
  final double openingBalance;

  const BalanceStatement({required this.months, required this.openingBalance});

  double get totalIncome => months.fold(0, (s, m) => s + m.totalIncome);
  double get totalExpenses => months.fold(0, (s, m) => s + m.expenses);
  double get currentBalance => months.isEmpty ? openingBalance : months.first.closingBalance;
}

class _MonthAccum {
  final String key;
  final double openingBalance;
  double income = 0;
  double unexplainedIncome = 0;
  double expenses = 0;
  double closingBalance;

  _MonthAccum(this.key, double opening)
      : openingBalance = opening,
        closingBalance = opening;
}
