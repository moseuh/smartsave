import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Goal Creation Screen — clean full-page form
// ─────────────────────────────────────────────────────────────────────────────

class GoalCreationScreen extends StatefulWidget {
  final String userId;
  const GoalCreationScreen({super.key, required this.userId});

  @override
  State<GoalCreationScreen> createState() => _GoalCreationScreenState();
}

class _GoalCreationScreenState extends State<GoalCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _amtCtrl   = TextEditingController();
  final _daysCtrl  = TextEditingController();
  String _goalType = 'General';
  bool _saving = false;

  static const _goalTypes = [
    ('General',       Icons.savings_outlined),
    ('Emergency',     Icons.health_and_safety_outlined),
    ('Education',     Icons.school_outlined),
    ('Travel',        Icons.flight_outlined),
    ('Home',          Icons.home_outlined),
    ('Business',      Icons.business_center_outlined),
    ('Retirement',    Icons.elderly_outlined),
  ];

  static const _durations = [
    ('30 days',   30),
    ('60 days',   60),
    ('90 days',   90),
    ('6 months',  180),
    ('1 year',    365),
  ];

  int? _quickDays; // null = custom

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amtCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  Color _typeColor(String t) => AppColors.financeGreen;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final name  = _nameCtrl.text.trim();
    final amt   = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    final days  = _quickDays ?? (int.tryParse(_daysCtrl.text.trim()) ?? 30);

    setState(() => _saving = true);
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/goalscreate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id':       widget.userId,
          'title':         name,
          'target_amount': amt,
          'duration_days': days,
          'goal_type':     _goalType,
        }),
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (r.statusCode == 200 || r.statusCode == 201) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Goal created successfully!'),
          backgroundColor: AppColors.financeGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      } else {
        final err = jsonDecode(r.body);
        _snack(err['message'] ?? 'Failed to create goal');
      }
    } catch (_) {
      _snack('Network error — check your connection');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(_goalType);
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
        title: const Text('New Goal',
            style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // ── Goal type chips ──
            const Text('Goal Type',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _goalTypes.map(((String t, IconData icon) rec) {
                final selected = _goalType == rec.$1;
                final c = _typeColor(rec.$1);
                return GestureDetector(
                  onTap: () => setState(() => _goalType = rec.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? c : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? c : const Color(0xFFE5E7EB), width: 1.5),
                      boxShadow: selected ? [BoxShadow(color: c.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))] : [],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(rec.$2, size: 15, color: selected ? Colors.white : const Color(0xFF6B7280)),
                      const SizedBox(width: 6),
                      Text(rec.$1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xFF374151))),
                    ]),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ── Goal name ──
            _label('Goal Name'),
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
              decoration: _inputDecor('e.g. School fees 2027', Icons.label_outline_rounded),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name for your goal' : null,
            ),

            const SizedBox(height: 16),

            // ── Target amount ──
            _label('Target Amount (KES)'),
            TextFormField(
              controller: _amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
              decoration: _inputDecor('e.g. 50000', Icons.monetization_on_outlined),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n < 100) return 'Enter at least KES 100';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ── Duration quick-pick ──
            _label('Duration'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._durations.map(((String label, int days) rec) {
                  final selected = _quickDays == rec.$2;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _quickDays = rec.$2;
                        _daysCtrl.text = rec.$2.toString();
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? color : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? color : const Color(0xFFE5E7EB), width: 1.5),
                      ),
                      child: Text(rec.$1,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : const Color(0xFF374151))),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => setState(() => _quickDays = null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _quickDays == null ? color : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _quickDays == null ? color : const Color(0xFFE5E7EB), width: 1.5),
                    ),
                    child: Text('Custom',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: _quickDays == null ? Colors.white : const Color(0xFF374151))),
                  ),
                ),
              ],
            ),
            if (_quickDays == null) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _daysCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
                decoration: _inputDecor('Number of days', Icons.calendar_today_outlined),
                validator: _quickDays == null
                    ? (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1) return 'Enter a valid number of days';
                        return null;
                      }
                    : null,
              ),
            ],

            const SizedBox(height: 28),

            // ── Preview ──
            if (_amtCtrl.text.isNotEmpty || _nameCtrl.text.isNotEmpty) _buildPreview(color),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Create Goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(Color color) {
    final name   = _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'Your Goal';
    final amt    = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    final days   = _quickDays ?? (int.tryParse(_daysCtrl.text.trim()) ?? 30);
    final daily  = days > 0 && amt > 0 ? amt / days : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Text('Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ]),
        const SizedBox(height: 10),
        _previewRow('Goal', name),
        if (amt > 0) _previewRow('Target', 'KES ${amt.toStringAsFixed(2)}'),
        _previewRow('Duration', '$days days'),
        if (daily > 0) _previewRow('Daily savings needed', 'KES ${daily.toStringAsFixed(2)}'),
      ]),
    );
  }

  Widget _previewRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
    ]),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
  );

  InputDecoration _inputDecor(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
    prefixIcon: Icon(icon, color: AppColors.financeGreen, size: 20),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.financeGreen, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFDC2626))),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  GoalFormSheet — kept for backward compatibility (delegates to GoalCreationScreen)
// ─────────────────────────────────────────────────────────────────────────────

class GoalFormSheet extends StatelessWidget {
  final String userId;
  final List<String> goalTypes;
  final VoidCallback onGoalCreated;
  final void Function(String) onShowCatalogue;

  const GoalFormSheet({
    super.key,
    required this.userId,
    required this.goalTypes,
    required this.onGoalCreated,
    required this.onShowCatalogue,
  });

  @override
  Widget build(BuildContext context) {
    // Just push the full-screen creation screen instead
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => GoalCreationScreen(userId: userId),
      )).then((_) => onGoalCreated());
    });
    return const SizedBox.shrink();
  }
}
