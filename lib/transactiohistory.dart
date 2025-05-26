import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'graph.dart'; // Import SavingsDashboard
import 'buygoodselect.dart'; // Import BuyGoodsSelect
import 'profile.dart'; // Import Profile

class TransactionHistory extends StatefulWidget {
  final String userId;
  const TransactionHistory({super.key, required this.userId});

  @override
  State<TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory> {
  int _selectedIndex = 1; // Transactions tab is selected
  String _selectedFilter = 'Today'; // Default filter
  List<Map<String, dynamic>> transactions = [];
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    debugPrint('TransactionHistory initialized with userId: ${widget.userId}');
    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final response = await http.get(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/transactions/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('Transactions API response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            transactions = List<Map<String, dynamic>>.from(data['data']).map((transaction) {
              return {
                'icon': _getTransactionIcon(transaction['type'] ?? 'unknown'),
                'iconColor': _getIconColor(transaction['type'] ?? 'unknown'),
                'title': transaction['business_name'] ?? 'Unknown Merchant',
                'status': transaction['transaction_status']?.toString().capitalize() ?? 'Unknown',
                'amount': double.tryParse(transaction['total_amount']?.toString() ?? '0.0') ?? 0.0,
                'timestamp': _formatTimestamp(transaction['created_at'] ?? DateTime.now().toIso8601String()),
              };
            }).toList();
            isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load transactions');
        }
      } else {
        throw Exception('Failed to load transactions: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      setState(() {
        isLoading = false;
        hasError = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading transactions: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: fetchTransactions,
          ),
        ),
      );

      // Fallback to mock data
      setState(() {
        transactions = _getMockTransactions();
      });
    }
  }

  // Mock transactions for fallback
  List<Map<String, dynamic>> _getMockTransactions() {
    return [
      {
        'icon': Icons.shopping_cart,
        'iconColor': Colors.green,
        'title': 'Demo Merchant',
        'status': 'Completed',
        'amount': 1500.75,
        'timestamp': _formatTimestamp(DateTime.now().toIso8601String()),
      },
      {
        'icon': Icons.account_balance_wallet,
        'iconColor': Colors.blue,
        'title': 'Demo Utility',
        'status': 'Pending',
        'amount': 500.00,
        'timestamp': _formatTimestamp(DateTime.now().subtract(const Duration(days: 1)).toIso8601String()),
      },
    ];
  }

  IconData _getTransactionIcon(String type) {
    switch (type.toLowerCase()) {
      case 'buy_goods':
        return Icons.shopping_cart;
      case 'pay_bill':
        return Icons.account_balance_wallet;
      default:
        return Icons.receipt;
    }
  }

  Color _getIconColor(String type) {
    switch (type.toLowerCase()) {
      case 'buy_goods':
        return Colors.green;
      case 'pay_bill':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      if (dateTime.day == now.day && dateTime.month == now.month && dateTime.year == now.year) {
        return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else if (dateTime.day == now.day - 1 && dateTime.month == now.month && dateTime.year == now.year) {
        return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return timestamp;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SavingsDashboard(userId: widget.userId)),
      );
    } else if (index == 1) {
      // Stay on TransactionHistory
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BuyGoodsSelect(userId: widget.userId)),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Profile(userId: widget.userId)),
      );
    }
  }

  void _setFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    fetchTransactionsWithFilter(filter);
  }

  Future<void> fetchTransactionsWithFilter(String filter) async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      await fetchTransactions();
      final now = DateTime.now();
      setState(() {
        transactions = transactions.where((transaction) {
          final timestamp = transaction['timestamp'] as String;
          if (timestamp.startsWith('Today')) {
            return filter == 'Today';
          } else if (timestamp.startsWith('Yesterday')) {
            return filter == 'Today' || filter == 'Week';
          } else {
            final dateParts = timestamp.split('/');
            final transactionDate = DateTime(
              int.parse(dateParts[2]),
              int.parse(dateParts[1]),
              int.parse(dateParts[0]),
            );
            if (filter == 'Week') {
              return now.difference(transactionDate).inDays <= 7;
            } else if (filter == 'Month') {
              return now.difference(transactionDate).inDays <= 30;
            } else if (filter == 'Year') {
              return now.difference(transactionDate).inDays <= 365;
            }
            return true;
          }
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error filtering transactions: $e');
      setState(() {
        isLoading = false;
        hasError = true;
      });
    }
  }

  void _onSearchTapped() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Search tapped')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate totalAmount only for completed transactions
    double totalAmount = transactions
        .where((item) => item['status'].toString().toLowerCase() == 'completed')
        .fold(0.0, (sum, item) => sum + (item['amount'] as double));
    int transactionCount = transactions.length;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 31, 41, 55),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: Container(
          color: const Color(0xFF374151),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transaction History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: _onSearchTapped,
                ),
              ],
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF5BB1B)))
          : hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Failed to load transactions',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: fetchTransactions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildFilterButton('Today'),
                            _buildFilterButton('Week'),
                            _buildFilterButton('Month'),
                            _buildFilterButton('Year'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF374151),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Amount',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$transactionCount Transactions',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    'KSh ${totalAmount.abs().toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Color(0xFFF5BB1B),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '.${(totalAmount.abs() % 1 * 100).toInt().toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Color(0xFFF5BB1B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        transactions.isEmpty
                            ? const Center(
                                child: Text(
                                  'No transactions found',
                                  style: TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: transactions.length,
                                itemBuilder: (context, index) {
                                  final transaction = transactions[index];
                                  return _buildTransactionItem(
                                    icon: transaction['icon'],
                                    iconColor: transaction['iconColor'],
                                    title: transaction['title'],
                                    status: transaction['status'],
                                    amount: transaction['amount'],
                                    timestamp: transaction['timestamp'],
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: Container(
        color: const Color(0xFF374151),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            selectedItemColor: const Color(0xFFF5BB1B),
            unselectedItemColor: Colors.white54,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart),
                label: 'Trans...',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.payment),
                label: 'Payments',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => _setFilter(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String status,
    required double amount,
    required String timestamp,
  }) {
    final isPositive = amount > 0;
    final statusColor = status.toLowerCase() == 'completed'
        ? Colors.green
        : status.toLowerCase() == 'pending'
            ? Colors.orange
            : Colors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF374151),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timestamp,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${isPositive ? "+" : "-"}KSH ${amount.abs().toStringAsFixed(2)}',
              style: TextStyle(
                color: isPositive ? Colors.green : Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}