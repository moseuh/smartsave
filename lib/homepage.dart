import 'package:flutter/material.dart';
import 'landingpage.dart';
import 'sign_in_screen.dart' as signIn;
import 'roundup.dart';
import 'confirmpayment.dart';
import 'addtofavourites.dart';
import 'buygoodselect.dart';
import 'favourites.dart';
import 'till.dart';
import 'insufficient.dart';

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
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  void _navigateToPage(String routeName) {
    Widget page;
    switch (routeName) {
      case 'RoundUpSettings':
        page = const RoundUpSettings();
        break;
      case 'ConfirmPayment':
        page = const ConfirmPayment();
        break;
      case 'AddToFavourites':
        if (widget.userId == null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const signIn.SignInScreen()),
          ).then((result) {
            if (result != null && result is String) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddToFavourites(userId: result)),
              );
            }
          });
          return;
        }
        page = AddToFavourites(userId: widget.userId!);
        break;
      case 'BuyGoodsSelect':
        if (widget.userId == null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const signIn.SignInScreen()),
          ).then((result) {
            if (result != null && result is String) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BuyGoodsSelect(userId: result)),
              );
            }
          });
          return;
        }
        page = BuyGoodsSelect(userId: widget.userId!);
        break;
      case 'Favourites':
        if (widget.userId == null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const signIn.SignInScreen()),
          ).then((result) {
            if (result != null && result is String) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Favourites(userId: result)),
              );
            }
          });
          return;
        }
        page = Favourites(userId: widget.userId!);
        break;
      case 'TillFavourites':
        page = const TillFavourites();
        break;
      case 'InsufficientFunds':
        page = const InsufficientFunds();
        break;
      default:
        return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Removed logo here
            Container(
              width: double.infinity,
              height: 460,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/landing.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.5),
                    BlendMode.dstATop,
                  ),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF000000),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Haba na Haba\nSmart Savings Made Simple',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Join millions of users who save smarter\nwith automated tools and intelligent insights',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFD1D5DB),
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const signIn.SignInScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero, // Sharp edges
                            ),
                          ),
                          child: const Text(
                            'Get Started',
                            style: TextStyle(
                              color: Color(0xFF000000),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LandingPage()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFFFFFF), width: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero, // Sharp edges
                            ),
                          ),
                          child: const Text(
                            'Learn More',
                            style: TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            buildFeatureCard(), // Removed the SizedBox above
            const SizedBox(height: 40), // Kept padding at the bottom
          ],
        ),
      ),
    );
  }

  Widget buildFeatureCard() {
    return Container(
      width: double.infinity, // Extend to full width
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          const Text(
            'Key Features',
            style: TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              Expanded(
                child: FeatureIcon(
                  icon: Icons.savings,
                  title: 'Round Up',
                  description: 'Automatic spare change savings',
                ),
              ),
              Expanded(
                child: FeatureIcon(
                  icon: Icons.payment,
                  title: 'Pay Bills',
                  description: 'Easy utility payments',
                ),
              ),
              Expanded(
                child: FeatureIcon(
                  icon: Icons.shopping_cart,
                  title: 'Buy Goods',
                  description: 'Seamless purchases',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const FeatureIcon({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF4B5563),
            radius: 30,
            child: Icon(icon, color: const Color(0xFFF59E0B), size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}