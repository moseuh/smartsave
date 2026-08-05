import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_theme.dart';
import '../config/api_config.dart';

const Map<String, IconData> _categoryIcons = {
  'credit_card': Icons.credit_card_rounded,
  'groups': Icons.groups_rounded,
  'trending_up': Icons.trending_up_rounded,
  'bar_chart': Icons.bar_chart_rounded,
  'shield': Icons.shield_rounded,
  'lock_clock': Icons.lock_clock_rounded,
  'currency_exchange': Icons.currency_exchange_rounded,
};

IconData _iconFor(String? key) => _categoryIcons[key] ?? Icons.category_rounded;

// Derives a logo image URL from the provider's website — avoids bundling
// or hosting third-party trademarked logo assets. Uses Google's favicon
// service (same infra Chrome uses), since logo.clearbit.com was
// decommissioned (its hostname no longer resolves at all). If this ever
// fails to load, _ProviderLogo falls back to the category icon.
String? _logoUrlFor(String? websiteUrl) {
  if (websiteUrl == null || websiteUrl.isEmpty) return null;
  final host = Uri.tryParse(websiteUrl)?.host;
  if (host == null || host.isEmpty) return null;
  final bareHost = host.startsWith('www.') ? host.substring(4) : host;
  return 'https://t1.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=https://$bareHost&size=128';
}

Future<void> _openWebsite(BuildContext context, String? websiteUrl) async {
  if (websiteUrl == null || websiteUrl.isEmpty) return;
  final uri = Uri.tryParse(websiteUrl);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }
}

class MarketplaceTab extends StatefulWidget {
  final String userId;
  const MarketplaceTab({super.key, required this.userId});

  @override
  State<MarketplaceTab> createState() => _MarketplaceTabState();
}

class _MarketplaceTabState extends State<MarketplaceTab> {
  bool _joining = false;
  bool _joined = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _listings = [];
  String? _selectedCategory; // null = All
  String _sort = 'recommended';
  bool _loadingCategories = true;
  bool _loadingListings = true;

  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadListings();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadListings);
  }

  Future<void> _loadCategories() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.getUrl('marketplace/categories')));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') {
          setState(() => _categories = List<Map<String, dynamic>>.from(d['data'] ?? []));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingCategories = false);
  }

  Future<void> _loadListings() async {
    setState(() => _loadingListings = true);
    try {
      final params = <String, String>{'sort': _sort};
      if (_selectedCategory != null) params['category'] = _selectedCategory!;
      if (_searchCtrl.text.trim().isNotEmpty) params['q'] = _searchCtrl.text.trim();
      final uri = Uri.parse(ApiConfig.getUrl('marketplace/listings')).replace(queryParameters: params);
      final r = await http.get(uri);
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') {
          setState(() => _listings = List<Map<String, dynamic>>.from(d['data'] ?? []));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingListings = false);
  }

  void _selectCategory(String? slug) {
    setState(() => _selectedCategory = slug);
    _loadListings();
  }

  void _changeSort(String sort) {
    setState(() => _sort = sort);
    _loadListings();
  }

  Future<void> _joinWaitlist({String? source}) async {
    setState(() => _joining = true);
    try {
      final userR = await http.get(Uri.parse(ApiConfig.userDetailsById(widget.userId)));
      String name = 'Nebo User';
      String email = '';
      if (userR.statusCode == 200) {
        final d = jsonDecode(userR.body);
        final u = d['data'] ?? {};
        name = (u['full_name']?.toString().isNotEmpty ?? false) ? u['full_name'].toString() : name;
        email = u['email']?.toString() ?? '';
      }
      if (email.isEmpty) {
        if (mounted) _snack('Add an email to your profile first to join the waitlist.');
        if (mounted) setState(() => _joining = false);
        return;
      }
      final r = await http.post(
        Uri.parse(ApiConfig.getUrl('waitlist')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'source': source ?? 'marketplace_teaser'}),
      );
      if (r.statusCode == 200 || r.statusCode == 409) {
        if (mounted) {
          setState(() => _joined = true);
          _snack("You're on the list — we'll notify you when Marketplace launches!");
        }
      } else {
        if (mounted) _snack('Something went wrong. Please try again.');
      }
    } catch (_) {
      if (mounted) _snack('Network error — please try again.');
    }
    if (mounted) setState(() => _joining = false);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.financeGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _openListing(Map<String, dynamic> listing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ListingDetailSheet(
        listing: listing,
        joining: _joining,
        joined: _joined,
        onJoinWaitlist: () => _joinWaitlist(source: 'marketplace_listing_${listing['id']}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // ── Shrunk hero ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B3D1F), Color(0xFF1B6631)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RichText(
                  text: const TextSpan(children: [
                    TextSpan(text: 'Nebo ', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                    TextSpan(text: 'Marketplace', style: TextStyle(color: Color(0xFF7CFFA0), fontSize: 17, fontWeight: FontWeight.w900)),
                  ]),
                ),
                const SizedBox(height: 3),
                const Text('Compare loans, savings & more.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _joining ? null : () => _joinWaitlist(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFD8FFE3), borderRadius: BorderRadius.circular(10)),
                child: _joining
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.financeGreen))
                    : Text(_joined ? 'Joined' : 'Notify me',
                        style: const TextStyle(color: Color(0xFF0B3D1F), fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Search box ────────────────────────────────────────────
        TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search banks, SACCOs, products...',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF9CA3AF)),
            suffixIcon: _searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF9CA3AF)),
                    onPressed: () { _searchCtrl.clear(); _loadListings(); },
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
          ),
        ),
        const SizedBox(height: 14),

        // ── Category filter chips ───────────────────────────────
        if (_loadingCategories)
          const SizedBox(height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.financeGreen)))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _CategoryChip(label: 'All', selected: _selectedCategory == null, onTap: () => _selectCategory(null)),
              ..._categories.map((c) => _CategoryChip(
                    label: c['name']?.toString() ?? '',
                    icon: _iconFor(c['icon']?.toString()),
                    selected: _selectedCategory == c['slug'],
                    onTap: () => _selectCategory(c['slug']?.toString()),
                  )),
            ]),
          ),
        const SizedBox(height: 14),

        // ── Sort control ─────────────────────────────────────────
        Row(children: [
          const Text('Sort:', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            initialValue: _sort,
            onSelected: _changeSort,
            offset: const Offset(0, 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'recommended', child: Text('Recommended')),
              PopupMenuItem(value: 'name', child: Text('Name A–Z')),
              PopupMenuItem(value: 'rate_desc', child: Text('Rate: High to Low')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_sortLabel(_sort), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF6B7280)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),

        // ── Listings grid ─────────────────────────────────────────
        if (_loadingListings)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator(color: AppColors.financeGreen)),
          )
        else if (_listings.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(children: [
              Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade300),
              const SizedBox(height: 10),
              Text('No listings in this category yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ]),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              // Fixed pixel height (not an aspect ratio) so every card is
              // identical regardless of how much text/content it holds.
              crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 168,
            ),
            itemCount: _listings.length,
            itemBuilder: (_, i) => _ListingCard(listing: _listings[i], onTap: () => _openListing(_listings[i])),
          ),
      ],
    );
  }

  String _sortLabel(String sort) {
    switch (sort) {
      case 'name': return 'Name A–Z';
      case 'rate_desc': return 'Rate: High to Low';
      default: return 'Recommended';
    }
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  const _CategoryChip({required this.label, required this.selected, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.financeGreen : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? AppColors.financeGreen : const Color(0xFFE5E7EB)),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.financeGreen.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: selected ? Colors.white : const Color(0xFF6B7280)),
            const SizedBox(width: 5),
          ],
          Text(label, style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF6B7280),
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          )),
        ]),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> listing;
  final VoidCallback onTap;
  const _ListingCard({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isFeatured = listing['is_featured'] == true;
    return GestureDetector(
      onTap: onTap,
      child: Stack(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.max, children: [
            _ProviderLogo(
              websiteUrl: listing['website_url']?.toString(),
              fallbackIcon: _iconFor(listing['category_slug'] != null ? _iconKeyForSlug(listing['category_slug']) : null),
              height: 32,
              fullWidth: true,
            ),
            const SizedBox(height: 10),
            Text(listing['provider_name']?.toString() ?? '',
                style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(listing['product_name']?.toString() ?? '',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            if ((listing['headline_rate']?.toString() ?? '').isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(listing['headline_rate'].toString(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.financeGreen),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ]),
        ),
        if (isFeatured)
          Positioned(
            top: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: const BoxDecoration(
                color: Color(0xFFF59E0B),
                borderRadius: BorderRadius.only(topRight: Radius.circular(16), bottomLeft: Radius.circular(10)),
              ),
              child: const Text('Recommended', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
  }
}

class _ProviderLogo extends StatelessWidget {
  final String? websiteUrl;
  final IconData fallbackIcon;
  // Square mode (used in the detail sheet, next to text in a Row).
  final double? size;
  // Full-width mode (used on grid cards): spans the card, capped to [height].
  final double? height;
  final bool fullWidth;
  const _ProviderLogo({
    required this.websiteUrl,
    required this.fallbackIcon,
    this.size,
    this.height,
    this.fullWidth = false,
  }) : assert(size != null || height != null);

  @override
  Widget build(BuildContext context) {
    final logoUrl = _logoUrlFor(websiteUrl);
    final boxHeight = size ?? height!;
    final iconSize = boxHeight * 0.53;
    final content = logoUrl == null
        ? Icon(fallbackIcon, color: AppColors.financeGreen, size: iconSize)
        : Image.network(
            logoUrl,
            // Brand logos are usually wide wordmarks, not square icons —
            // contain (not cover) so the whole mark is visible, not cropped.
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: AppColors.financeGreen, size: iconSize),
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : Icon(fallbackIcon, color: AppColors.financeGreen, size: iconSize),
          );

    return Container(
      width: fullWidth ? double.infinity : boxHeight,
      height: boxHeight,
      alignment: fullWidth ? Alignment.centerLeft : Alignment.center,
      padding: EdgeInsets.all(boxHeight * 0.1),
      decoration: BoxDecoration(
        color: AppColors.financeGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(fullWidth ? 10 : boxHeight * 0.3),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

// Reverse-lookup so listing cards can show the right category icon without
// a second network round-trip — listings carry category_slug, not icon key.
String? _iconKeyForSlug(String? slug) {
  const map = {
    'loans': 'credit_card',
    'saccos': 'groups',
    'money_market_funds': 'trending_up',
    'shares': 'bar_chart',
    'insurance': 'shield',
    'fixed_deposits': 'lock_clock',
    'forex': 'currency_exchange',
  };
  return map[slug];
}

class _ListingDetailSheet extends StatelessWidget {
  final Map<String, dynamic> listing;
  final bool joining, joined;
  final VoidCallback onJoinWaitlist;
  const _ListingDetailSheet({required this.listing, required this.joining, required this.joined, required this.onJoinWaitlist});

  String _fmtAmount(dynamic v) {
    final d = double.tryParse(v?.toString() ?? '');
    if (d == null) return '';
    return 'KES ${d.round()}';
  }

  @override
  Widget build(BuildContext context) {
    final minAmt = listing['min_amount'];
    final maxAmt = listing['max_amount'];
    String? amountRange;
    if (minAmt != null && maxAmt != null) {
      amountRange = '${_fmtAmount(minAmt)} – ${_fmtAmount(maxAmt)}';
    } else if (minAmt != null) {
      amountRange = 'From ${_fmtAmount(minAmt)}';
    } else if (maxAmt != null) {
      amountRange = 'Up to ${_fmtAmount(maxAmt)}';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            _ProviderLogo(
              websiteUrl: listing['website_url']?.toString(),
              fallbackIcon: _iconFor(_iconKeyForSlug(listing['category_slug']?.toString())),
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(listing['provider_name']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
              Text(listing['product_name']?.toString() ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            ])),
          ]),
          if ((listing['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(listing['description'].toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              if ((listing['rate_label']?.toString() ?? '').isNotEmpty)
                _detailRow(listing['rate_label'].toString(), listing['headline_rate']?.toString() ?? ''),
              if (amountRange != null) ...[
                const SizedBox(height: 8),
                _detailRow('Amount', amountRange),
              ],
              if ((listing['term_label']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                _detailRow(listing['term_label'].toString(), listing['term_value']?.toString() ?? ''),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(14)),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Expanded(child: Text(
                "This product isn't available to apply for directly yet. Join the waitlist and we'll notify you when it launches.",
                style: TextStyle(fontSize: 12, color: Color(0xFFD97706), height: 1.4),
              )),
            ]),
          ),
          const SizedBox(height: 20),
          if ((listing['website_url']?.toString() ?? '').isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openWebsite(context, listing['website_url']?.toString()),
                icon: const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.financeGreen),
                label: const Text('Visit website', style: TextStyle(color: AppColors.financeGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: AppColors.financeGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: joining ? null : onJoinWaitlist,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.financeGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: joining
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(joined ? "You're on the list" : 'Join the waitlist',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        ],
      );
}
