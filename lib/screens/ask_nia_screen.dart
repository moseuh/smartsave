import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_theme.dart';
import '../config/api_config.dart';
import '../services/sms_finance_service.dart';

class AskNiaScreen extends StatefulWidget {
  final String userId;
  const AskNiaScreen({super.key, required this.userId});

  @override
  State<AskNiaScreen> createState() => _AskNiaScreenState();
}

class _AskNiaScreenState extends State<AskNiaScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_Message> _messages = [];
  // Full conversation history sent to OpenAI
  final List<Map<String, String>> _history = [];
  bool _isTyping = false;
  bool _loadingData = true;
  List<FinanceTransaction> _transactions = [];
  BalanceStatement? _statement;
  double _walletBalance = 0;
  List<Map<String, dynamic>> _goals = [];

  final List<String> _suggestions = [
    'How much did I spend this month?',
    'What is my savings rate?',
    'Where is most of my money going?',
    'How can I save more money?',
    'Show my income vs expenses',
    'Help me create a budget',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_Message(
      text: "Hi! I'm Nia 🌱 Loading your financial data...",
      isNia: true,
    ));
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    try {
      final granted = await SmsFinanceService.checkPermission();
      if (granted) {
        _transactions = await SmsFinanceService.loadAll();
        _statement = SmsFinanceService.buildStatement(_transactions);
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      if (userId.isNotEmpty) {
        final walletRes = await http.get(Uri.parse(ApiConfig.walletById(userId)));
        if (walletRes.statusCode == 200) {
          final d = jsonDecode(walletRes.body);
          _walletBalance = (d['balance'] ?? d['data']?['balance'] ?? 0).toDouble();
        }
        final goalsRes = await http.get(Uri.parse(ApiConfig.goalsListById(userId)));
        if (goalsRes.statusCode == 200) {
          final d = jsonDecode(goalsRes.body);
          _goals = List<Map<String, dynamic>>.from(d['data'] ?? d['goals'] ?? []);
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _loadingData = false);

    _messages.clear();
    _history.clear();

    final hasData = _transactions.isNotEmpty;
    String greeting;

    if (hasData) {
      final stmt = _statement;
      final income = stmt?.totalIncome ?? SmsFinanceService.totalIncome(_transactions);
      final expenses = stmt?.totalExpenses ?? SmsFinanceService.totalExpenses(_transactions);
      final rate = income > 0 ? ((income - expenses) / income * 100).clamp(0.0, 100.0) : 0.0;

      greeting = "Hey! I'm Nia 🌱 I've gone through your M-Pesa history — **${_transactions.length} transactions** loaded.\n\n"
          "Quick snapshot of the last 6 months:\n"
          "• Income: **KES ${_fmt(income)}**\n"
          "• Spent: **KES ${_fmt(expenses)}**\n"
          "• Nebo wallet: **KES ${_fmt(_walletBalance)}**\n"
          "${_goals.isNotEmpty ? '• Savings goals: **${_goals.length} active**\n' : ''}"
          "• Savings rate: **${rate.toStringAsFixed(1)}%**\n\n"
          "What's on your mind? Ask me anything 💬";
    } else {
      greeting = "Hey! I'm Nia, your personal finance assistant 🌱\n\n"
          "${_walletBalance > 0 ? '💳 Nebo wallet: **KES ${_fmt(_walletBalance)}**\n\n' : ''}"
          "I don't have your M-Pesa data yet — head to the Expenditure screen to grant SMS access so I can really dig into your finances.\n\n"
          "But I'm still here! Ask me anything about budgeting, saving, or managing money.";
    }

    _messages.add(_Message(text: greeting, isNia: true));
    // Seed OpenAI history with the greeting
    _history.add({'role': 'assistant', 'content': greeting});

    setState(() {});
  }

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _buildSystemPrompt() {
    final now = DateTime.now();
    final sb = StringBuffer();

    sb.writeln('You are Nia, a warm, smart, deeply human personal financial assistant inside the Nebo SmartSave app (Kenya).');
    sb.writeln('');
    sb.writeln('Your personality:');
    sb.writeln('- Talk like a smart friend who knows finance deeply — never robotic, never corporate');
    sb.writeln('- Read context fully: if someone greets you ("hi", "hey", "good morning") respond warmly like a human would, don\'t jump straight into finance');
    sb.writeln('- If someone says "how are you" — answer naturally, then offer to help');
    sb.writeln('- You naturally use casual Kenyan English — you know M-Pesa, Fuliza, Paybill, NHIF, NSSF, KCB, Equity, Safaricom, Hustler Fund');
    sb.writeln('- Be empathetic: if someone sounds stressed about money, acknowledge it before giving advice');
    sb.writeln('- Use light emojis naturally (not after every sentence)');
    sb.writeln('- Keep answers concise — max 3-4 short paragraphs unless doing a detailed breakdown');
    sb.writeln('- NEVER say "As an AI language model" or "I cannot" — just help or ask a clarifying question');
    sb.writeln('- Always quote amounts in KES');
    sb.writeln('- When you have the user\'s real data, use it — don\'t give generic advice when you can be specific');
    sb.writeln('- If you\'re asked to do something unrelated to finance (like write code), gently steer back: "That\'s a bit outside my lane 😄 I\'m your finance brain — what money question can I help with?"');
    sb.writeln('');
    sb.writeln('Today: ${now.day}/${now.month}/${now.year}');
    sb.writeln('');
    sb.writeln('--- USER\'S FINANCIAL DATA ---');
    sb.writeln('Nebo wallet balance: KES ${_walletBalance.toStringAsFixed(0)}');

    if (_goals.isNotEmpty) {
      sb.writeln('');
      sb.writeln('Savings goals:');
      for (final g in _goals) {
        final name = g['goal_name'] ?? g['name'] ?? 'Goal';
        final current = (g['current_amount'] ?? 0).toDouble();
        final target = (g['target_amount'] ?? 0).toDouble();
        final pct = target > 0 ? (current / target * 100).clamp(0, 100) : 0;
        sb.writeln('  - $name: KES ${current.toStringAsFixed(0)} of KES ${target.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}% funded)');
      }
    }

    if (_transactions.isEmpty) {
      sb.writeln('');
      sb.writeln('M-Pesa data: Not available (SMS permission not granted yet)');
    } else {
      final stmt = _statement;
      final income6m = stmt?.totalIncome ?? SmsFinanceService.totalIncome(_transactions);
      final expenses6m = stmt?.totalExpenses ?? SmsFinanceService.totalExpenses(_transactions);
      final mpesaBalance = stmt?.currentBalance ?? 0;
      final savings6m = (income6m - expenses6m).clamp(0.0, double.infinity);
      final rate6m = income6m > 0 ? (savings6m / income6m * 100) : 0.0;

      sb.writeln('');
      sb.writeln('M-Pesa summary (last 6 months, ${_transactions.length} transactions):');
      sb.writeln('  - Current M-Pesa balance: KES ${mpesaBalance.toStringAsFixed(0)}');
      sb.writeln('  - Total income: KES ${income6m.toStringAsFixed(0)}');
      sb.writeln('  - Total expenses: KES ${expenses6m.toStringAsFixed(0)}');
      sb.writeln('  - Net saved: KES ${savings6m.toStringAsFixed(0)}');
      sb.writeln('  - Savings rate: ${rate6m.toStringAsFixed(1)}%');
      sb.writeln('  - Monthly avg income: KES ${(income6m / 6).toStringAsFixed(0)}');
      sb.writeln('  - Monthly avg expenses: KES ${(expenses6m / 6).toStringAsFixed(0)}');

      final thisMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final thisMonthStmt = stmt?.months.where((m) => m.month == thisMonthKey).firstOrNull;
      if (thisMonthStmt != null) {
        sb.writeln('');
        sb.writeln('This month (${now.month}/${now.year}):');
        sb.writeln('  - Income: KES ${thisMonthStmt.totalIncome.toStringAsFixed(0)}');
        sb.writeln('  - Expenses: KES ${thisMonthStmt.expenses.toStringAsFixed(0)}');
        sb.writeln('  - Closing balance: KES ${thisMonthStmt.closingBalance.toStringAsFixed(0)}');
      }

      final cats = SmsFinanceService.expensesByCategory(_transactions);
      if (cats.isNotEmpty) {
        sb.writeln('');
        sb.writeln('Top spending categories (6 months):');
        for (final e in cats.entries.take(6)) {
          sb.writeln('  - ${e.key}: KES ${e.value.toStringAsFixed(0)}');
        }
      }

      if (stmt != null && stmt.months.isNotEmpty) {
        sb.writeln('');
        sb.writeln('Monthly trend (most recent first):');
        for (final m in stmt.months.take(6)) {
          sb.writeln('  - ${m.month}: income KES ${m.totalIncome.toStringAsFixed(0)}, expenses KES ${m.expenses.toStringAsFixed(0)}, balance KES ${m.closingBalance.toStringAsFixed(0)}');
        }
      }
    }

    return sb.toString();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    final userText = text.trim();
    setState(() {
      _messages.add(_Message(text: userText, isNia: false));
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    _history.add({'role': 'user', 'content': userText});

    final reply = await _askOpenAI();
    if (!mounted) return;

    _history.add({'role': 'assistant', 'content': reply});

    setState(() {
      _isTyping = false;
      _messages.add(_Message(text: reply, isNia: true));
    });
    _scrollToBottom();
  }

  Future<String> _askOpenAI() async {
    // Keep last 20 messages to stay within token limits
    final trimmedHistory = _history.length > 20
        ? _history.sublist(_history.length - 20)
        : List<Map<String, String>>.from(_history);

    http.Response? res;
    String? errorDetail;

    try {
      res = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${ApiConfig.openAiApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'max_tokens': 600,
          'temperature': 0.85,
          'messages': [
            {'role': 'system', 'content': _buildSystemPrompt()},
            ...trimmedHistory,
          ],
        }),
      ).timeout(const Duration(seconds: 30));
    } catch (e) {
      errorDetail = e.toString();
    }

    if (res != null && res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final reply = data['choices']?[0]?['message']?['content']?.toString().trim();
      if (reply != null && reply.isNotEmpty) return reply;
    }

    // Show the actual error to help diagnose, then fall through
    final lastMsg = _history.last['content'] ?? '';
    if (errorDetail != null) {
      // Network/timeout — use smart local fallback
      return _localFallback(lastMsg);
    }
    if (res != null && res.statusCode != 200) {
      // API returned an error — parse it
      try {
        final errBody = jsonDecode(res.body);
        final errMsg = errBody['error']?['message']?.toString() ?? 'API error ${res.statusCode}';
        // Don't expose raw API errors to user — use smart fallback
        debugPrint('[Nia OpenAI error] $errMsg');
      } catch (_) {}
    }
    return _localFallback(lastMsg);
  }

  /// Smart fallback used when OpenAI is unreachable
  String _localFallback(String input) {
    final q = input.toLowerCase().trim();

    // ── Greetings & small talk ─────────────────────────────────────
    if (RegExp(r'^(hi|hey|hello|hii|helo|sup|wassup|howdy|yo|morning|good morning|good evening|evening|afternoon)').hasMatch(q)) {
      return "Hey! 👋 Great to hear from you. What's on your mind?";
    }
    if (q.contains('how are you') || q.contains('how r u') || q.contains('hows nia') || q == 'hows it going') {
      return "Doing well, thanks for asking! 😄 Ready to help with your finances. What do you need?";
    }
    if (q == 'thanks' || q == 'thank you' || q.startsWith('thank')) {
      return "Anytime! 😊 Let me know if there's anything else.";
    }
    if (q.contains('who are you') || q.contains('what are you') || q.contains('what is nia')) {
      return "I'm Nia — your personal finance assistant inside Nebo. I can read your M-Pesa history, track your spending, help you save smarter, and answer any money questions you have. What would you like to know?";
    }

    // ── Finance questions ──────────────────────────────────────────
    final stmt = _statement;
    final income = stmt?.totalIncome ?? SmsFinanceService.totalIncome(_transactions);
    final expenses = stmt?.totalExpenses ?? SmsFinanceService.totalExpenses(_transactions);
    final balance = stmt?.currentBalance ?? 0.0;
    final savings = (income - expenses).clamp(0.0, double.infinity);
    final rate = income > 0 ? (savings / income * 100) : 0.0;

    if (q.contains('wallet') || q.contains('nebo balance')) {
      return "💳 Your Nebo wallet: **KES ${_fmt(_walletBalance)}**";
    }
    if (q.contains('balance')) {
      return "📱 M-Pesa balance: **KES ${_fmt(balance)}**\n💳 Nebo wallet: **KES ${_fmt(_walletBalance)}**";
    }
    if (q.contains('goal')) {
      if (_goals.isEmpty) return "You don't have any savings goals yet. Tap the Savings tab to create one!";
      final list = _goals.map((g) {
        final name = g['goal_name'] ?? g['name'] ?? 'Goal';
        final cur = (g['current_amount'] ?? 0).toDouble();
        final tar = (g['target_amount'] ?? 0).toDouble();
        return '• $name: KES ${_fmt(cur)} / KES ${_fmt(tar)}';
      }).join('\n');
      return "Your savings goals:\n\n$list";
    }
    if (q.contains('spend') || q.contains('expens') || q.contains('where') && q.contains('money')) {
      if (_transactions.isEmpty) return "I don't have your M-Pesa data yet. Grant SMS permission in the Expenditure screen so I can see your spending!";
      final cats = SmsFinanceService.expensesByCategory(_transactions);
      final top = cats.entries.take(3).map((e) => '• ${e.key}: KES ${_fmt(e.value)}').join('\n');
      return "Your top spending categories (last 6 months):\n\n$top\n\nTotal spent: **KES ${_fmt(expenses)}**";
    }
    if (q.contains('income') || q.contains('earn') || q.contains('salary')) {
      if (_transactions.isEmpty) return "Grant SMS permission in the Expenditure screen so I can analyse your income!";
      return "📥 6-month income: **KES ${_fmt(income)}**\nMonthly average: **KES ${_fmt(income / 6)}**";
    }
    if (q.contains('sav') || q.contains('rate')) {
      if (_transactions.isEmpty) return "I need your M-Pesa data to calculate your savings rate. Head to Finance → Expenditure to grant access.";
      final tip = rate >= 20
          ? '🎉 You\'re saving ${rate.toStringAsFixed(1)}% — that\'s above the 20% benchmark. Keep it up!'
          : '🎯 You\'re saving ${rate.toStringAsFixed(1)}%. The goal is 20% — that\'s about KES ${_fmt(income * 0.20 / 6)} more saved per month.';
      return "💰 Net saved (6 months): **KES ${_fmt(savings)}**\n\n$tip";
    }

    // ── Generic fallback — no stats dump ─────────────────────────
    return "I'm having a bit of trouble connecting right now. Try again in a moment, or ask me something specific like your balance, spending, or savings goals!";
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.financeGreen, shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ask Nia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  _loadingData ? 'Loading your data...' : '${_transactions.length} transactions loaded',
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!_loadingData && _transactions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
              onPressed: () async {
                await SmsFinanceService.clearCache();
                setState(() {
                  _loadingData = true;
                  _transactions = [];
                  _history.clear();
                  _messages.clear();
                  _messages.add(_Message(text: "Refreshing your financial data...", isNia: true));
                });
                await _loadFinancialData();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (_loadingData)
            LinearProgressIndicator(
              backgroundColor: AppColors.financeGreenV3.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(AppColors.financeGreenV3),
            ),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) return _TypingIndicator();
                return _MessageBubble(message: _messages[index]);
              },
            ),
          ),

          // Suggestions shown only before first user message
          if (_messages.length <= 1 && !_loadingData)
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _suggestions.length,
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => _send(_suggestions[i]),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.financeGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.financeGreenV3.withValues(alpha: 0.3)),
                    ),
                    child: Text(_suggestions[i],
                        style: TextStyle(color: AppColors.financeGreen, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Input bar
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12,
                MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      controller: _controller,
                      onSubmitted: _send,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                      decoration: const InputDecoration(
                        hintText: 'Ask Nia about your finances...',
                        hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _send(_controller.text),
                  child: Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1B6631), Color(0xFF6BB046)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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

class _Message {
  final String text;
  final bool isNia;
  _Message({required this.text, required this.isNia});
}

class _MessageBubble extends StatelessWidget {
  final _Message message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isNia ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (message.isNia) ...[
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(color: AppColors.financeGreen, shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: message.isNia ? Colors.white : AppColors.financeGreen,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(message.isNia ? 4 : 18),
                  bottomRight: Radius.circular(message.isNia ? 18 : 4),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: _renderText(message.text, message.isNia),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderText(String text, bool isNia) {
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          fontWeight: i.isOdd ? FontWeight.bold : FontWeight.normal,
          color: isNia ? const Color(0xFF111827) : Colors.white,
          fontSize: 13.5,
          height: 1.5,
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(color: AppColors.financeGreen, shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
            ),
            child: const Text('Nia is thinking...', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }
}
