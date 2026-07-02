import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../constants/app_theme.dart';
import '../constants/app_constants.dart';
import '../services/tab_refresh_registry.dart';

// Safe numeric parse — handles String, int, double, or null from JSON
double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

class LoansTab extends StatefulWidget {
  final String userId;
  const LoansTab({super.key, required this.userId});

  @override
  State<LoansTab> createState() => _LoansTabState();
}

class _LoansTabState extends State<LoansTab> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _borrowKey = GlobalKey<_SocialBorrowingTabState>();

  void refresh() => _borrowKey.currentState?._load();

  @override
  void initState() {
    super.initState();
    TabRefreshRegistry.register(3, refresh);
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    TabRefreshRegistry.unregister(3);
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Rafiki2Rafiki',
                  style: TextStyle(color: Color(0xFF111827), fontSize: 26,
                      fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              const Text('Borrow & lend with your people',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              const SizedBox(height: 16),
              // Tab bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F2EB),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.financeGreen,
                  unselectedLabelColor: const Color(0xFF9CA3AF),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Rafiki2Rafiki'),
                    Tab(text: 'Nebo Loans'),
                  ],
                ),
              ),
            ]),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _SocialBorrowingTab(key: _borrowKey, userId: widget.userId),
                const _NeboLoansTab(),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  SOCIAL BORROWING TAB
// ─────────────────────────────────────────────────────────────────

class _SocialBorrowingTab extends StatefulWidget {
  final String userId;
  const _SocialBorrowingTab({super.key, required this.userId});

  @override
  State<_SocialBorrowingTab> createState() => _SocialBorrowingTabState();
}

class _SocialBorrowingTabState extends State<_SocialBorrowingTab> {
  List<Map<String, dynamic>> _links = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/social-borrowing/my/${widget.userId}'),
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (mounted) setState(() => _links = List<Map<String, dynamic>>.from(d['data'] ?? []));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleLink(Map<String, dynamic> link) async {
    try {
      final r = await http.patch(
        Uri.parse('${AppConstants.apiBaseUrl}/social-borrowing/${link['id']}/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': widget.userId}),
      );
      if (r.statusCode == 200) _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.financeGreen));
    }

    return RefreshIndicator(
      color: AppColors.financeGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          // Create new link button
          _CreateLinkCard(userId: widget.userId, onCreated: _load),
          const SizedBox(height: 20),

          if (_links.isEmpty) ...[
            const SizedBox(height: 32),
            Center(
              child: Column(children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.financeGreen.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.link_rounded, color: AppColors.financeGreen, size: 34),
                ),
                const SizedBox(height: 16),
                const Text('No links yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                const SizedBox(height: 6),
                const Text('Create your first Rafiki2Rafiki link\nand share it with friends.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
              ]),
            ),
          ] else ...[
            const Text('Your Links', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
            const SizedBox(height: 12),
            ..._links.map((link) => _LinkCard(
              link: link,
              userId: widget.userId,
              onToggle: () => _toggleLink(link),
              onRefresh: _load,
            )),
          ],
        ],
      ),
    );
  }
}

// ── Create Link Card ──────────────────────────────────────────────

class _CreateLinkCard extends StatefulWidget {
  final String userId;
  final VoidCallback onCreated;
  const _CreateLinkCard({required this.userId, required this.onCreated});

  @override
  State<_CreateLinkCard> createState() => _CreateLinkCardState();
}

class _CreateLinkCardState extends State<_CreateLinkCard> {
  bool _expanded = false;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  DateTime? _repaymentDate;
  bool _termsAccepted = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.financeGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _repaymentDate = picked);
  }

  Future<void> _create() async {
    final title = _titleCtrl.text.trim();
    final amt = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    if (title.isEmpty || amt <= 0) {
      _snack('Enter a title and target amount');
      return;
    }
    if (_repaymentDate == null) {
      _snack('Select a repayment date');
      return;
    }
    if (!_termsAccepted) {
      _snack('You must accept the terms to continue');
      return;
    }
    setState(() => _saving = true);
    final repayStr = '${_repaymentDate!.year}-${_repaymentDate!.month.toString().padLeft(2, '0')}-${_repaymentDate!.day.toString().padLeft(2, '0')}';
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/social-borrowing/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'title': title,
          'description': _descCtrl.text.trim(),
          'target_amount': amt,
          'repayment_date': repayStr,
        }),
      ).timeout(const Duration(seconds: 12));
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['status'] == 'success') {
        final link = d['data']['link'] as String;
        _titleCtrl.clear();
        _descCtrl.clear();
        _amtCtrl.clear();
        setState(() { _expanded = false; _saving = false; _repaymentDate = null; _termsAccepted = false; });
        widget.onCreated();
        if (mounted) _showCreatedDialog(link);
      } else {
        _snack(d['message'] ?? 'Failed to create link', error: true);
        setState(() => _saving = false);
      }
    } catch (_) {
      _snack('Network error', error: true);
      setState(() => _saving = false);
    }
  }

  void _showCreatedDialog(String link) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.financeGreen, size: 34),
          ),
          const SizedBox(height: 14),
          const Text('Borrowing Link Created!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 8),
          const Text('Share this link with friends and family. They will see the repayment date and terms before sending money.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Expanded(child: Text(link, style: const TextStyle(fontSize: 12, color: Color(0xFF374151)), overflow: TextOverflow.ellipsis)),
              GestureDetector(
                onTap: () { Clipboard.setData(ClipboardData(text: link)); _snack('Copied!'); },
                child: const Icon(Icons.copy_rounded, size: 18, color: AppColors.financeGreen),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                SharePlus.instance.share(ShareParams(text: 'I need your help! Lend me money via Nebo — see details and repayment date here: $link'));
              },
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Share Link'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.financeGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
        ]),
      ),
    );
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B6631), Color(0xFF27AE60)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.financeGreen.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _expanded ? null : () => setState(() => _expanded = true),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _expanded ? _buildForm() : _buildCollapsed(),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsed() => Row(children: [
    Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
      child: const Icon(Icons.add_link_rounded, color: Colors.white, size: 22),
    ),
    const SizedBox(width: 14),
    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Create a Borrowing Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      SizedBox(height: 3),
      Text('Share with friends to collect money', style: TextStyle(color: Colors.white70, fontSize: 12)),
    ])),
    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
  ]);

  Widget _buildForm() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Expanded(child: Text('New Borrowing Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
      GestureDetector(
        onTap: () => setState(() => _expanded = false),
        child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
      ),
    ]),
    const SizedBox(height: 16),
    _whiteField(_titleCtrl, 'Title (e.g. "School fees help")'),
    const SizedBox(height: 10),
    _whiteField(_descCtrl, 'Description (optional)'),
    const SizedBox(height: 10),
    _whiteField(_amtCtrl, 'Target amount (KES)', keyboardType: TextInputType.number),
    const SizedBox(height: 10),
    // Repayment date picker
    GestureDetector(
      onTap: _pickDate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF9CA3AF)),
          const SizedBox(width: 10),
          Text(
            _repaymentDate == null
                ? 'Repayment date'
                : 'Repay by ${_repaymentDate!.day}/${_repaymentDate!.month}/${_repaymentDate!.year}',
            style: TextStyle(
              fontSize: 14,
              color: _repaymentDate == null ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
            ),
          ),
        ]),
      ),
    ),
    const SizedBox(height: 14),
    // Terms & Conditions
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('By creating this link you confirm:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 6),
        const Text('• Nebo is not a lender, credit provider, debt collector, or financial advisor\n• Any financial support is arranged directly between you and your personal contacts\n• Nebo only provides tools for tracking contributions and repayments',
            style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.5)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _termsAccepted = !_termsAccepted),
          child: Row(children: [
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: _termsAccepted ? Colors.white : Colors.transparent,
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _termsAccepted
                  ? const Icon(Icons.check_rounded, size: 14, color: AppColors.financeGreen)
                  : null,
            ),
            const SizedBox(width: 8),
            const Expanded(child: Text('I understand and agree', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
          ]),
        ),
      ]),
    ),
    const SizedBox(height: 16),
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saving ? null : _create,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.financeGreen,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _saving
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.financeGreen))
            : const Text('Create & Get Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    ),
  ]);

  Widget _whiteField(TextEditingController ctrl, String hint, {TextInputType? keyboardType}) => TextField(
    controller: ctrl,
    keyboardType: keyboardType,
    style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    ),
  );
}

// ── Individual Link Card ──────────────────────────────────────────

class _LinkCard extends StatelessWidget {
  final Map<String, dynamic> link;
  final String userId;
  final VoidCallback onToggle;
  final VoidCallback onRefresh;
  const _LinkCard({required this.link, required this.userId, required this.onToggle, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final double raised = _d(link['raised']);
    final double target = _d(link['target_amount']);
    final double pending = _d(link['pending']);
    final int contributors = _d(link['contributors']).toInt();
    final bool active = link['is_active'] == true;
    final String linkUrl = link['link']?.toString() ?? '';
    final double pct = target > 0 ? (raised / target).clamp(0.0, 1.0) : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: active ? AppColors.financeGreen.withValues(alpha: 0.1) : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.link_rounded, color: active ? AppColors.financeGreen : const Color(0xFF9CA3AF), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(link['title']?.toString() ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)), maxLines: 1, overflow: TextOverflow.ellipsis),
              if ((link['description'] as String?)?.isNotEmpty == true)
                Text(link['description'].toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            // Active toggle
            GestureDetector(
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? AppColors.financeGreen.withValues(alpha: 0.1) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: active ? AppColors.financeGreen : const Color(0xFF9CA3AF), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(active ? 'Active' : 'Paused', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? AppColors.financeGreen : const Color(0xFF9CA3AF))),
                ]),
              ),
            ),
          ]),
        ),

        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 7,
                backgroundColor: const Color(0xFFE5F2EA),
                valueColor: const AlwaysStoppedAnimation(AppColors.financeGreen),
              ),
            ),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('KES ${raised.toStringAsFixed(2)} raised', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              Text('of KES ${target.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ]),
          ]),
        ),

        const SizedBox(height: 12),

        // Stats row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _statChip(Icons.people_alt_rounded, '$contributors', 'people'),
            const SizedBox(width: 10),
            _statChip(Icons.hourglass_top_rounded, 'KES ${pending.toStringAsFixed(2)}', 'pending'),
            const SizedBox(width: 10),
            _statChip(Icons.percent_rounded, '${(pct * 100).toStringAsFixed(0)}%', 'funded'),
          ]),
        ),

        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),

        // Action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            _actionBtn(Icons.share_rounded, 'Share', () {
              SharePlus.instance.share(ShareParams(text: 'I need your help! Lend me money via Nebo — see details and repayment date here: $linkUrl'));
            }),
            _actionBtn(Icons.copy_rounded, 'Copy Link', () {
              Clipboard.setData(ClipboardData(text: linkUrl));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Link copied!'),
                backgroundColor: AppColors.financeGreen,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ));
            }),
            _actionBtn(Icons.bar_chart_rounded, 'Activity', () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => _LinkActivityScreen(link: link, userId: userId),
              ));
            }),
          ]),
        ),
      ]),
    );
  }

  Widget _statChip(IconData icon, String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 13, color: AppColors.financeGreen),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        ]),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
      ]),
    ),
  );

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) => Expanded(
    child: TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: AppColors.financeGreen),
      label: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.financeGreen, fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
    ),
  );
}

// ── Link Activity Screen ──────────────────────────────────────────

class _LinkActivityScreen extends StatefulWidget {
  final Map<String, dynamic> link;
  final String userId;
  const _LinkActivityScreen({required this.link, required this.userId});

  @override
  State<_LinkActivityScreen> createState() => _LinkActivityScreenState();
}

class _LinkActivityScreenState extends State<_LinkActivityScreen> {
  List<Map<String, dynamic>> _contributions = [];
  bool _loading = true;
  Map<String, dynamic> _stats = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // Auto-refresh every 30s
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final slug = widget.link['slug']?.toString() ?? '';
      final r = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/social-borrowing/stats/$slug'),
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (mounted) {
          setState(() {
            _stats = d['data'] ?? {};
            _contributions = List<Map<String, dynamic>>.from(_stats['recent'] ?? []);
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double raised = _d(_stats['raised']);
    final double target = _stats.containsKey('target_amount') ? _d(_stats['target_amount']) : _d(widget.link['target_amount']);
    final int contributors = _d(_stats['contributors']).toInt();
    final double pct = target > 0 ? (raised / target).clamp(0.0, 1.0) : 0;
    final String linkUrl = widget.link['link']?.toString() ?? '';

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
        title: Text(widget.link['title']?.toString() ?? 'Activity',
            style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.financeGreen),
            onPressed: () => SharePlus.instance.share(ShareParams(text: 'I need your help! Lend me money via Nebo — see details and repayment date here: $linkUrl')),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.financeGreen))
          : RefreshIndicator(
              color: AppColors.financeGreen,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  // Progress card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B6631), Color(0xFF27AE60)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('KES ${raised.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text('of KES ${target.toStringAsFixed(2)} target',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('${(pct * 100).toStringAsFixed(0)}% funded',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('$contributors contributor${contributors == 1 ? '' : 's'}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ]),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  // Stats grid
                  Row(children: [
                    _statCard('Raised', 'KES ${raised.toStringAsFixed(2)}', Icons.trending_up_rounded, AppColors.financeGreen),
                    const SizedBox(width: 12),
                    _statCard('Pending', 'KES ${(target - raised).clamp(0, double.infinity).toStringAsFixed(2)}', Icons.hourglass_empty_rounded, const Color(0xFFD97706)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _statCard('Contributors', '$contributors people', Icons.people_rounded, const Color(0xFF6366F1)),
                    const SizedBox(width: 12),
                    _statCard('Progress', '${(pct * 100).toStringAsFixed(0)}%', Icons.donut_large_rounded, AppColors.financeGreen),
                  ]),

                  const SizedBox(height: 24),

                  // Contributions list
                  const Text('Recent Contributions',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                  const SizedBox(height: 12),

                  if (_contributions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(children: [
                          Icon(Icons.inbox_rounded, size: 40, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text('No contributions yet', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
                          const SizedBox(height: 4),
                          const Text('Share your link to start collecting', style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12)),
                        ]),
                      ),
                    )
                  else
                    ..._contributions.map((c) => _ContributionRow(c)),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
      ]),
    ),
  );
}

class _ContributionRow extends StatelessWidget {
  final Map<String, dynamic> c;
  const _ContributionRow(this.c);

  @override
  Widget build(BuildContext context) {
    final amt = _d(c['amount']);
    final name = c['contributor_name']?.toString() ?? 'Anonymous';
    final time = c['created_at']?.toString() ?? '';
    final initials = name.trim().split(' ').map((w) => w.isEmpty ? '' : w[0].toUpperCase()).take(2).join();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Center(child: Text(initials, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.financeGreen))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF111827))),
          if (time.isNotEmpty)
            Text(_formatTime(time), style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ])),
        Text('KES ${amt.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.financeGreen)),
      ]),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────
//  NEBO LOANS TAB
// ─────────────────────────────────────────────────────────────────

class _NeboLoansTab extends StatelessWidget {
  const _NeboLoansTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        // Coming soon hero
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B6631), Color(0xFF27AE60)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Nebo Loans', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Instant credit powered by your savings history and financial behaviour.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.construction_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text('In Development', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
          ]),
        ),

        const SizedBox(height: 24),

        const Text('What\'s Coming', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
        const SizedBox(height: 12),

        _featureCard(Icons.speed_rounded, 'Instant Approval', 'Get a loan decision in seconds based on your Nebo savings score.', const Color(0xFF6366F1)),
        _featureCard(Icons.credit_score_rounded, 'CRB Check & Credit Score', 'We\'ll check your CRB status and generate a credit score from your activity.', const Color(0xFFD97706)),
        _featureCard(Icons.account_balance_wallet_rounded, 'Wallet Disbursement', 'Loan funds go straight to your Nebo wallet — ready to use immediately.', AppColors.financeGreen),
        _featureCard(Icons.schedule_rounded, 'Flexible Repayment', 'Choose your repayment plan and pay back via M-Pesa automatically.', const Color(0xFFEC4899)),

        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.financeGreen.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.2)),
          ),
          child: const Row(children: [
            Icon(Icons.notifications_outlined, color: AppColors.financeGreen, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text('We\'ll notify you the moment Nebo Loans goes live.',
                style: TextStyle(color: AppColors.financeGreen, fontWeight: FontWeight.w600, fontSize: 13))),
          ]),
        ),
      ],
    );
  }

  Widget _featureCard(IconData icon, String title, String desc, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
    ),
    child: Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        const SizedBox(height: 3),
        Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4)),
      ])),
    ]),
  );
}
