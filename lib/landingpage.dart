import 'package:flutter/material.dart';
import 'sign_in_screen.dart';
import 'homepage.dart'; // Import HomePage (assumed from your previous code)

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Remove Roboto by overriding the default theme
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Arial', // Use a system font like Arial (available on most platforms)
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'Arial'),
          bodyLarge: TextStyle(fontFamily: 'Arial'),
          headlineSmall: TextStyle(fontFamily: 'Arial'),
          headlineMedium: TextStyle(fontFamily: 'Arial'),
          titleLarge: TextStyle(fontFamily: 'Arial'),
        ),
      ),
      home: const HomePage(), // Start with HomePage
    );
  }
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  _LandingPageState createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      body: Column(
        children: [
          // 🔹 Top Navigation Bar with Back Arrow
          Container(
            color: const Color(0xFF1F2937),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomePage()),
                    );
                  },
                ),
                const Text(
                  "My App",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(Icons.notifications, color: Colors.white),
              ],
            ),
          ),

          // 🔹 Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Image.asset(
                        'assets/background.png',
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                      const Positioned(
                        bottom: 30,
                        left: 20,
                        child: Text(
                          'Turn Every Spend Into\nSavings — Effortlessly!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'How It Works',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      FeatureCard(icon: Icons.phone_android, text: 'Make any\nmobile payment'),
                      FeatureCard(icon: Icons.savings, text: 'Round up to\nnearest 10, 50,\nor 100'),
                      FeatureCard(icon: Icons.auto_awesome, text: 'Auto-save the\ndifference'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Benefits',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const BenefitCard(),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'Perfect For African Dream Chasers',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: const [
                        ProfileCard(image: 'assets/business_leader.png', text: 'Business Leaders'),
                        ProfileCard(image: 'assets/market_trader.png', text: 'Market Traders'),
                        ProfileCard(image: 'assets/farmers.png', text: 'Smart Farmers'),
                        ProfileCard(image: 'assets/digital_creative.png', text: 'Digital Creatives'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 🔹 Start Now Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignInScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5BB1B),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        minimumSize: const Size(double.infinity, 50), // Full-width button
                      ),
                      child: const Text(
                        'START NOW',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 20.0),
                    child: Center(
                      child: Text(
                        'Start saving like a pro today!',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🔹 FeatureCard Widget
class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const FeatureCard({required this.icon, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF374151), // Changed from 0xFF9CA3AF to 0xFF1F2937
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: 100,
        height: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.amber, size: 30),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// 🔹 BenefitCard Widget
class BenefitCard extends StatelessWidget {
  const BenefitCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        color: const Color(0xFF374151),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.edit, color: Colors.amber),
              SizedBox(height: 8),
              Text(
                'Effortless Savings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Save automatically with every purchase you make, no extra effort required.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🔹 ProfileCard Widget
class ProfileCard extends StatelessWidget {
  final String image;
  final String text;
  const ProfileCard({required this.image, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF374151).withOpacity(1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Image.asset(
            image,
            width: 150,
            height: 120,
            fit: BoxFit.cover,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}