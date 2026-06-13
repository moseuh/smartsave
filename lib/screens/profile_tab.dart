import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_theme.dart';
import '../config/api_config.dart';
import 'profile.dart' show Profile;
import 'favourites.dart' show Favourites;
import 'modern_login_screen.dart';

class ProfileTab extends StatefulWidget {
  final String userId;
  const ProfileTab({super.key, required this.userId});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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
                _MenuTile(icon: Icons.notifications_none_rounded, label: 'Notifications', onTap: () {}),
                _MenuTile(icon: Icons.security_rounded, label: 'Security & Privacy', onTap: () {}),
                const SizedBox(height: 20),

                // Opportunities section
                _SectionLabel('Opportunities'),
                _MenuTile(icon: Icons.favorite_outline_rounded, label: 'Favourites', subtitle: 'Your saved payees', onTap: () => _go(Favourites(userId: widget.userId))),
                const SizedBox(height: 20),

                // Support section
                _SectionLabel('Support'),
                _MenuTile(icon: Icons.help_outline_rounded, label: 'Help Centre', onTap: () {}),
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
