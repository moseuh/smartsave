import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../config/api_config.dart';
import '../services/tab_refresh_registry.dart';
import '../utils/validation_utils.dart';
import 'goals_dashboard.dart';
import 'roundup.dart';
import 'SetSavingsGoalScreen.dart' show GoalCreationScreen;
import 'LeaderboardPage.dart';

class SaveTab extends StatefulWidget {
  final String userId;
  const SaveTab({super.key, required this.userId});

  @override
  State<SaveTab> createState() => _SaveTabState();
}

class _SaveTabState extends State<SaveTab> {
  Map<String, dynamic>? _savings;
  List<Map<String, dynamic>> _goals = [];
  bool _loading = true;
  final fmt = NumberFormat('#,##0.00');

  void refresh() => _load();

  @override
  void initState() {
    super.initState();
    TabRefreshRegistry.register(1, refresh);
    _load();
  }

  @override
  void dispose() {
    TabRefreshRegistry.unregister(1);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.wait([_fetchSavings(), _fetchGoals()]);
    setState(() => _loading = false);
  }

  Future<void> _fetchSavings() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.userSavingsById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') setState(() => _savings = d['data']);
      }
    } catch (_) {}
  }

  Future<void> _fetchGoals() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.goalsListById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') {
          setState(() => _goals = List<Map<String, dynamic>>.from(d['data'] ?? []));
        }
      }
    } catch (_) {}
  }

  double get _totalSaved => double.tryParse(_savings?['total_saved']?.toString() ?? '0') ?? 0;
  double get _monthSaved => double.tryParse(_savings?['month_saved']?.toString() ?? '0') ?? 0;
  double get _roundupTotal => double.tryParse(_savings?['roundup_total']?.toString() ?? '0') ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: RefreshIndicator(
        color: AppColors.financeGreenV3,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── White hero header ─────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: AppTheme.backgroundLight,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              expandedHeight: 170,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  color: AppTheme.backgroundLight,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Savings',
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Build your wealth, step by step',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                _HeaderStat('Total Saved', _loading ? '…' : 'KES ${fmt.format(_totalSaved)}'),
                                _HeaderStat('This Month', _loading ? '…' : 'KES ${fmt.format(_monthSaved)}'),
                                _HeaderStat('Round-ups', _loading ? '…' : 'KES ${fmt.format(_roundupTotal)}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: AppColors.coreWhiteW2),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Quick actions row
                  Row(
                    children: [
                      Expanded(child: _ActionCard(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'New Goal',
                        color: AppColors.financeGreen,
                        onTap: () => Navigator.push(context, _slide(GoalCreationScreen(userId: widget.userId))),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _ActionCard(
                        icon: Icons.loop_rounded,
                        label: 'Round-ups',
                        color: AppColors.financeGreenV2,
                        onTap: () => Navigator.push(context, _slide(const RoundUpSettings())),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _ActionCard(
                        icon: Icons.emoji_events_rounded,
                        label: 'Leaderboard',
                        color: const Color(0xFFF5A623),
                        onTap: () => Navigator.push(context, _slide(LeaderboardPage(userId: widget.userId))),
                      )),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Goals section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('My Goals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      GestureDetector(
                        onTap: () => Navigator.push(context, _slide(GoalsDashboard(userId: widget.userId))),
                        child: const Text('See all', style: TextStyle(fontSize: 13, color: AppColors.financeGreenV3, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_loading)
                    ...List.generate(2, (_) => const Padding(padding: EdgeInsets.only(bottom: 12), child: _Skeleton(height: 100)))
                  else if (_goals.isEmpty)
                    _EmptyGoals(onTap: () => Navigator.push(context, _slide(GoalCreationScreen(userId: widget.userId))))
                  else
                    ..._goals.map((g) => _GoalCard(goal: g, fmt: fmt, userId: widget.userId, onRefresh: _load)),

                  const SizedBox(height: 24),

                  // Savings tips
                  const Text('Smart Saving Tips', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 12),
                  const _TipCard(
                    icon: Icons.loop_rounded,
                    title: 'Enable Round-ups',
                    body: 'Every M-Pesa transaction rounds up to the nearest 10 — small amounts that add up fast.',
                    color: Color(0xFF059669),
                  ),
                  const SizedBox(height: 10),
                  const _TipCard(
                    icon: Icons.calendar_today_rounded,
                    title: '50/30/20 Rule',
                    body: 'Allocate 50% needs, 30% wants, 20% savings every month.',
                    color: AppColors.financeGreenV3,
                  ),
                  const SizedBox(height: 10),
                  const _TipCard(
                    icon: Icons.emoji_events_rounded,
                    title: 'Join Challenges',
                    body: 'Compete with others on the leaderboard and stay motivated to save.',
                    color: Color(0xFFF5A623),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
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
}

// ── _HeaderStat — dark text for light background ──────────────────────────────
class _HeaderStat extends StatelessWidget {
  final String label, value;
  const _HeaderStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
}

// ── _ActionCard — solid color, tall, icon in frosted circle ──────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _GoalCard ─────────────────────────────────────────────────────────────────
class _GoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  final NumberFormat fmt;
  final String userId;
  final VoidCallback onRefresh;
  const _GoalCard({required this.goal, required this.fmt, required this.userId, required this.onRefresh});

  void _showContribute(BuildContext context) {
    final goalId = goal['id'] ?? goal['goal_id'];
    final name = goal['goal_name'] ?? goal['name'] ?? 'Goal';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalContributeSheet(
        userId: userId,
        goalId: goalId?.toString() ?? '',
        goalName: name.toString(),
        onSuccess: onRefresh,
      ),
    );
  }

  void _showHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GoalHistoryScreen(goal: goal)),
    ).then((_) => onRefresh());
  }

  void _showOptions(BuildContext context) {
    final isDefault = goal['is_default'] == true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(ctx).padding.bottom + 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.edit_rounded, color: AppColors.financeGreen),
            title: const Text('Edit Goal', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              _showEdit(context);
            },
          ),
          if (!isDefault)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
              title: const Text('Delete Goal', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
              subtitle: const Text('Balance moves to Savings Wallet', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context);
              },
            ),
        ]),
      ),
    );
  }

  void _showEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalEditSheet(goal: goal, userId: userId, onSuccess: onRefresh),
    );
  }

  void _confirmDelete(BuildContext context) {
    final saved = double.tryParse((goal['current_amount'] ?? 0).toString()) ?? 0;
    final name = goal['goal_name'] ?? goal['title'] ?? 'Goal';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Goal?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          saved > 0
              ? 'KES ${NumberFormat('#,##0').format(saved)} from "$name" will move to your Savings Wallet.'
              : 'Are you sure you want to delete "$name"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteGoal(context);
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGoal(BuildContext context) async {
    final goalId = goal['id']?.toString() ?? '';
    try {
      final r = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/goalsdelete/$goalId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': int.tryParse(userId) ?? userId}),
      );
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['status'] == 'success') {
        onRefresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(data['message'] ?? 'Goal deleted'),
            backgroundColor: AppColors.financeGreen,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(data['message'] ?? 'Delete failed'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final saved = double.tryParse((goal['current_amount'] ?? goal['saved_amount'] ?? 0).toString()) ?? 0;
    final target = double.tryParse((goal['goal_amount'] ?? goal['target_amount'] ?? 1).toString()) ?? 1;
    final pct = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;
    final name = goal['goal_name'] ?? goal['title'] ?? goal['name'] ?? 'Goal';
    final deadline = goal['deadline'] ?? goal['target_date'] ?? '';
    String dateStr = '';
    try { dateStr = DateFormat('d MMM yyyy').format(DateTime.parse(deadline)); } catch (_) {}

    return GestureDetector(
      onTap: () => _showHistory(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.financeGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.flag_rounded, color: AppColors.financeGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
                      if (dateStr.isNotEmpty)
                        Text('Due $dateStr', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ),
                // Add Money inline button
                GestureDetector(
                  onTap: () => _showContribute(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.financeGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 15),
                      SizedBox(width: 4),
                      Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                // Options menu
                GestureDetector(
                  onTap: () => _showOptions(context),
                  child: const Icon(Icons.more_vert_rounded, color: Color(0xFF9CA3AF), size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: AppColors.financeGreenV3.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation(AppColors.financeGreenV3),
                minHeight: 7,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('KES ${fmt.format(saved)} saved', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                Text('${(pct * 100).toStringAsFixed(0)}% of KES ${fmt.format(target)}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── _GoalEditSheet ────────────────────────────────────────────────────────────

class _GoalEditSheet extends StatefulWidget {
  final Map<String, dynamic> goal;
  final String userId;
  final VoidCallback onSuccess;
  const _GoalEditSheet({required this.goal, required this.userId, required this.onSuccess});

  @override
  State<_GoalEditSheet> createState() => _GoalEditSheetState();
}

class _GoalEditSheetState extends State<_GoalEditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _targetCtrl;
  bool _loading = false;
  final fmt = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.goal['goal_name'] ?? widget.goal['title'] ?? '');
    final target = widget.goal['goal_amount'] ?? widget.goal['target_amount'] ?? 100;
    _targetCtrl = TextEditingController(text: target.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final goalId = widget.goal['id']?.toString() ?? '';
    final isDefault = widget.goal['is_default'] == true;
    setState(() => _loading = true);
    try {
      final body = <String, dynamic>{
        'user_id': int.tryParse(widget.userId) ?? widget.userId,
        'title': _nameCtrl.text.trim(),
      };
      if (!isDefault) {
        final t = double.tryParse(_targetCtrl.text.trim()) ?? 0;
        if (t < 100) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Target must be at least KES 100'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
          setState(() => _loading = false);
          return;
        }
        body['target_amount'] = t;
      }
      final r = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/goalsupdate/$goalId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['status'] == 'success') {
        widget.onSuccess();
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data['message'] ?? 'Update failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDefault = widget.goal['is_default'] == true;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Edit Goal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 16),
          const Text('Goal Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            enabled: !isDefault,
            decoration: InputDecoration(
              hintText: 'Goal name',
              filled: true,
              fillColor: isDefault ? const Color(0xFFF9FAFB) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            ),
          ),
          if (!isDefault) ...[
            const SizedBox(height: 14),
            const Text('Target Amount (KES)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            TextField(
              controller: _targetCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: 'KES ',
                prefixStyle: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.financeGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── _GoalContributeSheet ──────────────────────────────────────────────────────

class _GoalContributeSheet extends StatefulWidget {
  final String userId;
  final String goalId;
  final String goalName;
  final VoidCallback onSuccess;
  const _GoalContributeSheet({required this.userId, required this.goalId, required this.goalName, required this.onSuccess});

  @override
  State<_GoalContributeSheet> createState() => _GoalContributeSheetState();
}

class _GoalContributeSheetState extends State<_GoalContributeSheet> {
  final _amtCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _checkoutRef;
  bool _paid = false;
  bool _polling = false;
  int _pollCount = 0;
  static const int _maxPolls = 60;

  @override
  void initState() {
    super.initState();
    _prefillPhone();
  }

  Future<void> _prefillPhone() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.userDetailsById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        final phone = d['data']?['phone_number']?.toString();
        if (mounted && phone != null && phone.isNotEmpty) {
          setState(() => _phoneCtrl.text = phone);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() { _polling = false; _amtCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _sendSTK() async {
    final amt = double.tryParse(_amtCtrl.text.replaceAll(',', ''));
    if (amt == null || amt < 10) { setState(() => _error = 'Minimum contribution is KES 10'); return; }
    final phoneError = ValidationUtils.validateKenyanPhone(_phoneCtrl.text);
    if (phoneError != null) { setState(() => _error = phoneError); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final body = {
        'user_id': widget.userId,
        'amount': amt,
        'phone': _phoneCtrl.text.trim(),
        if (widget.goalId.isNotEmpty) 'goal_id': int.tryParse(widget.goalId) ?? widget.goalId,
      };
      final res = await http.post(
        Uri.parse(ApiConfig.getUrl('deposit')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 20));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['status'] == 'success') {
        setState(() { _loading = false; _checkoutRef = data['checkout_id']?.toString() ?? ''; });
        _startPolling();
      } else {
        setState(() { _loading = false; _error = data['message'] ?? 'Failed to send STK push'; });
      }
    } catch (_) {
      setState(() { _loading = false; _error = 'Network error — check your connection'; });
    }
  }

  void _startPolling() {
    _polling = true; _pollCount = 0;
    Future.doWhile(() async {
      if (!_polling || !mounted) return false;
      await Future.delayed(const Duration(seconds: 3));
      if (!_polling || !mounted) return false;
      _pollCount++;
      if (_pollCount >= _maxPolls) {
        if (mounted) setState(() { _polling = false; _checkoutRef = null; _error = 'Timed out. If debited, goal will update shortly.'; });
        return false;
      }
      try {
        final ref = _checkoutRef ?? '';
        if (ref.isEmpty) return false;
        final res = await http.get(Uri.parse(ApiConfig.transactionStatus(ref))).timeout(const Duration(seconds: 10));
        final data = jsonDecode(res.body);
        final status = (data['payment_status'] ?? data['status'] ?? '').toString().toUpperCase();
        if (status == 'SUCCESS' || status == 'COMPLETE' || status == 'COMPLETED') {
          if (mounted) { setState(() { _paid = true; _polling = false; }); widget.onSuccess(); }
          return false;
        } else if (status == 'FAILED' || status == 'CANCELLED' || status == 'EXPIRED') {
          if (mounted) setState(() { _polling = false; _checkoutRef = null; _error = 'Payment ${status.toLowerCase()} — please try again'; });
          return false;
        }
      } catch (_) {}
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottom = mq.viewInsets.bottom + mq.padding.bottom + 24;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          if (_paid) ...[
            Center(child: Column(children: [
              Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.financeGreen, size: 40)),
              const SizedBox(height: 16),
              Text('Added to ${widget.goalName}!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              const SizedBox(height: 6),
              const Text('Your goal has been updated.', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreen, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )),
            ])),
          ] else if (_checkoutRef != null) ...[
            Center(child: Column(children: [
              const SizedBox(height: 8),
              const CircularProgressIndicator(color: AppColors.financeGreen, strokeWidth: 3),
              const SizedBox(height: 16),
              const Text('Check your phone', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              const SizedBox(height: 6),
              const Text('Enter your M-Pesa PIN to save to your goal.\nWaiting for confirmation...', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextButton(onPressed: () => setState(() { _checkoutRef = null; _polling = false; }), child: const Text('Cancel / Try again', style: TextStyle(color: Colors.red))),
            ])),
          ] else ...[
            Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.flag_rounded, color: AppColors.financeGreen, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Save to Goal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                Text(widget.goalName, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ])),
            ]),
            const SizedBox(height: 20),
            _field(_amtCtrl, 'Amount (KES)', isNumber: true, onChanged: (_) => setState(() {})),
            const SizedBox(height: 8),
            Builder(builder: (_) {
              final amt = double.tryParse(_amtCtrl.text.replaceAll(',', '')) ?? 0;
              if (amt <= 0) return const SizedBox.shrink();
              final charge = (amt * 0.015).ceil().toDouble();
              final total = amt + charge;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Save to goal', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    Text('KES ${amt.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Fee', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    Text('KES ${charge.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
                  ]),
                  const Divider(height: 12, color: Color(0xFFD1FAE5)),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('M-Pesa total', style: TextStyle(fontSize: 13, color: Color(0xFF111827), fontWeight: FontWeight.bold)),
                    Text('KES ${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: AppColors.financeGreen, fontWeight: FontWeight.bold)),
                  ]),
                ]),
              );
            }),
            const SizedBox(height: 12),
            _field(_phoneCtrl, 'M-Pesa Phone Number', isNumber: true),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [const Icon(Icons.error_outline, color: Colors.red, size: 16), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)))]),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _loading ? null : _sendSTK,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreen, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Send STK Push', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            )),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, {bool isNumber = false, void Function(String)? onChanged}) {
    return TextField(
      controller: ctrl,
      onChanged: onChanged,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        filled: true, fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ── _EmptyGoals ───────────────────────────────────────────────────────────────
class _EmptyGoals extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyGoals({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.coreWhiteW2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: AppColors.financeGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.financeGreen, size: 30),
            ),
            const SizedBox(height: 12),
            const Text('Create your first goal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            const Text('People with goals save 3× more', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}

// ── _TipCard ──────────────────────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final Color color;
  const _TipCard({required this.icon, required this.title, required this.body, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827))),
                  const SizedBox(height: 3),
                  Text(body, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _Skeleton ─────────────────────────────────────────────────────────────────
class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({required this.height});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(16)),
      );
}
