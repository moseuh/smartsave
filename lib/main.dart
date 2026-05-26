// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'firebase_options.dart';
import 'screens/modern_login_screen.dart';
import 'screens/homepage.dart';
import 'screens/main_shell.dart';
import 'screens/profile_completion_screen.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'providers/wallet_provider.dart';
import 'constants/app_theme.dart';
import 'constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MainApp());
  } catch (e) {
    print('Firebase initialization failed: $e');
    runApp(const ErrorApp());
  }
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
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<Widget> _getInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    if (!isLoggedIn) {
      return const ModernLoginScreen();
    }

    final userId = prefs.getString('user_id') ?? '';
    final userName = prefs.getString('user_name') ?? '';
    final userEmail = prefs.getString('email') ?? '';

    if (userId.isEmpty) {
      return const ModernLoginScreen();
    }

    // Check if we already know profile is complete
    final profileCompleted = prefs.getBool('profile_completed') ?? false;
    if (profileCompleted) {
      return MainShell(userId: userId);
    }

    // Verify with backend whether basics are already filled in
    try {
      final isComplete = await _checkProfileCompletion(userId);
      if (isComplete) {
        await prefs.setBool('profile_completed', true);
        return MainShell(userId: userId);
      }
    } catch (_) {
      // If backend unreachable, fall through to profile completion
    }

    return ProfileCompletionScreen(
      userId: userId,
      userName: userName,
      userEmail: userEmail,
    );
  }

  Future<bool> _checkProfileCompletion(String userId) async {
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/user-details/$userId');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final d = data['data'];
          final nationalId = (d['national_id'] ?? '').toString();
          final dob = (d['date_of_birth'] ?? '').toString();
          return nationalId.isNotEmpty &&
              nationalId != 'PENDING' &&
              dob.isNotEmpty &&
              dob != '1990-01-01';
        }
      }
    } catch (_) {}
    return false;
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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  late Timer _timer;

  @override
  void initState() {
    super.initState();

    // Animation Controller for progress bar (3 seconds)
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..forward();

    // Progress Animation from 0.0 to 1.0
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    // Navigate to AuthWrapper to check authentication status
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.financeGreen,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Image.asset(
                'assets/logo.png',
                width: 140,
                height: 140,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.account_balance, size: 140, color: Colors.white),
              ),
              const Spacer(flex: 3),
              Column(
                children: [
                  SizedBox(
                    width: 200,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return LinearProgressIndicator(
                          value: _progressAnimation.value,
                          backgroundColor: AppColors.financeGreenV2,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.financeGreenV3),
                          minHeight: 8,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Empowering Your Finances...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: AppColors.financeGreenV3,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}