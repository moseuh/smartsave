import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../constants/app_theme.dart';

const _kPinKey = 'txn_pin_hash';
const _kBioKey = 'txn_bio_enabled';
const _kLastActivity = 'txn_last_activity';
const _kSessionMs = 3 * 60 * 1000; // 3 minutes

class TransactionAuthService {
  static final _auth = LocalAuthentication();

  // ── PIN helpers ──────────────────────────────────────────────────────────────

  static String _hash(String pin) =>
      sha256.convert(utf8.encode(pin)).toString();

  static Future<bool> hasPin() async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(_kPinKey);
  }

  static Future<void> savePin(String pin) async {
    final h = _hash(pin);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPinKey, h);
    // Sync to backend (fire-and-forget — local copy is authoritative)
    final userId = p.getString('user_id') ?? '';
    if (userId.isNotEmpty) {
      try {
        await http.post(
          Uri.parse(ApiConfig.getUrl('user/save-pin')),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': userId, 'pin_hash': h}),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
  }

  static Future<bool> checkPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kPinKey) == _hash(pin);
  }

  // ── Biometrics helpers ───────────────────────────────────────────────────────

  static Future<bool> isBioAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isBioEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kBioKey) ?? false;
  }

  static Future<void> setBioEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kBioKey, v);
  }

  static Future<bool> authenticateBio() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Confirm your identity to proceed',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Bio auth error: ${e.code} — ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Bio auth error: $e');
      return false;
    }
  }

  // ── Session activity tracking ────────────────────────────────────────────────

  static Future<void> touchActivity() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastActivity, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<bool> isSessionExpired() async {
    final pinSet = await hasPin();
    if (!pinSet) return false; // no PIN yet — don't lock
    final p = await SharedPreferences.getInstance();
    final last = p.getInt(_kLastActivity) ?? 0;
    if (last == 0) return true; // never recorded — lock
    return DateTime.now().millisecondsSinceEpoch - last > _kSessionMs;
  }

  // ── Main gate — call before any transaction ──────────────────────────────────
  // Fingerprint first (if enabled), otherwise PIN sheet.
  // Returns true if authenticated, false if cancelled/failed.

  static Future<bool> authenticate(BuildContext context) async {
    final pinSet = await hasPin();
    if (!context.mounted) return false;

    // No PIN yet — first-time setup
    if (!pinSet) {
      final set = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _SetupPinSheet(),
      );
      return set == true;
    }

    // Try biometrics silently first if enabled
    final bioEnabled = await isBioEnabled();
    final bioAvail = bioEnabled && await isBioAvailable();
    if (bioAvail) {
      final ok = await authenticateBio();
      if (ok) return true;
      // Bio failed/cancelled — fall through to PIN sheet
    }

    if (!context.mounted) return false;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AuthSheet(),
    );
    return ok == true;
  }
}

// ── Setup PIN Sheet ───────────────────────────────────────────────────────────

class _SetupPinSheet extends StatefulWidget {
  const _SetupPinSheet();

  @override
  State<_SetupPinSheet> createState() => _SetupPinSheetState();
}

class _SetupPinSheetState extends State<_SetupPinSheet> {
  final _pin1 = ValueNotifier('');
  final _pin2 = ValueNotifier('');
  bool _confirming = false;
  String? _error;

  void _onDigit(String d) {
    if (_confirming) {
      if (_pin2.value.length < 4) _pin2.value += d;
      if (_pin2.value.length == 4) _submit();
    } else {
      if (_pin1.value.length < 4) {
        _pin1.value += d;
        if (_pin1.value.length == 4) setState(() => _confirming = true);
      }
    }
  }

  void _onBack() {
    if (_confirming) {
      if (_pin2.value.isNotEmpty) {
        _pin2.value = _pin2.value.substring(0, _pin2.value.length - 1);
      } else {
        setState(() { _confirming = false; _pin1.value = ''; _error = null; });
      }
    } else {
      if (_pin1.value.isNotEmpty) _pin1.value = _pin1.value.substring(0, _pin1.value.length - 1);
    }
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _submit() async {
    final p1 = _pin1.value;
    final p2 = _pin2.value;
    if (p1 != p2) {
      _pin1.value = '';
      _pin2.value = '';
      setState(() { _error = 'PINs do not match. Try again.'; _confirming = false; });
      return;
    }
    await TransactionAuthService.savePin(p1);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return _PinSheetScaffold(
      title: _confirming ? 'Confirm PIN' : 'Create Transaction PIN',
      subtitle: _confirming ? 'Enter your PIN again to confirm' : 'This PIN protects all your transactions',
      pin: _confirming ? _pin2 : _pin1,
      error: _error,
      onDigit: _onDigit,
      onBack: _onBack,
      onClose: () => Navigator.pop(context, false),
      showBio: false,
      onBio: null,
    );
  }
}

// ── Auth Sheet (PIN or biometrics) ────────────────────────────────────────────

class _AuthSheet extends StatefulWidget {
  const _AuthSheet();

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
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
    setState(() { _bioAvailable = avail; _bioEnabled = enabled; });
    if (avail && enabled) _tryBio();
  }

  Future<void> _tryBio() async {
    final ok = await TransactionAuthService.authenticateBio();
    if (ok && mounted) Navigator.pop(context, true);
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
      Navigator.pop(context, true);
    } else {
      _pin.value = '';
      setState(() => _error = 'Incorrect PIN. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PinSheetScaffold(
      title: 'Confirm Transaction',
      subtitle: 'Enter your PIN to proceed',
      pin: _pin,
      error: _error,
      onDigit: _onDigit,
      onBack: _onBack,
      onClose: () => Navigator.pop(context, false),
      showBio: _bioAvailable && _bioEnabled,
      onBio: _tryBio,
    );
  }
}

// ── Shared PIN sheet UI ───────────────────────────────────────────────────────

class _PinSheetScaffold extends StatelessWidget {
  final String title, subtitle;
  final ValueNotifier<String> pin;
  final String? error;
  final void Function(String) onDigit;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final bool showBio;
  final VoidCallback? onBio;

  const _PinSheetScaffold({
    required this.title,
    required this.subtitle,
    required this.pin,
    required this.error,
    required this.onDigit,
    required this.onBack,
    required this.onClose,
    required this.showBio,
    required this.onBio,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom + mq.padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),

          // Close button
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                onPressed: onClose,
              ),
            ),
          ),

          // Lock icon
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppColors.financeGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline_rounded, color: AppColors.financeGreen, size: 30),
          ),
          const SizedBox(height: 16),

          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 28),

          // PIN dots
          ValueListenableBuilder<String>(
            valueListenable: pin,
            builder: (_, val, __) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 18, height: 18,
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

          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],

          const SizedBox(height: 28),

          // Keypad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                _KeyRow(['1', '2', '3'], onDigit),
                const SizedBox(height: 12),
                _KeyRow(['4', '5', '6'], onDigit),
                const SizedBox(height: 12),
                _KeyRow(['7', '8', '9'], onDigit),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Bio or blank
                    SizedBox(
                      width: 72, height: 56,
                      child: showBio
                          ? _KeyBtn(
                              onTap: onBio,
                              child: const Icon(Icons.fingerprint, size: 28, color: AppColors.financeGreen),
                            )
                          : const SizedBox.shrink(),
                    ),
                    _KeyBtn(label: '0', onTap: () => onDigit('0')),
                    _KeyBtn(
                      onTap: onBack,
                      child: const Icon(Icons.backspace_outlined, size: 22, color: Color(0xFF374151)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  final List<String> labels;
  final void Function(String) onTap;
  const _KeyRow(this.labels, this.onTap);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: labels.map((l) => _KeyBtn(label: l, onTap: () => onTap(l))).toList(),
  );
}

class _KeyBtn extends StatelessWidget {
  final String? label;
  final Widget? child;
  final VoidCallback? onTap;
  const _KeyBtn({this.label, this.child, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 72, height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: label != null
            ? Text(label!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF111827)))
            : child,
      ),
    ),
  );
}
