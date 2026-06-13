import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants/app_theme.dart';
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
  bool _isTyping = false;
  bool _loadingData = true;
  List<FinanceTransaction> _transactions = [];

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
      text: "Hi! I'm Nia 🌱 Loading your financial data from M-Pesa and bank SMS...",
      isNia: true,
    ));
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    try {
      final granted = await SmsFinanceService.checkPermission();
      if (granted) {
        _transactions = await SmsFinanceService.loadAll();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _loadingData = false);

    // Replace loading message with real greeting
    final hasData = _transactions.isNotEmpty;
    _messages.clear();

    if (hasData) {
      final income = SmsFinanceService.totalIncome(_transactions);
      final expenses = SmsFinanceService.totalExpenses(_transactions);
      final savings = income - expenses;
      final rate = income > 0 ? (savings / income * 100) : 0;

      _messages.add(_Message(
        text: "Hi! I'm Nia, your personal financial assistant 🌱\n\n"
            "I've loaded **${_transactions.length} transactions** from your M-Pesa and bank SMS (last 6 months).\n\n"
            "📊 Quick snapshot:\n"
            "• Income: KES ${_fmt(income)}\n"
            "• Expenses: KES ${_fmt(expenses)}\n"
            "• Net savings: KES ${_fmt(savings)} (${rate.toStringAsFixed(1)}%)\n\n"
            "Ask me anything about your finances!",
        isNia: true,
      ));
    } else {
      _messages.add(_Message(
        text: "Hi! I'm Nia, your personal financial assistant 🌱\n\n"
            "I couldn't read your SMS messages yet. Grant SMS permission in the Expenditure screen so I can analyse your M-Pesa and bank transactions.\n\n"
            "I can still help with budgeting tips, savings advice, and financial planning!",
        isNia: true,
      ));
    }
    setState(() {});
  }

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  /// Build a rich financial context string from the user's SMS transactions
  String _buildFinancialContext() {
    if (_transactions.isEmpty) return 'No transaction data available yet.';

    final now = DateTime.now();
    final thisMonth = _transactions.where(
        (t) => t.date.year == now.year && t.date.month == now.month).toList();
    final income6m = SmsFinanceService.totalIncome(_transactions);
    final expenses6m = SmsFinanceService.totalExpenses(_transactions);
    final savings6m = income6m - expenses6m;
    final rate6m = income6m > 0 ? (savings6m / income6m * 100) : 0;
    final avgMonthly = income6m / 6;

    final incomeThisMonth = SmsFinanceService.totalIncome(thisMonth);
    final expensesThisMonth = SmsFinanceService.totalExpenses(thisMonth);

    final cats = SmsFinanceService.expensesByCategory(_transactions);
    final topCats = cats.entries.take(5)
        .map((e) => '  - ${e.key}: KES ${e.value.toStringAsFixed(0)}')
        .join('\n');

    final byMonth = SmsFinanceService.groupByMonth(_transactions);
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    final monthlyTrend = months.take(4).map((m) {
      final mTxs = byMonth[m]!;
      final inc = SmsFinanceService.totalIncome(mTxs);
      final exp = SmsFinanceService.totalExpenses(mTxs);
      return '  - $m: income KES ${inc.toStringAsFixed(0)}, expenses KES ${exp.toStringAsFixed(0)}, net KES ${(inc - exp).toStringAsFixed(0)}';
    }).join('\n');

    return '''
User Financial Summary (last 6 months, from M-Pesa SMS):
- Total transactions parsed: ${_transactions.length}
- Total income: KES ${income6m.toStringAsFixed(0)}
- Total expenses: KES ${expenses6m.toStringAsFixed(0)}
- Net savings: KES ${savings6m.toStringAsFixed(0)}
- Savings rate: ${rate6m.toStringAsFixed(1)}%
- Average monthly income: KES ${avgMonthly.toStringAsFixed(0)}

This month (${now.month}/${now.year}):
- Income: KES ${incomeThisMonth.toStringAsFixed(0)}
- Expenses: KES ${expensesThisMonth.toStringAsFixed(0)}

Top spending categories (6 months):
$topCats

Monthly trend (most recent first):
$monthlyTrend
''';
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_Message(text: text.trim(), isNia: false));
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    final reply = await _askClaude(text.trim());
    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add(_Message(text: reply, isNia: true));
    });
    _scrollToBottom();
  }

  Future<String> _askClaude(String userMessage) async {
    const apiKey = 'YOUR_ANTHROPIC_API_KEY'; // Replace with env/config
    const model = 'claude-haiku-4-5-20251001';

    final systemPrompt = '''You are Nia, a warm, smart personal financial assistant built into the Nebo SmartSave app — a Kenyan mobile savings and finance app. You help users understand their M-Pesa spending, improve savings habits, and make better financial decisions.

Rules:
- Always be concise, friendly, and practical
- Use KES (Kenyan Shillings) for all money amounts
- Reference the user's actual data when available — don't make up numbers
- Use emojis sparingly but warmly
- Keep answers under 200 words unless doing a detailed breakdown
- If data is unavailable, still give useful general advice
- You know about M-Pesa, Fuliza, Paybill, Buy Goods, NHIF, NSSF, and Kenyan financial norms

${_buildFinancialContext()}''';

    try {
      final res = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 512,
          'system': systemPrompt,
          'messages': [
            // Include recent conversation history for context
            ..._messages.skip(_messages.length > 6 ? _messages.length - 6 : 0).map((m) => {
              'role': m.isNia ? 'assistant' : 'user',
              'content': m.text,
            }),
            {'role': 'user', 'content': userMessage},
          ],
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['content']?[0]?['text']?.toString() ??
            'Sorry, I had trouble responding. Please try again.';
      } else {
        // Fallback to local smart response on API error
        return _localFallback(userMessage);
      }
    } catch (_) {
      return _localFallback(userMessage);
    }
  }

  /// Fallback when API is unreachable — still uses real SMS data
  String _localFallback(String input) {
    final q = input.toLowerCase();
    if (_transactions.isEmpty) {
      return "I need your M-Pesa SMS data to give you personalised advice. Grant SMS permission in the Finance → Expenditure screen, then come back!";
    }
    final income = SmsFinanceService.totalIncome(_transactions);
    final expenses = SmsFinanceService.totalExpenses(_transactions);
    final savings = income - expenses;
    final rate = income > 0 ? (savings / income * 100) : 0;

    if (q.contains('spend') || q.contains('expens')) {
      final cats = SmsFinanceService.expensesByCategory(_transactions);
      final top = cats.entries.take(3).map((e) => '• ${e.key}: KES ${_fmt(e.value)}').join('\n');
      return "Your top expenses (6 months):\n\n$top\n\nTotal spent: KES ${_fmt(expenses)}";
    }
    if (q.contains('income') || q.contains('earn')) {
      return "📥 6-month income: KES ${_fmt(income)}\n📈 Monthly avg: KES ${_fmt(income / 6)}";
    }
    if (q.contains('sav')) {
      return "💰 Net saved (6 months): KES ${_fmt(savings)}\n📊 Savings rate: ${rate.toStringAsFixed(1)}%\n\n${rate >= 20 ? '🎉 Great job hitting 20%+!' : '🎯 Target is 20% — you need KES ${_fmt(income * 0.20 / 6)} more saved per month.'}";
    }
    return "Based on your data: income KES ${_fmt(income / 6)}/month, expenses KES ${_fmt(expenses / 6)}/month, savings rate ${rate.toStringAsFixed(1)}%. What would you like to explore?";
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

          // Suggestions
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
            padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16),
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
    // Simple bold renderer for **text**
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
