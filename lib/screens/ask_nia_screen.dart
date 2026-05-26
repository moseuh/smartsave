import 'package:flutter/material.dart';
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

  void _send(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_Message(text: text.trim(), isNia: false));
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(_Message(text: _respond(text.trim()), isNia: true));
      });
      _scrollToBottom();
    });
  }

  String _respond(String input) {
    final q = input.toLowerCase();

    // Data-driven responses if we have transactions
    if (_transactions.isNotEmpty) {
      if (q.contains('spend') || q.contains('spent') || q.contains('expenses') || q.contains('expenditure')) {
        return _spendingResponse();
      }
      if (q.contains('income') || q.contains('earn') || q.contains('salary') || q.contains('receive')) {
        return _incomeResponse();
      }
      if (q.contains('saving') || q.contains('savings') || q.contains('save') || q.contains('rate')) {
        return _savingsResponse();
      }
      if (q.contains('budget') || q.contains('plan')) {
        return _budgetResponse();
      }
      if (q.contains('category') || q.contains('categories') || q.contains('most') || q.contains('top')) {
        return _categoryResponse();
      }
      if (q.contains('month') || q.contains('trend') || q.contains('history') || q.contains('pattern')) {
        return _trendResponse();
      }
      if (q.contains('mpesa') || q.contains('m-pesa')) {
        return _mpesaResponse();
      }
      if (q.contains('goal') || q.contains('target')) {
        return _goalResponse();
      }
    }

    // Generic responses
    if (q.contains('save') || q.contains('saving')) {
      return "Great question! Here are 3 quick wins:\n\n1. **Round-ups** — every M-Pesa transaction, we round up and save the change automatically.\n2. **Set a goal** — users with a savings goal save 3x more on average.\n3. **50/30/20 rule** — 50% needs, 30% wants, 20% savings.\n\nWant me to analyse your actual spending to find where you can cut back?";
    }
    if (q.contains('budget')) {
      return "A budget is just telling your money where to go before it disappears 😄\n\nCheck the **Finance Manager** tab — it shows your income vs expenses and a 50/30/20 budget breakdown based on your actual M-Pesa and bank transactions.";
    }
    if (q.contains('credit') || q.contains('score')) {
      return "Your credit score here is powered by 1,800+ data points including:\n\n• Savings consistency\n• Loan repayment history\n• M-Pesa transaction patterns\n\nThe best way to improve it? Save regularly and repay loans on time.";
    }
    if (q.contains('loan') || q.contains('borrow')) {
      return "Before taking a loan, ask yourself:\n\n1. Is this for an income-generating asset?\n2. Can I repay within the tenure?\n3. Is the interest manageable?\n\nCheck the Loans tab for your eligibility based on your transaction history.";
    }
    return "That's a great topic! Based on your financial data, I'd suggest:\n\n• Review your spending in the Finance Manager\n• Check if you're hitting your 20% savings target\n• Set a specific savings goal in the Goals tab\n\nWhat specific area would you like help with?";
  }

  String _spendingResponse() {
    final now = DateTime.now();
    final thisMonth = _transactions.where((t) =>
        !t.isIncome && t.date.year == now.year && t.date.month == now.month).toList();
    final total = SmsFinanceService.totalExpenses(thisMonth);
    final cats = SmsFinanceService.expensesByCategory(thisMonth);
    final top = cats.entries.take(3).map((e) => '  • ${e.key}: KES ${_fmt(e.value)}').join('\n');

    return "This month's spending so far:\n\n"
        "💸 Total: **KES ${_fmt(total)}** across ${thisMonth.length} transactions\n\n"
        "Top categories:\n$top\n\n"
        "${_spendingTip(cats)}";
  }

  String _spendingTip(Map<String, double> cats) {
    if (cats.isEmpty) return "No categorised expenses found yet.";
    final top = cats.entries.first;
    return "💡 Your biggest spend is **${top.key}** at KES ${_fmt(top.value)}. Want tips on reducing this?";
  }

  String _incomeResponse() {
    final now = DateTime.now();
    final thisMonth = _transactions.where((t) =>
        t.isIncome && t.date.year == now.year && t.date.month == now.month).toList();
    final total = SmsFinanceService.totalIncome(thisMonth);
    final allIncome = SmsFinanceService.totalIncome(_transactions);
    final avgMonthly = allIncome / 6;

    return "Your income summary:\n\n"
        "📥 This month: **KES ${_fmt(total)}** (${thisMonth.length} transactions)\n"
        "📊 6-month total: KES ${_fmt(allIncome)}\n"
        "📈 Monthly average: KES ${_fmt(avgMonthly)}\n\n"
        "${total >= avgMonthly ? '🎉 Great — you\'re above your monthly average!' : '📉 This month is below your usual income. Any irregular month?'}";
  }

  String _savingsResponse() {
    final income = SmsFinanceService.totalIncome(_transactions);
    final expenses = SmsFinanceService.totalExpenses(_transactions);
    final savings = income - expenses;
    final rate = income > 0 ? (savings / income * 100) : 0;

    String advice;
    if (rate >= 20) {
      advice = "🎉 Excellent! You're hitting the recommended 20% savings rate. Keep it up!";
    } else if (rate >= 10) {
      advice = "👍 Good start! To hit 20%, try cutting KES ${_fmt((income * 0.20) - savings)} more per month.";
    } else if (rate > 0) {
      advice = "⚠️ Your savings rate is low. Target is 20% — that's KES ${_fmt(income * 0.20)} per month.";
    } else {
      advice = "🚨 You're spending more than you earn. Let's find where to cut back.";
    }

    return "Your 6-month savings picture:\n\n"
        "💰 Total income: KES ${_fmt(income)}\n"
        "💸 Total expenses: KES ${_fmt(expenses)}\n"
        "✅ Net saved: KES ${_fmt(savings)}\n"
        "📊 Savings rate: **${rate.toStringAsFixed(1)}%**\n\n"
        "$advice";
  }

  String _budgetResponse() {
    final income = SmsFinanceService.totalIncome(_transactions);
    final monthly = income / 6;
    final needs = monthly * 0.50;
    final wants = monthly * 0.30;
    final savingsTarget = monthly * 0.20;

    return "Based on your average monthly income of **KES ${_fmt(monthly)}**, here's your ideal 50/30/20 budget:\n\n"
        "🏠 Needs (50%): KES ${_fmt(needs)}\n"
        "   Rent, food, transport, utilities, health\n\n"
        "🎬 Wants (30%): KES ${_fmt(wants)}\n"
        "   Entertainment, dining out, shopping\n\n"
        "💰 Savings (20%): KES ${_fmt(savingsTarget)}\n"
        "   Emergency fund, goals, investments\n\n"
        "Open the **Finance Manager → Budgets** tab to see how you're tracking against this!";
  }

  String _categoryResponse() {
    final cats = SmsFinanceService.expensesByCategory(_transactions);
    if (cats.isEmpty) return "No expense categories found in your SMS data yet.";
    final top5 = cats.entries.take(5).map((e) => '  ${cats.keys.toList().indexOf(e.key) + 1}. ${e.key}: KES ${_fmt(e.value)}').join('\n');
    return "Your top spending categories (last 6 months):\n\n$top5\n\n"
        "💡 Tip: The 50/30/20 rule suggests keeping wants (entertainment, dining, shopping) under 30% of income.";
  }

  String _trendResponse() {
    final byMonth = SmsFinanceService.groupByMonth(_transactions);
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    final lines = months.take(4).map((m) {
      final mTxs = byMonth[m]!;
      final inc = SmsFinanceService.totalIncome(mTxs);
      final exp = SmsFinanceService.totalExpenses(mTxs);
      return '  $m → Saved: KES ${_fmt(inc - exp)}';
    }).join('\n');
    return "Your recent monthly savings trend:\n\n$lines\n\nOpen the Finance Manager for the full 6-month breakdown with charts.";
  }

  String _mpesaResponse() {
    final mpesa = _transactions.where((t) => t.source == 'M-Pesa').toList();
    final income = SmsFinanceService.totalIncome(mpesa);
    final expenses = SmsFinanceService.totalExpenses(mpesa);
    return "Your M-Pesa activity (last 6 months):\n\n"
        "📲 Total M-Pesa transactions: ${mpesa.length}\n"
        "📥 Money received: KES ${_fmt(income)}\n"
        "📤 Money sent/paid: KES ${_fmt(expenses)}\n\n"
        "M-Pesa is your ${income > expenses ? 'main income channel 💪' : 'main spending channel — make sure to top up your savings too!'}";
  }

  String _goalResponse() {
    final income = SmsFinanceService.totalIncome(_transactions);
    final monthly = income / 6;
    final savingsTarget = monthly * 0.20;
    return "Setting goals is powerful! Research shows people with specific savings goals are 42% more likely to save.\n\n"
        "Based on your income, you could save **KES ${_fmt(savingsTarget)}** per month (20% rule).\n\n"
        "🎯 Go to Goals → tap + → give it a name, target amount, and deadline. We track progress automatically!\n\n"
        "Some popular goals:\n• Emergency fund (3 months expenses)\n• Rent deposit\n• Business capital\n• Education fees";
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
        backgroundColor: AppColors.financeGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.financeGreenV3, shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ask Nia', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  _loadingData ? 'Loading your data...' : '${_transactions.length} transactions loaded',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
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
            padding: EdgeInsets.fromLTRB(12, 8, 12, 16 + MediaQuery.of(context).viewInsets.bottom),
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
