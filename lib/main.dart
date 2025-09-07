// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'sign_in_screen.dart';
import 'homepage.dart';
import 'dart:async';

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/sign_in': (context) => const SignInScreen(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const HomePage();
        }
        return const SignInScreen();
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

    // Navigate to AuthWrapper after 3 seconds
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
        );
      }
    });

    // Dispose the controller when navigation occurs
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _controller.dispose();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose(); // Ensure disposal if not already handled
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4B5563), // Fintech-themed dark grayish-blue
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Spread content vertically
          children: [
            const SizedBox(height: 20), // Spacer at the top
            Image.asset(
              'assets/logo.png', // Logo without enclosing container
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.account_balance, size: 120, color: Colors.white),
            ),
            Column(
              children: [
                const SizedBox(height: 20),
                SizedBox(
                  width: 200, // Fixed width for progress bar
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: _progressAnimation.value,
                        backgroundColor: Colors.grey[700],
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)), // Gold progress
                        minHeight: 8,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Empowering Your Finances...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter', // Fallback to Roboto
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Color(0xFFD4AF37), // Gold shadow
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}