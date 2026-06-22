// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../constants/app_theme.dart';
import '../config/api_config.dart';
import 'main_shell.dart';

class ModernSignUpScreen extends StatefulWidget {
  const ModernSignUpScreen({Key? key}) : super(key: key);

  @override
  State<ModernSignUpScreen> createState() => _ModernSignUpScreenState();
}

class _ModernSignUpScreenState extends State<ModernSignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String _phoneNumber = '';
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Sign Up ────────────────────────────────────────────────────────────────
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.register),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim().toLowerCase(),
          'phone_number': _phoneNumber,
          'password': _passCtrl.text,
          'date_of_birth': '1990-01-01',
          'national_id': 'PENDING',
        }),
      );
      final data = jsonDecode(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) &&
          data['status'] == 'success') {
        final userId = data['userId']?.toString() ?? '';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', userId);
        await prefs.setString('user_name', _nameCtrl.text.trim());
        await prefs.setString('email', _emailCtrl.text.trim());
        await prefs.setBool('is_logged_in', true);
        await prefs.setBool('profile_completed', true);
        if (!mounted) return;
        _success('Account created!');
        await Future.delayed(const Duration(milliseconds: 600));
        _go(MainShell(userId: userId));
      } else {
        _err(data['message'] ?? 'Sign up failed');
      }
    } catch (_) {
      _err('Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignUp() async {
    setState(() => _loading = true);
    try {
      final googleUser = await GoogleSignIn(
        serverClientId: '1020426440691-2h1lkmu995u590m9rh6g1ffbrktmaa4v.apps.googleusercontent.com',
      ).signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }
      final auth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(
          accessToken: auth.accessToken, idToken: auth.idToken);
      final uc = await FirebaseAuth.instance.signInWithCredential(cred);
      final user = uc.user;
      if (user != null && mounted) {
        final res = await http.post(
          Uri.parse(ApiConfig.googleLogin),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': user.email,
            'google_id': user.uid,
            'name': user.displayName,
            'photo_url': user.photoURL
          }),
        );
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', data['userId'].toString());
          await prefs.setString('user_name', user.displayName ?? '');
          await prefs.setString('email', user.email ?? '');
          await prefs.setBool('is_logged_in', true);
          await prefs.setBool('profile_completed', true);
          if (!mounted) return;
          _go(MainShell(userId: data['userId'].toString()));
        } else {
          _err(data['message'] ?? 'Google sign-up failed');
        }
      }
    } catch (e) {
      _err(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _go(Widget page) => Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ));

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _success(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: AppColors.financeGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── Back button ──────────────────────────────────────
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20, color: Color(0xFF374151)),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),

                    // ── Logo ─────────────────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.financeGreen.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: SvgPicture.asset('assets/logo.svg',
                                  width: 48,
                                  colorFilter: const ColorFilter.mode(
                                      AppColors.financeGreen, BlendMode.srcIn)),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Heading ──────────────────────────────────────────
                    const Text('Create account',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                            letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    const Text('Sign up to get started',
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                    const SizedBox(height: 28),

                    // ── Form ─────────────────────────────────────────────
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _field(
                            ctrl: _nameCtrl,
                            label: 'Full name',
                            icon: Icons.person_outline_rounded,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter your full name'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          _field(
                            ctrl: _emailCtrl,
                            label: 'Email address',
                            icon: Icons.email_outlined,
                            type: TextInputType.emailAddress,
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Enter a valid email'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          // ── Phone field ──────────────────────────────
                          IntlPhoneField(
                            decoration: InputDecoration(
                              labelText: 'Phone number',
                              labelStyle: const TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 14),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB))),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB))),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: AppColors.financeGreen,
                                      width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                            ),
                            style: const TextStyle(
                                fontSize: 15, color: Color(0xFF111827)),
                            dropdownTextStyle: const TextStyle(
                                fontSize: 15, color: Color(0xFF111827)),
                            dropdownIcon: const Icon(Icons.arrow_drop_down,
                                color: Color(0xFF9CA3AF), size: 18),
                            initialCountryCode: 'KE',
                            disableLengthCheck: true,
                            flagsButtonPadding:
                                const EdgeInsets.only(left: 12, right: 4),
                            onChanged: (phone) =>
                                _phoneNumber = phone.completeNumber,
                          ),
                          const SizedBox(height: 14),

                          _field(
                            ctrl: _passCtrl,
                            label: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePass,
                            suffix: IconButton(
                              icon: Icon(
                                  _obscurePass
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.financeGreen,
                                  size: 20),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                            ),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Minimum 6 characters'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          _field(
                            ctrl: _confirmCtrl,
                            label: 'Confirm password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscureConfirm,
                            suffix: IconButton(
                              icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.financeGreen,
                                  size: 20),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                            validator: (v) => v != _passCtrl.text
                                ? 'Passwords do not match'
                                : null,
                          ),
                          const SizedBox(height: 28),

                          // Create account button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _signUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.financeGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5))
                                  : const Text('Create Account',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Divider
                          Row(children: [
                            Expanded(
                                child: Divider(color: Colors.grey.shade300)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Text('or',
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                            ),
                            Expanded(
                                child: Divider(color: Colors.grey.shade300)),
                          ]),
                          const SizedBox(height: 20),

                          // Google button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton(
                              onPressed: _loading ? null : _googleSignUp,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                    color: Color(0xFFE5E7EB), width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset('assets/google_logo.png',
                                      height: 22,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.g_mobiledata,
                                          size: 26,
                                          color: Colors.red)),
                                  const SizedBox(width: 10),
                                  const Text('Sign up with Google',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF374151))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Sign in link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Already have an account? ',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280), fontSize: 14)),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text('Sign In',
                                    style: TextStyle(
                                        color: AppColors.financeGreen,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType? type,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.financeGreen, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.financeGreen, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDC2626))),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
