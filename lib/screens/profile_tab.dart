import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_theme.dart';
import '../config/api_config.dart';
import '../services/tab_refresh_registry.dart';
import 'profile.dart' show Profile;
import 'favourites.dart' show Favourites;
import 'modern_login_screen.dart';
import 'onboarding_flow.dart';

// Notification preference keys
const _kNotifPayments   = 'notif_payments';
const _kNotifSavings    = 'notif_savings';
const _kNotifGoals      = 'notif_goals';
const _kNotifPromotions = 'notif_promotions';

class ProfileTab extends StatefulWidget {
  final String userId;
  const ProfileTab({super.key, required this.userId});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  void refresh() => _load();

  @override
  void initState() {
    super.initState();
    TabRefreshRegistry.register(4, refresh);
    _load();
  }

  @override
  void dispose() {
    TabRefreshRegistry.unregister(4);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.userDetailsById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') setState(() => _user = d['data']);
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  String get _name => _user?['full_name'] ?? _user?['user_name'] ?? 'Nebo User';
  String get _email => _user?['email'] ?? '';
  String get _phone => _user?['phone'] ?? '';

  String get _avatarUrl {
    final path = _user?['selfie_path']?.toString().replaceAll('\\', '/');
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl.replaceAll('/api', '')}/$path';
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('You\'ll need to log back in to access your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ModernLoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // Header with avatar
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.backgroundLight,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    children: [
                      // Avatar
                      Stack(
                        children: [
                          Container(
                            width: 88, height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.25), width: 3),
                            ),
                            child: ClipOval(
                              child: _avatarUrl.isNotEmpty
                                  ? Image.network(_avatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initials())
                                  : _initials(),
                            ),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: GestureDetector(
                              onTap: () => _go(Profile(userId: widget.userId)),
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.financeGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(_loading ? '...' : _name,
                          style: const TextStyle(color: Color(0xFF111827), fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      if (_email.isNotEmpty)
                        Text(_email, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                      if (_phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(_phone, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Account section
                _SectionLabel('Account'),
                _MenuTile(icon: Icons.person_outline_rounded, label: 'Edit Profile', onTap: () => _go(Profile(userId: widget.userId))),
                _MenuTile(icon: Icons.notifications_none_rounded, label: 'Notifications', onTap: () => _showNotifications()),
                _MenuTile(icon: Icons.security_rounded, label: 'Security & Privacy', onTap: () => _go(Profile(userId: widget.userId))),
                const SizedBox(height: 20),

                // Finances section
                _SectionLabel('Finances'),
                _MenuTile(icon: Icons.fact_check_outlined, label: 'Financial Profile', subtitle: 'Update your income, goals & preferences', onTap: () => _go(OnboardingFlow(userId: widget.userId))),
                const SizedBox(height: 20),

                // Opportunities section
                _SectionLabel('Opportunities'),
                _MenuTile(icon: Icons.favorite_outline_rounded, label: 'Favourites', subtitle: 'Your saved payees', onTap: () => _go(Favourites(userId: widget.userId))),
                const SizedBox(height: 20),

                // Support section
                _SectionLabel('Support'),
                _MenuTile(icon: Icons.help_outline_rounded, label: 'Help Centre', onTap: () => _showHelpCentre()),
                _MenuTile(icon: Icons.info_outline_rounded, label: 'About Nebo', onTap: () => _showAbout()),
                const SizedBox(height: 20),

                // Sign out
                GestureDetector(
                  onTap: _logout,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                        SizedBox(width: 10),
                        Text('Sign Out', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text('Nebo v1.0.0 • Licensed by CBK', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initials() => Container(
        color: AppColors.financeGreenV2,
        child: Center(
          child: Text(
            _name.isNotEmpty ? _name[0].toUpperCase() : 'N',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32),
          ),
        ),
      );

  void _go(Widget page) => Navigator.push(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ));

  Future<void> _showNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    var payments   = prefs.getBool(_kNotifPayments)   ?? true;
    var savings    = prefs.getBool(_kNotifSavings)    ?? true;
    var goals      = prefs.getBool(_kNotifGoals)      ?? true;
    var promotions = prefs.getBool(_kNotifPromotions) ?? false;

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSS) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Notification Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose what you want to be notified about',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              ),
            ),
            const SizedBox(height: 16),
            _NotifTile(
              icon: Icons.receipt_long_rounded,
              title: 'Payments & Transactions',
              subtitle: 'Receipts for every payment you make',
              value: payments,
              onChanged: (v) async {
                setSS(() => payments = v);
                await prefs.setBool(_kNotifPayments, v);
              },
            ),
            _NotifTile(
              icon: Icons.savings_rounded,
              title: 'Savings Activity',
              subtitle: 'When round-up savings are credited',
              value: savings,
              onChanged: (v) async {
                setSS(() => savings = v);
                await prefs.setBool(_kNotifSavings, v);
              },
            ),
            _NotifTile(
              icon: Icons.flag_rounded,
              title: 'Goal Milestones',
              subtitle: 'Progress updates on your savings goals',
              value: goals,
              onChanged: (v) async {
                setSS(() => goals = v);
                await prefs.setBool(_kNotifGoals, v);
              },
            ),
            _NotifTile(
              icon: Icons.campaign_rounded,
              title: 'Promotions & Tips',
              subtitle: 'Financial tips and Nebo updates',
              value: promotions,
              onChanged: (v) async {
                setSS(() => promotions = v);
                await prefs.setBool(_kNotifPromotions, v);
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _showHelpCentre() => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (sheetCtx, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(sheetCtx).padding.bottom + 32),
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Text('Help Centre', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                const SizedBox(height: 4),
                const Text('Answers to common questions', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(height: 20),
                ..._faqs.map((f) => _FaqTile(question: f.$1, answer: f.$2)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.financeGreen.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Still need help?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF111827))),
                    const SizedBox(height: 4),
                    const Text('Our support team usually replies within a day.', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse('mailto:support@nebo.co.ke?subject=Nebo%20Support')),
                      child: Row(children: [
                        const Icon(Icons.email_outlined, color: AppColors.financeGreen, size: 18),
                        const SizedBox(width: 8),
                        const Text('support@nebo.co.ke', style: TextStyle(color: AppColors.financeGreen, fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      );

  static final List<(String, String)> _faqs = [
    ('How do I make a deposit?', 'Go to the Save tab and tap Deposit. Enter the amount and confirm via the M-Pesa STK push prompt on your phone.'),
    ('How do I withdraw money?', 'From the Save tab, tap Withdraw, choose the goal or wallet to withdraw from, enter the amount, and confirm.'),
    ('What is Round-Up Savings?', 'Round-Up rounds your everyday M-Pesa spending up to the nearest amount and saves the difference automatically into your chosen goal.'),
    ('How do I create a savings goal?', 'Tap the + button on the Save tab, name your goal, set a target amount and date, and Nebo will help you track progress.'),
    ('How does Debt Manager work?', 'Debt Manager tracks what you owe across loans and Fuliza, showing how much you\'ve repaid and what remains so you can plan repayments.'),
  ];

  void _showAbout() => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.savings_rounded, color: AppColors.financeGreen, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('About Nebo', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          content: const Text('Nebo helps you understand your money, manage debt, and build better financial habits — one smart decision at a time.\n\nVersion 1.0.0\nLicensed by CBK\nBuilt in Kenya 🇰🇪', style: TextStyle(fontSize: 13, height: 1.6)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF), letterSpacing: 1.2)),
      );
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFF111827))),
          iconColor: AppColors.financeGreen,
          collapsedIconColor: const Color(0xFF9CA3AF),
          children: [
            Text(answer, style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280), height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.label, required this.onTap, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.financeGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.financeGreen, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF111827))),
            if (subtitle != null)
              Text(subtitle!, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB), size: 20),
        ]),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _NotifTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.financeGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.financeGreen, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ])),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.financeGreen,
          activeTrackColor: AppColors.financeGreen.withValues(alpha: 0.35),
        ),
      ]),
    );
  }
}
