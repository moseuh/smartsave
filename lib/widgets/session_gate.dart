import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/transaction_auth_service.dart';
import '../constants/app_theme.dart';

/// Wraps the entire app. On every pointer event it resets the inactivity timer.
/// When the session expires it overlays a lock screen requiring PIN/biometric.
/// First use: after PIN is created, offers biometric enrollment once.
class SessionGate extends StatefulWidget {
  final Widget child;
  const SessionGate({super.key, required this.child});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> with WidgetsBindingObserver {
  bool _locked = false;
  Timer? _idleTimer;
  bool _checkingLock = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final expired = await TransactionAuthService.isSessionExpired();
    if (mounted) setState(() { _locked = expired; _checkingLock = false; });
    if (!expired) _resetTimer();
  }

  void _resetTimer() {
    _idleTimer?.cancel();
    TransactionAuthService.touchActivity();
    _idleTimer = Timer(const Duration(minutes: 3), () {
      if (mounted) setState(() => _locked = true);
    });
  }

  void _onUserInteraction() {
    if (_locked) return; // don't reset while locked
    _resetTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      TransactionAuthService.touchActivity(); // record last activity time
      _idleTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _init(); // re-check on resume
    }
  }

  void _onUnlocked() {
    TransactionAuthService.touchActivity();
    setState(() => _locked = false);
    _resetTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingLock) return const SizedBox.shrink();
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onUserInteraction(),
      child: Stack(
        children: [
          widget.child,
          if (_locked) _LockOverlay(onUnlocked: _onUnlocked),
        ],
      ),
    );
  }
}

// ── Lock screen overlay ───────────────────────────────────────────────────────

class _LockOverlay extends StatefulWidget {
  final VoidCallback onUnlocked;
  const _LockOverlay({required this.onUnlocked});

  @override
  State<_LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends State<_LockOverlay> {
  final _pin = ValueNotifier('');
  String? _error;
  bool _bioAvailable = false;
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    _initBio();
  }

  Future<void> _initBio() async {
    final avail = await TransactionAuthService.isBioAvailable();
    final enabled = await TransactionAuthService.isBioEnabled();
    if (mounted) setState(() { _bioAvailable = avail; _bioEnabled = enabled; });
    if (avail && enabled) _tryBio();
  }

  Future<void> _tryBio() async {
    final ok = await TransactionAuthService.authenticateBio();
    if (ok && mounted) widget.onUnlocked();
  }

  void _onDigit(String d) {
    if (_pin.value.length < 4) {
      _pin.value += d;
      if (_error != null) setState(() => _error = null);
      if (_pin.value.length == 4) _checkPin();
    }
  }

  void _onBack() {
    if (_pin.value.isNotEmpty) {
      _pin.value = _pin.value.substring(0, _pin.value.length - 1);
      if (_error != null) setState(() => _error = null);
    }
  }

  Future<void> _checkPin() async {
    final entered = _pin.value;
    final ok = await TransactionAuthService.checkPin(entered);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      _pin.value = '';
      setState(() => _error = 'Incorrect PIN');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Column(children: [
          const SizedBox(height: 48),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.financeGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded, color: AppColors.financeGreen, size: 34),
          ),
          const SizedBox(height: 20),
          const Text('Session Locked',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          const Text('Enter your PIN to continue',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          const SizedBox(height: 36),

          // PIN dots
          ValueListenableBuilder<String>(
            valueListenable: _pin,
            builder: (_, val, __) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < val.length ? AppColors.financeGreen : const Color(0xFFE5E7EB),
                  border: Border.all(
                    color: i < val.length ? AppColors.financeGreen : const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                ),
              )),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],

          const SizedBox(height: 36),

          // Keypad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(children: [
              _keyRow(['1', '2', '3']),
              const SizedBox(height: 14),
              _keyRow(['4', '5', '6']),
              const SizedBox(height: 14),
              _keyRow(['7', '8', '9']),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                SizedBox(
                  width: 76, height: 58,
                  child: (_bioAvailable && _bioEnabled)
                      ? _keyTile(
                          child: const Icon(Icons.fingerprint, size: 30, color: AppColors.financeGreen),
                          onTap: _tryBio,
                        )
                      : const SizedBox.shrink(),
                ),
                _keyTile(label: '0', onTap: () => _onDigit('0')),
                _keyTile(
                  child: const Icon(Icons.backspace_outlined, size: 22, color: Color(0xFF374151)),
                  onTap: _onBack,
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _keyRow(List<String> labels) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: labels.map((l) => _keyTile(label: l, onTap: () => _onDigit(l))).toList(),
  );

  Widget _keyTile({String? label, Widget? child, VoidCallback? onTap}) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 76, height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: label != null
            ? Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF111827)))
            : child,
      ),
    ),
  );
}

// ── Biometric enrollment prompt ───────────────────────────────────────────────
// Call once after first PIN creation to offer biometric opt-in.

class BiometricEnrollPrompt extends StatelessWidget {
  const BiometricEnrollPrompt({super.key});

  static Future<void> showIfApplicable(BuildContext context) async {
    final pinSet = await TransactionAuthService.hasPin();
    if (!pinSet) return;
    final bioAvail = await TransactionAuthService.isBioAvailable();
    if (!bioAvail) return;
    final bioEnabled = await TransactionAuthService.isBioEnabled();
    if (bioEnabled) return; // already opted in
    // Check if we've already asked
    final p = await SharedPreferences.getInstance();
    if (p.getBool('bio_enroll_asked') == true) return;
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const BiometricEnrollPrompt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 24),
        Container(
          width: 68, height: 68,
          decoration: BoxDecoration(
            color: AppColors.financeGreen.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.fingerprint, color: AppColors.financeGreen, size: 36),
        ),
        const SizedBox(height: 18),
        const Text('Enable Fingerprint Login?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        const SizedBox(height: 8),
        const Text(
          'Use your fingerprint or face instead of PIN to unlock the app and confirm payments.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final ok = await TransactionAuthService.authenticateBio();
              final p = await SharedPreferences.getInstance();
              await p.setBool('bio_enroll_asked', true);
              if (ok) await TransactionAuthService.setBioEnabled(true);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.financeGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Enable Fingerprint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () async {
            final p = await SharedPreferences.getInstance();
            await p.setBool('bio_enroll_asked', true);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Not now', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
        ),
      ]),
    );
  }
}
