import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';
import '../constants/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  Round Savings Settings — up to 3 rules per user
//  Each rule: fixed KES amount OR percentage of transaction
// ─────────────────────────────────────────────────────────────────

class RoundUpSettings extends StatefulWidget {
  const RoundUpSettings({super.key});

  @override
  State<RoundUpSettings> createState() => _RoundUpSettingsState();
}

class _RoundUpSettingsState extends State<RoundUpSettings> {
  bool _loading = true;
  bool _saving = false;
  String? _userId;

  final List<_RuleModel> _rules = [];
  List<Map<String, dynamic>> _goals = []; // { id, goal_name }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    if (_userId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      // Fetch settings+rules and goals in parallel
      final results = await Future.wait([
        http.get(Uri.parse('${AppConstants.apiBaseUrl}/roundup-settings/$_userId')),
        http.get(Uri.parse('${AppConstants.apiBaseUrl}/goalslist/$_userId')),
      ]);

      final settingsRes = results[0];
      final goalsRes = results[1];

      if (settingsRes.statusCode == 200) {
        final d = jsonDecode(settingsRes.body);
        final rawRules = d['rules'] as List? ?? [];
        _rules.clear();
        for (final rule in rawRules) {
          _rules.add(_RuleModel(
            id: rule['id'],
            type: rule['type'] ?? 'fixed',
            value: rule['value']?.toString() ?? '',
            appliesTo: rule['applies_to'] ?? 'both',
            goalId: rule['goal_id'],
            goalName: rule['goal_name'],
            active: rule['active'] == true || rule['active'] == 1,
          ));
        }
      }

      if (goalsRes.statusCode == 200) {
        final d = jsonDecode(goalsRes.body);
        final rawGoals = (d['goals'] ?? d['data'] ?? d) as List? ?? [];
        _goals.clear();
        _goals.addAll(rawGoals.map((g) => {
          'id': g['id'],
          'goal_name': g['goal_name'] ?? g['title'] ?? 'Goal ${g['id']}',
        }));
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _addRule() {
    if (_rules.length >= 3) {
      _snack('Maximum 3 round savings rules allowed', error: true);
      return;
    }
    setState(() => _rules.add(_RuleModel(type: 'fixed', value: '0', appliesTo: 'both', active: true)));
  }

  void _removeRule(int index) {
    setState(() => _rules.removeAt(index));
  }

  Future<void> _save() async {
    if (_userId == null) return;

    // Validate
    for (int i = 0; i < _rules.length; i++) {
      final r = _rules[i];
      final val = double.tryParse(r.value);
      if (val == null || val < 0) {
        _snack('Rule ${i + 1}: Enter a valid amount', error: true);
        return;
      }
      if (r.type == 'percentage' && val > 100) {
        _snack('Rule ${i + 1}: Percentage cannot exceed 100%', error: true);
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final hasActive = _rules.any((r) => r.active);
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/roundup-settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _userId,
          'is_enabled': hasActive,
          'buy_goods_round_up': _rules.any((r) => r.active && (r.appliesTo == 'buy_goods' || r.appliesTo == 'both')),
          'pay_bill_round_up': _rules.any((r) => r.active && (r.appliesTo == 'pay_bill' || r.appliesTo == 'both')),
          'rules': _rules.map((r) => {
            'type': r.type,
            'value': double.parse(r.value),
            'applies_to': r.appliesTo,
            'goal_id': r.goalId,
            'active': r.active,
          }).toList(),
        }),
      );
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['status'] == 'success') {
        _snack('Round savings saved!');
        if (mounted) Navigator.pop(context);
      } else {
        _snack(data['message'] ?? 'Failed to save', error: true);
      }
    } catch (_) {
      _snack('Network error', error: true);
    }
    if (mounted) setState(() => _saving = false);
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Round Savings',
            style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.financeGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header explanation
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.financeGreen.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.15)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.savings_rounded, color: AppColors.financeGreen, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('How Round Savings Works',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                        SizedBox(height: 4),
                        Text(
                          'When you pay, a small extra amount is added on top and saved to your wallet. You control the rules below.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4),
                        ),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Your Rules (${_rules.length}/3)',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  if (_rules.length < 3)
                    GestureDetector(
                      onTap: _addRule,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.financeGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Add Rule', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                ]),
                const SizedBox(height: 12),

                if (_rules.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(children: [
                      Icon(Icons.add_circle_outline_rounded, size: 40, color: AppColors.financeGreen.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      const Text('No rules yet', style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
                      const SizedBox(height: 4),
                      const Text('Tap "Add Rule" to create your first round savings rule',
                          style: TextStyle(fontSize: 12, color: Color(0xFFD1D5DB)), textAlign: TextAlign.center),
                    ]),
                  )
                else
                  for (int i = 0; i < _rules.length; i++) ...[
                    _RuleCard(
                      index: i,
                      rule: _rules[i],
                      goals: _goals,
                      onChanged: (updated) => setState(() => _rules[i] = updated),
                      onRemove: () => _removeRule(i),
                    ),
                    if (i < _rules.length - 1) const SizedBox(height: 10),
                  ],

                const SizedBox(height: 24),

                // Example preview
                if (_rules.isNotEmpty) _buildPreview(),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.financeGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Rules', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 16),
              ]),
            ),
    );
  }

  Widget _buildPreview() {
    const exampleAmt = 100.0;
    double extraFixed = 0;
    double extraPct = 0;
    for (final r in _rules) {
      if (!r.active) continue;
      final val = double.tryParse(r.value) ?? 0;
      if (r.type == 'fixed') extraFixed += val;
      if (r.type == 'percentage') extraPct += (exampleAmt * val) / 100;
    }
    final extra = extraFixed + extraPct;
    final total = exampleAmt + extra;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Preview (example: KES 100 payment)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 12),
        _previewRow('Payment amount', 'KES 100.00'),
        _previewRow('Round savings added', '+ KES ${extra.toStringAsFixed(2)}', green: true),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
        _previewRow('Total deducted', 'KES ${total.toStringAsFixed(2)}', bold: true),
      ]),
    );
  }

  Widget _previewRow(String label, String value, {bool bold = false, bool green = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: 13, color: bold ? const Color(0xFF111827) : const Color(0xFF6B7280), fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 13, color: green ? AppColors.financeGreen : (bold ? AppColors.financeGreen : const Color(0xFF374151)), fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────
//  Rule Card Widget
// ─────────────────────────────────────────────────────────────────

class _RuleModel {
  final int? id;
  String type;       // 'fixed' | 'percentage'
  String value;      // numeric string
  String appliesTo;  // 'buy_goods' | 'pay_bill' | 'both'
  int? goalId;
  String? goalName;
  bool active;

  _RuleModel({
    this.id,
    required this.type,
    required this.value,
    required this.appliesTo,
    this.goalId,
    this.goalName,
    required this.active,
  });

  _RuleModel copyWith({String? type, String? value, String? appliesTo, int? goalId, String? goalName, bool? active, bool clearGoal = false}) => _RuleModel(
        id: id,
        type: type ?? this.type,
        value: value ?? this.value,
        appliesTo: appliesTo ?? this.appliesTo,
        goalId: clearGoal ? null : (goalId ?? this.goalId),
        goalName: clearGoal ? null : (goalName ?? this.goalName),
        active: active ?? this.active,
      );
}

class _RuleCard extends StatefulWidget {
  final int index;
  final _RuleModel rule;
  final List<Map<String, dynamic>> goals;
  final ValueChanged<_RuleModel> onChanged;
  final VoidCallback onRemove;

  const _RuleCard({required this.index, required this.rule, required this.goals, required this.onChanged, required this.onRemove});

  @override
  State<_RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends State<_RuleCard> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.rule.value);
    _ctrl.addListener(() => widget.onChanged(widget.rule.copyWith(value: _ctrl.text)));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rule;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: r.active ? AppColors.financeGreen.withValues(alpha: 0.35) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: AppColors.financeGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${widget.index + 1}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.financeGreen)),
            ),
          ),
          const SizedBox(width: 8),
          const Text('Rule', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const Spacer(),
          // Active toggle
          GestureDetector(
            onTap: () => widget.onChanged(r.copyWith(active: !r.active)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: r.active ? AppColors.financeGreen : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                r.active ? 'Active' : 'Paused',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: r.active ? Colors.white : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onRemove,
            child: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF9CA3AF)),
          ),
        ]),
        const SizedBox(height: 12),

        // Type selector
        Row(children: [
          _typeBtn('Fixed (KES)', 'fixed', r.type, () => widget.onChanged(r.copyWith(type: 'fixed'))),
          const SizedBox(width: 8),
          _typeBtn('Percentage (%)', 'percentage', r.type, () => widget.onChanged(r.copyWith(type: 'percentage'))),
        ]),
        const SizedBox(height: 10),

        // Value input
        TextField(
          controller: _ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 15, color: Color(0xFF111827), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: r.type == 'fixed' ? 'e.g. 10' : 'e.g. 5',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.normal),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                r.type == 'fixed' ? 'KES ' : '%',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.financeGreen),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),

        // Applies to selector
        const Text('Applies to:', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(children: [
          _appliesToBtn('Buy Goods', 'buy_goods', r.appliesTo, () => widget.onChanged(r.copyWith(appliesTo: 'buy_goods'))),
          const SizedBox(width: 6),
          _appliesToBtn('Pay Bill', 'pay_bill', r.appliesTo, () => widget.onChanged(r.copyWith(appliesTo: 'pay_bill'))),
          const SizedBox(width: 6),
          _appliesToBtn('Both', 'both', r.appliesTo, () => widget.onChanged(r.copyWith(appliesTo: 'both'))),
        ]),

        // Goal picker
        if (widget.goals.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Save to goal:', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int?>(
            initialValue: r.goalId,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
            ),
            hint: const Text('Wallet (no specific goal)', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Wallet (general savings)', style: TextStyle(fontSize: 13))),
              ...widget.goals.map((g) => DropdownMenuItem<int?>(
                value: g['id'] as int?,
                child: Text(g['goal_name']?.toString() ?? 'Goal', style: const TextStyle(fontSize: 13)),
              )),
            ],
            onChanged: (val) {
              final goalName = val == null ? null : widget.goals.firstWhere((g) => g['id'] == val, orElse: () => {})['goal_name']?.toString();
              widget.onChanged(val == null ? r.copyWith(clearGoal: true) : r.copyWith(goalId: val, goalName: goalName));
            },
          ),
        ],
      ]),
    );
  }

  Widget _typeBtn(String label, String value, String current, VoidCallback onTap) {
    final selected = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.financeGreen : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? AppColors.financeGreen : const Color(0xFFE5E7EB)),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              )),
        ),
      ),
    );
  }

  Widget _appliesToBtn(String label, String value, String current, VoidCallback onTap) {
    final selected = current == value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.financeGreen.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.financeGreen : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.financeGreen : const Color(0xFF9CA3AF),
            )),
      ),
    );
  }
}
