// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../constants/app_constants.dart';

class NotificationsScreen extends StatefulWidget {
  final String userId;
  const NotificationsScreen({super.key, required this.userId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = false; });
    try {
      final res = await http
          .get(Uri.parse('${AppConstants.apiBaseUrl}/notifications/${widget.userId}'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          setState(() {
            _notifs = List<Map<String, dynamic>>.from(data['data'] ?? []);
            _loading = false;
          });
          return;
        }
      }
      setState(() { _loading = false; _error = true; });
    } catch (_) {
      setState(() { _loading = false; _error = true; });
    }
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
        title: const Text('Notifications',
            style: TextStyle(color: Color(0xFF111827), fontSize: 19, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.financeGreen),
            onPressed: _fetch,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE5E7EB)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.financeGreen))
          : _error
              ? _buildError()
              : _notifs.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: AppColors.financeGreen,
                      onRefresh: _fetch,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _notifs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _NotifTile(notif: _notifs[i]),
                      ),
                    ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.financeGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded, color: AppColors.financeGreen, size: 38),
          ),
          const SizedBox(height: 16),
          const Text('No notifications yet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          const Text("You're all caught up!",
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          const Text('Could not load notifications',
              style: TextStyle(fontSize: 15, color: Color(0xFF6B7280))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetch,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.financeGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> notif;
  const _NotifTile({required this.notif});

  @override
  Widget build(BuildContext context) {
    final title = notif['title']?.toString() ?? 'Notification';
    final message = notif['message']?.toString() ?? '';
    final type = notif['type']?.toString() ?? 'general';
    final raw = notif['created_at']?.toString() ?? '';
    String timeStr = '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        timeStr = DateFormat('HH:mm').format(dt);
      } else if (now.difference(dt).inDays < 7) {
        timeStr = DateFormat('EEE HH:mm').format(dt);
      } else {
        timeStr = DateFormat('d MMM').format(dt);
      }
    } catch (_) {}

    final iconData = _iconFor(type);
    final color = _colorFor(type);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(iconData, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827))),
                    ),
                    if (timeStr.isNotEmpty)
                      Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  ],
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(message,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'transaction': return Icons.receipt_rounded;
      case 'deposit':     return Icons.arrow_downward_rounded;
      case 'withdraw':    return Icons.arrow_upward_rounded;
      case 'goal':        return Icons.flag_rounded;
      case 'loan':        return Icons.account_balance_rounded;
      case 'security':    return Icons.security_rounded;
      case 'promo':       return Icons.local_offer_rounded;
      default:            return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'transaction':
      case 'deposit':     return const Color(0xFF059669);
      case 'withdraw':    return const Color(0xFFDC2626);
      case 'goal':        return AppColors.financeGreen;
      case 'loan':        return const Color(0xFF7C3AED);
      case 'security':    return const Color(0xFFDC2626);
      case 'promo':       return const Color(0xFFF59E0B);
      default:            return AppColors.financeGreenV2;
    }
  }
}
