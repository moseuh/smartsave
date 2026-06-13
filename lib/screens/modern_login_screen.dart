// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/app_theme.dart';
import '../config/api_config.dart';
import '../screens/main_shell.dart';
import 'modern_signup_screen.dart';

class ModernLoginScreen extends StatefulWidget {
  const ModernLoginScreen({Key? key}) : super(key: key);

  @override
  State<ModernLoginScreen> createState() => _ModernLoginScreenState();
}

class _ModernLoginScreenState extends State<ModernLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailCtrl.text.trim().toLowerCase(),
          'password': _passCtrl.text,
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['status'] == 'success') {
        final userId = data['userId']?.toString() ?? '';
        final userName = data['user_name'] ?? '';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', userId);
        await prefs.setString('user_name', userName);
        await prefs.setString('email', _emailCtrl.text.trim());
        await prefs.setBool('is_logged_in', true);
        await prefs.setBool('profile_completed', true);
        if (!mounted) return;
        _go(MainShell(userId: userId));
      } else {
        _err(data['message'] ?? 'Login failed');
      }
    } catch (_) {
      _err('Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) { setState(() => _loading = false); return; }
      final auth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(accessToken: auth.accessToken, idToken: auth.idToken);
      final uc = await FirebaseAuth.instance.signInWithCredential(cred);
      final user = uc.user;
      if (user != null && mounted) {
        final res = await http.post(
          Uri.parse(ApiConfig.googleLogin),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': user.email, 'google_id': user.uid, 'name': user.displayName, 'photo_url': user.photoURL}),
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
          _err(data['message'] ?? 'Google sign-in failed');
        }
      }
    } catch (_) {
      _err('Google sign-in failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _go(Widget page) => Navigator.pushReplacement(
      context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400),
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
                    const SizedBox(height: 52),

                    // ── Logo ────────────────────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.financeGreen.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: SvgPicture.asset('assets/logo.svg', width: 72,
                                  colorFilter: const ColorFilter.mode(
                                      AppColors.financeGreen, BlendMode.srcIn)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text('Better Outcomes. Together.',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Heading ─────────────────────────────────────────────
                    const Text('Welcome back',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                            color: Color(0xFF111827), letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    const Text('Sign in to your account',
                        style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                    const SizedBox(height: 28),

                    // ── Form ────────────────────────────────────────────────
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _field(
                            ctrl: _emailCtrl,
                            label: 'Email address',
                            icon: Icons.email_outlined,
                            type: TextInputType.emailAddress,
                            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                          ),
                          const SizedBox(height: 14),
                          _field(
                            ctrl: _passCtrl,
                            label: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscure,
                            suffix: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppColors.financeGreen, size: 20),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                          ),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Forgot password?',
                                  style: TextStyle(color: AppColors.financeGreen,
                                      fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Sign in button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.financeGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _loading
                                  ? const SizedBox(height: 22, width: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : const Text('Sign In',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Divider
                          Row(children: [
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text('or continue with',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                          ]),
                          const SizedBox(height: 20),

                          // Google button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton(
                              onPressed: _loading ? null : _googleSignIn,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset('assets/google_logo.png', height: 22,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata,
                                          size: 26, color: Colors.red)),
                                  const SizedBox(width: 10),
                                  const Text('Continue with Google',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                                          color: Color(0xFF374151))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Sign up link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don't have an account? ",
                                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                              GestureDetector(
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const ModernSignUpScreen())),
                                child: const Text('Sign Up',
                                    style: TextStyle(color: AppColors.financeGreen,
                                        fontSize: 14, fontWeight: FontWeight.bold)),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDC2626))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
