import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';

class Favourites extends StatefulWidget {
  final String userId;
  const Favourites({super.key, required this.userId});

  @override
  State<Favourites> createState() => _FavouritesState();
}

class _FavouritesState extends State<Favourites> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await http.get(Uri.parse('${AppConstants.apiBaseUrl}/favourites/${widget.userId}'));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') {
          setState(() => _all = List<Map<String, dynamic>>.from(d['data']));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(int id) async {
    try {
      final r = await http.delete(Uri.parse('${AppConstants.apiBaseUrl}/favourites/$id'));
      if (r.statusCode == 200) {
        setState(() => _all.removeWhere((f) => f['id'] == id));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Removed from favourites'),
            backgroundColor: AppColors.financeGreen,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final goods = _all.where((f) => f['type'] == 'buy_goods').toList();
    final bills = _all.where((f) => f['type'] == 'pay_bill').toList();

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
        title: const Text('Saved Payees',
            style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE9F2EB),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(3),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.financeGreen,
                unselectedLabelColor: const Color(0xFF9CA3AF),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: 'Buy Goods (${goods.length})'),
                  Tab(text: 'Pay Bill (${bills.length})'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.financeGreen))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _FavList(items: goods, icon: Icons.store_rounded, onDelete: _delete),
                _FavList(items: bills, icon: Icons.receipt_long_rounded, onDelete: _delete),
              ],
            ),
    );
  }
}

class _FavList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final IconData icon;
  final void Function(int) onDelete;
  const _FavList({required this.items, required this.icon, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('Nothing saved yet', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Tap ♡ next to a till/paybill to save it',
              style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 13)),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final f = items[i];
        final isBuyGoods = f['type'] == 'buy_goods';
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppColors.financeGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.financeGreen, size: 20),
            ),
            title: Text(
              f['name']?.toString() ?? '',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  isBuyGoods ? 'Till: ${f['till_number']}' : 'Paybill: ${f['till_number']}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                if (!isBuyGoods && (f['account_number'] as String?)?.isNotEmpty == true)
                  Text('Account: ${f['account_number']}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
              onPressed: () => _confirmDelete(context, f),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Map<String, dynamic> f) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 32),
          const SizedBox(height: 12),
          Text('Remove ${f['name'] ?? 'this payee'}?',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          const Text('It will be removed from your saved payees.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () { Navigator.pop(context); onDelete(f['id'] as int); },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
          ]),
        ]),
      ),
    );
  }
}
