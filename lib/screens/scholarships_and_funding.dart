// scholarships_and_funding.dart
import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ScholarshipsAndFundingPage extends StatefulWidget {
  const ScholarshipsAndFundingPage({super.key});

  @override
  _ScholarshipsAndFundingPageState createState() => _ScholarshipsAndFundingPageState();
}

class _ScholarshipsAndFundingPageState extends State<ScholarshipsAndFundingPage> {
  late Future<List<Map<String, String>>> _opportunities;

  @override
  void initState() {
    super.initState();
    _opportunities = fetchOpportunities();
  }

  Future<List<Map<String, String>>> fetchOpportunities() async {
    try {
      final response = await http.get(Uri.parse('https://api.example.com/scholarships'));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((item) => {
          'title': (item['title'] ?? 'No Title').toString(),
          'description': (item['description'] ?? 'No description available').toString(),
          'amount': (item['amount'] ?? 'KES N/A').toString(),
          'category': (item['category'] ?? 'Uncategorized').toString(),
          'applyUrl': (item['applyUrl'] ?? 'https://example.com/apply').toString(), // Default dummy URL
        }).toList();
      } else {
        // Fallback to static data if API fails
        return const [
          {
            'title': 'FinTech Scholarship 2025',
            'description': 'Full tuition support for fintech-related studies.',
            'amount': 'KES 500,000',
            'category': 'Scholarship',
            'applyUrl': 'https://example.com/scholarship1',
          },
          {
            'title': 'Startup Funding Grant',
            'description': 'Seed funding for innovative fintech startups.',
            'amount': 'KES 1,000,000',
            'category': 'Funding',
            'applyUrl': 'https://example.com/funding1',
          },
          {
            'title': 'Campus Innovation Award',
            'description': 'Funding for student-led fintech projects.',
            'amount': 'KES 250,000',
            'category': 'Funding',
            'applyUrl': 'https://example.com/funding2',
          },
          {
            'title': 'Women in Tech Scholarship',
            'description': 'Support for women pursuing tech education.',
            'amount': 'KES 300,000',
            'category': 'Scholarship',
            'applyUrl': 'https://example.com/scholarship2',
          },
        ];
      }
    } catch (e) {
      // Fallback to static data on network or other errors
      return const [
        {
          'title': 'FinTech Scholarship 2025',
          'description': 'Full tuition support for fintech-related studies.',
          'amount': 'KES 500,000',
          'category': 'Scholarship',
          'applyUrl': 'https://example.com/scholarship1',
        },
        {
          'title': 'Startup Funding Grant',
          'description': 'Seed funding for innovative fintech startups.',
          'amount': 'KES 1,000,000',
          'category': 'Funding',
          'applyUrl': 'https://example.com/funding1',
        },
        {
          'title': 'Campus Innovation Award',
          'description': 'Funding for student-led fintech projects.',
          'amount': 'KES 250,000',
          'category': 'Funding',
          'applyUrl': 'https://example.com/funding2',
        },
        {
          'title': 'Women in Tech Scholarship',
          'description': 'Support for women pursuing tech education.',
          'amount': 'KES 300,000',
          'category': 'Scholarship',
          'applyUrl': 'https://example.com/scholarship2',
        },
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4B5563), // Fintech-themed dark grayish-blue
      appBar: AppBar(
        title: const Text('Scholarships & Funding', style: TextStyle(color: AppTheme.cardLight)),
        backgroundColor: const Color(0xFF2A2F3A), // Darker header
        elevation: 2,
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _opportunities,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No opportunities available'));
          } else {
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final opportunity = snapshot.data![index];
                return Card(
                  color: const Color(0xFF2A2F3A), // Dark card background
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16.0),
                    leading: const Icon(Icons.school, size: 50, color: Color(0xFFD4AF37)), // Placeholder icon
                    title: Text(
                      opportunity['title']!,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          opportunity['description']!,
                          style: TextStyle(
                            color: AppColors.coreWhiteW2,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Amount: ${opportunity['amount']!}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WebViewPage(url: opportunity['applyUrl']!),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37), // Gold button
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}

// WebViewPage to display the URL
class WebViewPage extends StatefulWidget {
  final String url;

  const WebViewPage({super.key, required this.url});

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF4B5563))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading state if needed
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply Now', style: TextStyle(color: AppTheme.cardLight)),
        backgroundColor: const Color(0xFF2A2F3A),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.cardLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

