import 'package:flutter/material.dart';
import 'landingpage.dart';
import 'sign_in_screen.dart' as signIn;

// === YOUR REAL PAGES ===
import 'wallet_page.dart';
import 'jobs_page.dart';
import 'profile.dart';
import 'loans_credit_score.dart';
import 'till.dart';
import 'buygoodselect.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  final String? userId;
  const HomePage({super.key, this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late String? currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = widget.userId;
  }

  void _handleSuccessfulLogin(String userId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomePage(userId: userId)),
    );
  }

  void _openPage(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _comingSoonPage(String title) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: const Color(0xFF1E293B), title: Text(title, style: const TextStyle(color: Colors.white))),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 80, color: Color(0xFFF59E0B)),
            SizedBox(height: 20),
            Text('Coming Soon', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            Text('This feature is under development', style: TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // === Hero Section ===
            Container(
              width: double.infinity,
              height: 460,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/landing.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.dstATop), // Fixed: Colors.black
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF000000), Colors.transparent],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Haba na Haba\nSmart Savings Made Simple',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, height: 1.1)),
                    const SizedBox(height: 16),
                    const Text('Join millions of users who save smarter\nwith automated tools and intelligent insights',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 16, height: 1.5)),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const signIn.SignInScreen()),
                            );
                            if (result is String) {
                              _handleSuccessfulLogin(result);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          ),
                          child: const Text('Get Started', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LandingPage())),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white, width: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          ),
                          child: const Text('Learn More', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // === KEY FEATURES: ROUND UPS, P2P LENDING, SMART INVESTMENTS ===
            Container(
              width: double.infinity,
              color: const Color(0xFF1E293B),
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                children: [
                  const Text('Key Features', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: FeatureIcon(
                          icon: Icons.autorenew_rounded,
                          title: 'Round Ups',
                          description: 'Save spare change automatically',
                          onTap: () => _openPage(_comingSoonPage('Round Ups')),
                        ),
                      ),
                      Expanded(
                        child: FeatureIcon(
                          icon: Icons.swap_horiz,
                          title: 'P2P Lending',
                          description: 'Lend & borrow from peers',
                          onTap: () => _openPage(currentUserId != null ? LoansCreditScore(userId: currentUserId!) : const signIn.SignInScreen()),
                        ),
                      ),
                      Expanded(
                        child: FeatureIcon(
                          icon: Icons.trending_up,
                          title: 'Smart Investments',
                          description: 'Grow your money intelligently',
                          onTap: () => _openPage(_comingSoonPage('Smart Investments')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            buildQuickAccessSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // === QUICK ACCESS (same clean design) ===
  Widget buildQuickAccessSection() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          const Text('Quick Access', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: FeatureIcon(
                  icon: Icons.account_balance,
                  title: 'Loans',
                  description: 'Quick credit access',
                  onTap: () => _openPage(currentUserId != null ? LoansCreditScore(userId: currentUserId!) : const signIn.SignInScreen()),
                ),
              ),
              Expanded(
                child: FeatureIcon(
                  icon: Icons.storefront,
                  title: 'Till',
                  description: 'Business payments',
                  onTap: () => _openPage(const TillFavourites()),
                ),
              ),
              Expanded(
                child: FeatureIcon(
                  icon: Icons.account_balance_wallet,
                  title: 'Wallet',
                  description: 'Your balance',
                  onTap: () => _openPage(currentUserId != null ? WalletPage(userId: currentUserId!) : const signIn.SignInScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: FeatureIcon(
                  icon: Icons.work,
                  title: 'Jobs',
                  description: 'Find opportunities',
                  onTap: () => _openPage(currentUserId != null ? JobsPage(userId: currentUserId!) : const signIn.SignInScreen()),
                ),
              ),
              Expanded(
                child: FeatureIcon(
                  icon: Icons.school,
                  title: 'Scholarships',
                  description: 'Education funding',
                  onTap: () => _openPage(_comingSoonPage('Scholarships')),
                ),
              ),
              Expanded(
                child: FeatureIcon(
                  icon: Icons.person,
                  title: 'Profile',
                  description: 'Manage account',
                  onTap: () => _openPage(currentUserId != null ? Profile(userId: currentUserId!) : const signIn.SignInScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// === REUSABLE ICON WITH TAP ===
class FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const FeatureIcon({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF4B5563),
              radius: 30,
              child: Icon(icon, color: const Color(0xFFF59E0B), size: 30),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}