// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'screens/modern_login_screen.dart';
import 'screens/homepage.dart';
import 'screens/main_shell.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'providers/wallet_provider.dart';
import 'constants/app_theme.dart';
import 'widgets/session_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      debugPrint('Firebase init failed: $e');
    }
  }

  // OneSignal
  OneSignal.initialize('3a49f279-28c0-4202-8295-40803253b8b7');
  OneSignal.Notifications.requestPermission(true);

  runApp(const MainApp());
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Failed to initialize app')),
      ),
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Nebo',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: const SplashScreen(),
        routes: {
          '/sign_in': (context) => const ModernLoginScreen(),
          '/home': (context) => const HomePage(),
        },
        builder: (context, child) => SessionGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<Widget> _getInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    if (!isLoggedIn) return const ModernLoginScreen();
    final userId = prefs.getString('user_id') ?? '';
    if (userId.isEmpty) return const ModernLoginScreen();
    return MainShell(userId: userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getInitialScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data ?? const ModernLoginScreen();
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late AnimationController _barCtrl;
  late Timer _timer;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _taglineFade;
  late Animation<double> _barProgress;

  @override
  void initState() {
    super.initState();

    // Main: logo pops in (0–600ms), text slides up (400–900ms)
    _mainCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    _logoScale = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack)),
    );
    _logoFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _taglineFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.65, 1.0, curve: Curves.easeOut)),
    );

    // Loading bar fills over 2.2s
    _barCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _barProgress = CurvedAnimation(parent: _barCtrl, curve: Curves.easeInOut);

    _mainCtrl.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _barCtrl.forward();
    });

    _timer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AuthWrapper(),
            transitionsBuilder: (_, a, __, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _mainCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight, // #F2F7F2 — same as home
      body: SafeArea(
        child: Stack(
          children: [
            // ── Subtle top-right green circle ─────────────────────────
            Positioned(
              top: -size.width * 0.25,
              right: -size.width * 0.25,
              child: Container(
                width: size.width * 0.65,
                height: size.width * 0.65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.financeGreenV3.withValues(alpha: 0.07),
                ),
              ),
            ),
            // ── Subtle bottom-left circle ──────────────────────────────
            Positioned(
              bottom: -size.width * 0.2,
              left: -size.width * 0.2,
              child: Container(
                width: size.width * 0.55,
                height: size.width * 0.55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.financeGreen.withValues(alpha: 0.05),
                ),
              ),
            ),

            // ── Main content ──────────────────────────────────────────
            Column(
              children: [
                const Spacer(flex: 5),

                // Wordmark SVG — centered, big
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: SvgPicture.asset(
                      'assets/logo-green-word.svg',
                      width: 220,
                    ),
                  ),
                ),

                const Spacer(flex: 5),

                // Progress bar
                FadeTransition(
                  opacity: _taglineFade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _barProgress,
                          builder: (_, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _barProgress.value,
                              backgroundColor: AppColors.coreWhiteW2,
                              valueColor: const AlwaysStoppedAnimation(AppColors.financeGreenV3),
                              minHeight: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ],
        ),
      ),
    );
  }
}