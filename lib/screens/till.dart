import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class TillFavourites extends StatefulWidget {
  const TillFavourites({super.key});

  @override
  State<TillFavourites> createState() => _TillFavouritesState();
}

class _TillFavouritesState extends State<TillFavourites> {
  final List<Map<String, String>> savedTillNumbers = [
    {'name': 'Home Store', 'till': 'Till #123456'},
    {'name': 'Downtown Branch', 'till': 'Till #789012'},
    {'name': 'Mall Kiosk', 'till': 'Till #345678'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add to Favorites',
          style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saved Till Numbers',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: savedTillNumbers.length,
                itemBuilder: (context, index) {
                  final item = savedTillNumbers[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name']!,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['till']!,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.yellow),
                          onPressed: () {
                            // Add logic to remove the favorite
                            setState(() {
                              savedTillNumbers.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Done and Cancel Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Add logic for Done action
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Add logic for Cancel action
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 16),
                    ),
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

