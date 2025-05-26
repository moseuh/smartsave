import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'graph.dart'; // SavingsDashboard

class Favourites extends StatefulWidget {
  final String userId;
  const Favourites({super.key, required this.userId});

  @override
  State<Favourites> createState() => _FavouritesState();
}

class _FavouritesState extends State<Favourites> {
  List<Map<String, dynamic>> favourites = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchFavourites();
  }

  Future<void> fetchFavourites() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/favourites/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint('Fetch favourites response: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            favourites = List<Map<String, dynamic>>.from(data['data']);
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
            errorMessage = data['message'] ?? 'Failed to load favourites';
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load favourites: ${response.statusCode}';
        });
      }
    } catch (e) {
      debugPrint('Error fetching favourites: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching favourites: $e';
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF9CA3AF),
        content: Text(
          message,
          style: const TextStyle(color: Colors.black),
        ),
      ),
    );
  }

  Future<void> deleteFavourite(int favouriteId) async {
    try {
      final response = await http.delete(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/favourites/$favouriteId'),
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint('Delete favourite response: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _showSnackBar('Favourite deleted successfully');
          await fetchFavourites(); // Refresh the list
        } else {
          _showSnackBar('Failed to delete favourite: ${data['message']}');
        }
      } else {
        _showSnackBar('Failed to delete favourite: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting favourite: $e');
      _showSnackBar('Error deleting favourite: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        title: const Text(
          'Favourites',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context); // Go back to BuyGoodsSelect
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'assets/logo.png',
              width: 30,
              height: 30,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF5BB1B)))
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: fetchFavourites,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF5BB1B),
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : favourites.isEmpty
                  ? const Center(
                      child: Text(
                        'No favourites found',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: favourites.length,
                      itemBuilder: (context, index) {
                        final favourite = favourites[index];
                        return Card(
                          color: const Color(0xFF9CA3AF),
                          margin: const EdgeInsets.only(bottom: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16.0),
                            title: Text(
                              favourite['name'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Till/Pay Bill: ${favourite['till_number']}',
                                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                                ),
                                if (favourite['account_number'] != null && favourite['account_number'].isNotEmpty)
                                  Text(
                                    'Account: ${favourite['account_number']}',
                                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                                  ),
                                Text(
                                  'Type: ${favourite['type'] == 'buy_goods' ? 'Buy Goods' : 'Pay Bill'}',
                                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteFavourite(favourite['id']),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}