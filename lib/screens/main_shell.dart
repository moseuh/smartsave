import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_theme.dart';
import '../widgets/session_gate.dart';
import '../services/tab_refresh_registry.dart';
import 'home_tab.dart';
import 'save_tab.dart';
import 'finance_tab.dart';
import 'loans_tab.dart';
import 'profile_tab.dart';

class MainShell extends StatefulWidget {
  final String userId;
  const MainShell({super.key, required this.userId});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _current = 0;
  late final List<Widget> _pages;

  late final List<AnimationController> _iconControllers;
  late final List<Animation<double>> _iconScales;

  static const _navItems = [
    _NavItem(icon: Icons.home_rounded,           label: 'Home'),
    _NavItem(icon: Icons.savings_rounded,         label: 'Save'),
    _NavItem(icon: Icons.bar_chart_rounded,       label: 'Finance'),
    _NavItem(icon: Icons.account_balance_rounded, label: 'Loans'),
    _NavItem(icon: Icons.person_rounded,          label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pages = [
      HomeTab(userId: widget.userId),
      SaveTab(userId: widget.userId),
      FinanceTab(userId: widget.userId),
      LoansTab(userId: widget.userId),
      ProfileTab(userId: widget.userId),
    ];

    _iconControllers = List.generate(
      _navItems.length,
      (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 200)),
    );
    _iconScales = _iconControllers
        .map((c) => Tween<double>(begin: 1.0, end: 1.25).animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();

    _iconControllers[0].forward();

    // Offer biometric enrollment once after first PIN setup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BiometricEnrollPrompt.showIfApplicable(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _iconControllers) c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      TabRefreshRegistry.refresh(_current);
    }
  }

  void _onTap(int index) {
    if (index == _current) {
      // Tapping the active tab refreshes it
      HapticFeedback.lightImpact();
      TabRefreshRegistry.refresh(_current);
      return;
    }
    HapticFeedback.lightImpact();
    _iconControllers[_current].reverse();
    _iconControllers[index].forward();
    setState(() => _current = index);
    TabRefreshRegistry.refresh(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: IndexedStack(index: _current, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.coreWhiteW2, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: List.generate(_navItems.length, (i) => Expanded(
                child: GestureDetector(
                  onTap: () => _onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedBuilder(
                    animation: _iconControllers[i],
                    builder: (_, __) => _NavPill(
                      item: _navItems[i],
                      selected: _current == i,
                      scale: _iconScales[i].value,
                    ),
                  ),
                ),
              )),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _NavPill extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final double scale;
  const _NavPill({required this.item, required this.selected, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.scale(
          scale: scale,
          child: Icon(
            item.icon,
            size: 24,
            color: selected ? AppColors.financeGreen : AppColors.coreDarkD2,
          ),
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.financeGreen : AppColors.coreDarkD2,
            letterSpacing: 0.2,
          ),
          child: Text(item.label),
        ),
        const SizedBox(height: 3),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: selected ? 20 : 0,
          height: 3,
          decoration: BoxDecoration(
            color: selected ? AppColors.financeGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
