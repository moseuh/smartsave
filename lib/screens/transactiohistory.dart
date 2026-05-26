import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';
import '../constants/app_theme.dart';
import '../widgets/graph.dart'; // Import SavingsDashboard
import 'buygoodselect.dart';
import 'profile.dart';
import 'wallet_page.dart';

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
  List<Map<String, dynamic>> allTransactions = []; // Store all transactions for filtering
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
        Uri.parse('${AppConstants.apiBaseUrl}/transactions/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('Transactions API response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] is List) {
          setState(() {
            allTransactions = List<Map<String, dynamic>>.from(data['data']).map((transaction) {
              final createdAt = transaction['created_at'] ?? DateTime.now().toIso8601String();
              DateTime? parsedDate;
              try {
                parsedDate = DateTime.parse(createdAt);
              } catch (e) {
                debugPrint('Invalid timestamp format: $createdAt');
                parsedDate = DateTime.now();
              }
              return {
                'icon': _getTransactionIcon(transaction['type'] ?? 'unknown'),
                'iconColor': _getIconColor(transaction['type'] ?? 'unknown'),
                'title': transaction['business_name']?.toString() ?? 'Unknown Merchant',
                'status': transaction['transaction_status']?.toString().capitalize() ?? 'Unknown',
                'amount': double.tryParse(transaction['total_amount']?.toString() ?? '0.0') ?? 0.0,
                'timestamp': _formatTimestamp(createdAt),
                'date': parsedDate, // Store raw DateTime
              };
            }).toList();
            isLoading = false;
            _applyFilter(_selectedFilter); // Apply initial filter
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
        allTransactions = [];
        transactions = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading transactions: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: fetchTransactions,
            ),
          ),
        );
      }
    }
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
        return AppColors.financeGreenV3;
      case 'pay_bill':
        return AppColors.financeGreen;
      default:
        return AppTheme.textSecondary;
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
        return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
      }
    } catch (e) {
      return timestamp;
    }
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WalletPage(userId: widget.userId)));
    } else if (index == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SavingsDashboard(userId: widget.userId)));
    } else if (index == 2) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BuyGoodsSelect(userId: widget.userId)));
    } else if (index == 3) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Profile(userId: widget.userId)));
    }
  }

  void _setFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _applyFilter(filter);
  }

  void _applyFilter(String filter) {
    final now = DateTime.now();
    setState(() {
      transactions = allTransactions.where((transaction) {
        final DateTime transactionDate = transaction['date'] as DateTime;
        switch (filter) {
          case 'Today':
            return transactionDate.year == now.year &&
                transactionDate.month == now.month &&
                transactionDate.day == now.day;
          case 'Week':
            final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
            return transactionDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
                transactionDate.isBefore(now.add(const Duration(days: 1)));
          case 'Month':
            return transactionDate.year == now.year &&
                transactionDate.month == now.month;
          case 'Year':
            return transactionDate.year == now.year;
          default:
            return true; // Show all transactions if filter is invalid
        }
      }).toList();
    });
  }

  Future<void> fetchTransactionsWithFilter(String filter) async {
    // Since the API doesn't support server-side filtering, fetch all and filter client-side
    await fetchTransactions();
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
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        toolbarHeight: 70,
        title: const Text(
          'Transaction History',
          style: TextStyle(color: AppTheme.textLight, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppTheme.textLight),
            onPressed: _onSearchTapped,
          ),
        ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppTheme.primaryColor,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.financeGreenV3))
          : hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Failed to load transactions', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: fetchTransactions, child: const Text('Retry')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                            color: AppTheme.cardLight,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: AppColors.financeGreen.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Amount', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$transactionCount Transaction${transactionCount == 1 ? '' : 's'}',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    'KSh ${totalAmount.abs().toStringAsFixed(0)}',
                                    style: const TextStyle(color: AppColors.financeGreenV3, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '.${(totalAmount.abs() % 1 * 100).toInt().toString().padLeft(2, '0')}',
                                    style: const TextStyle(color: AppColors.financeGreenV3, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        transactions.isEmpty
                            ? const Center(
                                child: Text('No transactions found for this period', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
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
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppTheme.cardLight,
        selectedItemColor: AppColors.financeGreenV3,
        unselectedItemColor: AppTheme.textSecondary,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payments'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
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
          color: isSelected ? AppColors.financeGreenV3 : AppColors.coreWhiteW2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.textLight : AppTheme.textSecondary,
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
        ? AppColors.financeGreenV3
        : status.toLowerCase() == 'pending'
            ? AppTheme.warningColor
            : AppTheme.errorColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: AppTheme.cardLight,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppColors.financeGreen.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(status, style: TextStyle(color: statusColor, fontSize: 12)),
                      const SizedBox(width: 8),
                      Text(timestamp, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${isPositive ? "+" : "-"}KSh ${amount.abs().toStringAsFixed(2)}',
              style: TextStyle(
                color: isPositive ? AppColors.financeGreenV3 : AppTheme.errorColor,
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