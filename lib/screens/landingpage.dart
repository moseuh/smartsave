import 'package:flutter/material.dart';
import 'modern_login_screen.dart';
import 'homepage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Arial'),
      home: const LandingPage(),
    );
  }
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      body: Column(
        children: [
          // Top Navigation
          Container(
            color: const Color(0xFF1F2937),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage())),
                ),
                const Text("Haba na Haba", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Icon(Icons.notifications, color: Colors.white),
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo and App Description
                  Center(
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          width: 120,
                          height: 120,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.account_balance, size: 120, color: Color(0xFFF5BB1B)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'SmartSave',
                          style: TextStyle(
                            color: Color(0xFFF5BB1B),
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32.0),
                          child: Text(
                            'Your intelligent financial companion. Save automatically, invest wisely, and build wealth effortlessly.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  Stack(
                    children: [
                      Image.asset('assets/background.png', width: double.infinity, height: 200, fit: BoxFit.cover),
                      const Positioned(
                        bottom: 30,
                        left: 20,
                        child: Text(
                          'Your Money Works Harder\nThan You Do',
                          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // How It Works
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('How It Works', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      FeatureCard(icon: Icons.phone_android, text: 'Spend with\nM-Pesa or Card'),
                      FeatureCard(icon: Icons.savings, text: 'Round Up &\nAuto-Save'),
                      FeatureCard(icon: Icons.trending_up, text: 'Your Savings\nGrow Daily'),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Live Credit Score + Savings Culture
                  Container(
                    width: double.infinity,
                    color: const Color(0xFF111827),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          'We Track Your Financial Health in Real-Time',
                          style: TextStyle(color: Color(0xFFF5BB1B), fontSize: 26, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Live Credit Score powered by over 1,800 data points',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildHighlightCard(icon: Icons.bar_chart, title: 'Live Credit Score', description: 'We analyse over 1,800 data points from your spending, savings, lending, and repayment behaviour — updated daily.'),
                            _buildHighlightCard(icon: Icons.celebration, title: 'Enjoy Life, We Save For You', description: 'We foster a savings culture without sacrifice. Keep living your best life — we quietly build your wealth in the background.'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // The Big Vision — NO OVERFLOW ANYMORE
                  Container(
                    width: double.infinity,
                    color: const Color(0xFF111827),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          'One App. Infinite Opportunities.',
                          style: TextStyle(color: Color(0xFFF5BB1B), fontSize: 28, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Wrap = magic fix for overflow
                        Wrap(
                          spacing: 16,
                          runSpacing: 20,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildVisionCard(icon: Icons.public, title: 'Own Land Across the World', description: 'Fractional ownership in prime property — starting from KES 500.'),
                            _buildVisionCard(icon: Icons.business, title: 'Invest in SMEs', description: 'Back real Kenyan businesses and earn up to 30% returns.'),
                            _buildVisionCard(icon: Icons.handshake, title: 'Lend Without Losing Friends', description: 'Borrow from or lend to anyone. Smart contracts auto-collect — no awkward chats.'),
                            _buildVisionCard(icon: Icons.shopping_bag, title: 'Buy Now, Pay Later', description: 'Shop at thousands of stores and pay in easy installments.'),
                            _buildVisionCard(icon: Icons.flag, title: 'Save for Your Goals', description: 'Wedding? Plot? Business? Lock your money and watch it grow.'),
                            _buildVisionCard(icon: Icons.card_giftcard, title: 'Earn Rewards Everywhere', description: 'Cashback and discounts from our partner stores every time you spend.'),
                            _buildVisionCard(icon: Icons.work_outline, title: 'Top Up with Micro-Gigs', description: 'Earn extra cash with quick tasks — surveys, referrals, deliveries.'),
                            _buildVisionCard(icon: Icons.favorite, title: 'In Case of Death', description: 'Your investments automatically go to your chosen dependents — peace of mind guaranteed.'),
                            _buildVisionCard(icon: Icons.groups, title: 'Join Welfare Groups', description: 'Chamas, table banking, merry-go-rounds — all digital and transparent.'),
                            _buildVisionCard(icon: Icons.event, title: 'Events & Community', description: 'Financial literacy workshops, investment meetups, networking events — grow together.'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Start Now Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModernLoginScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5BB1B),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        minimumSize: const Size(double.infinity, 60),
                      ),
                      child: const Text('JOIN THE FUTURE OF MONEY', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 20, bottom: 60),
                    child: Center(
                      child: Text(
                        'Over 500,000 Kenyans already growing their money the smart way',
                        style: TextStyle(color: Colors.white70, fontSize: 15),
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

  // Highlight Card — responsive
  Widget _buildHighlightCard({required IconData icon, required String title, required String description}) {
    return Container(
      width: (MediaQuery.of(context).size.width - 72) / 2, // 2 cards with spacing
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF374151), borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: const EdgeInsets.all(14), decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF5BB1B)), child: Icon(icon, color: Colors.black, size: 32)),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(description, style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // Vision Card — responsive, no overflow
  Widget _buildVisionCard({required IconData icon, required String title, required String description}) {
    return Container(
      width: (MediaQuery.of(context).size.width - 72) / 2,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF374151), borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF5BB1B)), child: Icon(icon, color: Colors.black, size: 28)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Colors.white70, fontSize: 12.5), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// FeatureCard
class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const FeatureCard({required this.icon, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF374151),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: 100,
        height: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.amber, size: 30),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}