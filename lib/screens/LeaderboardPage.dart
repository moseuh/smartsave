import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LeaderboardPage extends StatefulWidget {
  final String userId;
  const LeaderboardPage({super.key, required this.userId});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<Map<String, dynamic>> leaderboard = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/leaderboard'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] is List) {
          setState(() {
            leaderboard = List<Map<String, dynamic>>.from(data['data']);
            isLoading = false;
          });
        } else {
          throw Exception('Invalid data format');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load leaderboard. Pull to refresh.';
      });
      // Fallback to mock data if API fails (optional, remove in production)
      _loadMockData();
    }
  }

  void _loadMockData() {
    setState(() {
      leaderboard = [
        {'rank': 1, 'full_name': 'Alex Kimani', 'selfie_path': '', 'total_savings': 125000, 'points': 12500},
        {'rank': 2, 'full_name': 'Sarah Wanjiku', 'selfie_path': '', 'total_savings': 112000, 'points': 11200},
        {'rank': 3, 'full_name': 'John Otieno', 'selfie_path': '', 'total_savings': 108500, 'points': 10850},
        {'rank': 4, 'full_name': 'Mary Achieng', 'selfie_path': '', 'total_savings': 95000, 'points': 9500},
        {'rank': 5, 'full_name': 'David Mutiso', 'selfie_path': '', 'total_savings': 89000, 'points': 8900},
        {'rank': 6, 'full_name': 'You', 'selfie_path': '', 'total_savings': 85000, 'points': 8500, 'is_current_user': true},
        {'rank': 7, 'full_name': 'Grace Njeri', 'selfie_path': '', 'total_savings': 82000, 'points': 8200},
        {'rank': 8, 'full_name': 'Peter Mwangi', 'selfie_path': '', 'total_savings': 78000, 'points': 7800},
        {'rank': 9, 'full_name': 'Faith Adhiambo', 'selfie_path': '', 'total_savings': 75000, 'points': 7500},
        {'rank': 10, 'full_name': 'James Omondi', 'selfie_path': '', 'total_savings': 72000, 'points': 7200},
      ];
      isLoading = false;
    });
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber; // Gold
      case 2:
        return Colors.grey[400]!; // Silver
      case 3:
        return Colors.orange[700]!; // Bronze
      default:
        return const Color(0xFFF5BB1B);
    }
  }

  Widget _buildRankBadge(int rank) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _getRankColor(rank),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          '$rank',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          color: const Color(0xFF374151),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Leaderboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.leaderboard, color: Color(0xFFF5BB1B), size: 28),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLeaderboard,
        color: const Color(0xFFF5BB1B),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFF5BB1B)))
            : errorMessage.isNotEmpty && leaderboard.isEmpty
                ? Center(
                    child: Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: leaderboard.length,
                    itemBuilder: (context, index) {
                      final user = leaderboard[index];
                      final isTop3 = user['rank'] <= 3;
                      final isCurrentUser = user['is_current_user'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isCurrentUser ? const Color(0xFF374151).withOpacity(0.8) : const Color(0xFF374151),
                          borderRadius: BorderRadius.circular(16),
                          border: isCurrentUser
                              ? Border.all(color: const Color(0xFFF5BB1B), width: 2)
                              : Border.all(color: Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            _buildRankBadge(user['rank']),
                            const SizedBox(width: 16),
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[700],
                              backgroundImage: user['selfie_path']?.isNotEmpty == true
                                  ? CachedNetworkImageProvider(user['selfie_path'])
                                  : null,
                              child: user['selfie_path']?.isEmpty ?? true
                                  ? Text(
                                      user['full_name'][0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['full_name'],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: isCurrentUser || isTop3 ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  Text(
                                    'KSh ${user['total_savings'].toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} saved',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${user['points']} pts',
                                  style: TextStyle(
                                    color: isTop3 ? _getRankColor(user['rank']) : const Color(0xFFF5BB1B),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isCurrentUser)
                                  const Text(
                                    'You',
                                    style: TextStyle(color: Color(0xFFF5BB1B), fontSize: 12),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}