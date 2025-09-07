
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:io' show Platform, File;
import 'buygoodselect.dart';
import 'sign_in_screen.dart';
import 'loans_credit_score.dart';
import 'profile.dart';
import 'jobs_page.dart';

// Placeholder pages for navigation
class ScholarshipsPage extends StatelessWidget {
  final String userId;
  const ScholarshipsPage({super.key, required this.userId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scholarships', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF374151),
      ),
      backgroundColor: const Color(0xFF1F2937),
      body: const Center(
        child: Text(
          'Scholarships Page Under Construction',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}

class ChatPage extends StatelessWidget {
  final String userId;
  const ChatPage({super.key, required this.userId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF374151),
      ),
      backgroundColor: const Color(0xFF1F2937),
      body: const Center(
        child: Text(
          'Chat Page Under Construction',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}

class LeaderboardPage extends StatelessWidget {
  final String userId;
  const LeaderboardPage({super.key, required this.userId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF374151),
      ),
      backgroundColor: const Color(0xFF1F2937),
      body: const Center(
        child: Text(
          'Leaderboard Page Under Construction',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}

class ClassesPage extends StatelessWidget {
  final String userId;
  const ClassesPage({super.key, required this.userId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF374151),
      ),
      backgroundColor: const Color(0xFF1F2937),
      body: const Center(
        child: Text(
          'Classes Page Under Construction',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}

class WalletPage extends StatefulWidget {
  final String userId;
  const WalletPage({super.key, required this.userId});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? userDetails;
  Map<String, dynamic>? walletData;
  List<dynamic>? transactions;
  bool isLoading = true;
  int _selectedIndex = 0;
  String _selectedCurrency = 'KES';
  Map<String, double> _exchangeRates = {'KES': 1.0, 'USD': 0.0078, 'EUR': 0.0070};
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isQuickTransferEnabled = true;
  bool _isBiometricEnabled = false;
  String? _pin;
  String _filterType = 'All';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _validateAndFetchData();
  }

  Future<void> _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isQuickTransferEnabled = prefs.getBool('quick_transfer') ?? true;
      _isBiometricEnabled = prefs.getBool('biometric_lock') ?? false;
      _pin = prefs.getString('wallet_pin');
    });
  }

  Future<void> _savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quick_transfer', _isQuickTransferEnabled);
    await prefs.setBool('biometric_lock', _isBiometricEnabled);
    if (_pin != null) await prefs.setString('wallet_pin', _pin!);
  }

  Future<void> _validateAndFetchData() async {
    if (widget.userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid user ID. Please log in again.')),
      );
      await _logout();
      return;
    }
    await fetchUserDetails();
    if (userDetails != null) {
      await fetchExchangeRates();
      await fetchWalletData();
    } else {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User details not found. Please update your profile.')),
      );
    }
  }

  Future<void> fetchUserDetails() async {
    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');
      final response = await http.get(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/user-details/${widget.userId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            userDetails = data['data'];
            isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load user details');
        }
      } else if (response.statusCode == 404) {
        throw Exception('User not found. Please log in again.');
      } else {
        throw Exception('Failed to load user details: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: fetchUserDetails,
          ),
        ),
      );
    }
  }

  Future<void> fetchExchangeRates() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.exchangerate-api.com/v4/latest/KES'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _exchangeRates = {
            'KES': 1.0,
            'USD': data['rates']['USD']?.toDouble() ?? 0.0078,
            'EUR': data['rates']['EUR']?.toDouble() ?? 0.0070,
          };
        });
      }
    } catch (e) {
      _exchangeRates = {'KES': 1.0, 'USD': 0.0078, 'EUR': 0.0070};
    }
  }

  Future<void> fetchWalletData() async {
    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');
      final response = await http.get(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/wallet/${widget.userId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            walletData = data['data'];
            transactions = data['data']['transactions'] ?? [];
            isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load wallet data');
        }
      } else {
        throw Exception('Failed to load wallet data: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        walletData = {
          'balance': 12540.0,
          'accounts': [
            {'type': 'Bank', 'name': 'KCB Bank', 'last4': '1234', 'balance': 5000.0},
            {'type': 'Mobile Money', 'name': 'M-Pesa', 'last4': '5678', 'balance': 3000.0},
            {'type': 'Card', 'name': 'Visa', 'last4': '9012', 'balance': 0.0},
            {'type': 'Virtual Card', 'name': 'Virtual Card', 'last4': '3456', 'balance': 0.0},
          ],
          'transactions': [
            {'type': 'Deposit', 'amount': 1000.0, 'date': '2025-08-20'},
            {'type': 'Withdrawal', 'amount': 500.0, 'date': '2025-08-18'},
            {'type': 'Transfer', 'amount': 200.0, 'date': '2025-08-15'},
          ],
        };
        transactions = walletData!['transactions'];
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Using default wallet data due to error: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: fetchWalletData,
          ),
        ),
      );
    }
  }

  Future<bool> _authenticate({required String reason}) async {
    if (_isBiometricEnabled) {
      try {
        return await _localAuth.authenticate(localizedReason: reason);
      } catch (e) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Biometric authentication failed: $e')),
        );
        return false;
      }
    } else if (_pin != null && !_isQuickTransferEnabled) {
      final pinController = TextEditingController();
      bool authenticated = false;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF374151),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Enter PIN', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: pinController,
            style: const TextStyle(color: Colors.white),
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'PIN',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white54),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFFF5BB1B)),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                if (pinController.text == _pin) {
                  authenticated = true;
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid PIN')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5BB1B),
                foregroundColor: Colors.black,
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      return authenticated;
    }
    return true;
  }

  Future<void> initiateP2PTransfer(String recipientId, double amount, String currency) async {
    if (amount <= 0 || recipientId.isEmpty || recipientId == widget.userId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid recipient ID or amount')),
      );
      return;
    }

    double amountInKES = amount / _exchangeRates[currency]!;
    if ((walletData?['balance'] ?? 0.0) < amountInKES) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance')),
      );
      return;
    }

    if (!await _authenticate(reason: 'Authenticate to send money')) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');
      final validateResponse = await http.get(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/user-details/$recipientId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (validateResponse.statusCode != 200 || jsonDecode(validateResponse.body)['status'] != 'success') {
        throw Exception('Recipient not found');
      }

      final response = await http.post(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/wallet/transfer'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'sender_id': widget.userId,
          'recipient_id': recipientId,
          'amount': amountInKES,
          'currency': 'KES',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            walletData!['balance'] -= amountInKES;
            transactions?.insert(0, {
              'type': 'Transfer',
              'amount': amount,
              'currency': currency,
              'date': DateTime.now().toString().split(' ')[0],
            });
            isLoading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Transfer of $currency ${amount.toStringAsFixed(2)} successful')),
          );
        } else {
          throw Exception(data['message'] ?? 'Transfer failed');
        }
      } else {
        throw Exception('Transfer failed: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initiating transfer: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => initiateP2PTransfer(recipientId, amount, currency),
          ),
        ),
      );
    }
  }

  Future<void> addMoney(double amount, String currency, String method) async {
    if (amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid amount')),
      );
      return;
    }

    if (!await _authenticate(reason: 'Authenticate to add money')) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');
      double amountInKES = amount / _exchangeRates[currency]!;
      final response = await http.post(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/wallet/deposit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': widget.userId,
          'amount': amountInKES,
          'currency': 'KES',
          'method': method,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            walletData!['balance'] += amountInKES;
            transactions?.insert(0, {
              'type': 'Deposit',
              'amount': amount,
              'currency': currency,
              'date': DateTime.now().toString().split(' ')[0],
            });
            isLoading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deposited $currency ${amount.toStringAsFixed(2)} via $method')),
          );
        } else {
          throw Exception(data['message'] ?? 'Deposit failed');
        }
      } else {
        throw Exception('Deposit failed: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding money: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => addMoney(amount, currency, method),
          ),
        ),
      );
    }
  }

  Future<void> withdrawMoney(double amount, String currency, String method) async {
    if (amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid amount')),
      );
      return;
    }

    double amountInKES = amount / _exchangeRates[currency]!;
    if ((walletData?['balance'] ?? 0.0) < amountInKES) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance')),
      );
      return;
    }

    if (!await _authenticate(reason: 'Authenticate to withdraw money')) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');
      final response = await http.post(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/wallet/withdraw'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': widget.userId,
          'amount': amountInKES,
          'currency': 'KES',
          'method': method,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            walletData!['balance'] -= amountInKES;
            transactions?.insert(0, {
              'type': 'Withdrawal',
              'amount': amount,
              'currency': currency,
              'date': DateTime.now().toString().split(' ')[0],
            });
            isLoading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Withdrawn $currency ${amount.toStringAsFixed(2)} via $method')),
          );
        } else {
          throw Exception(data['message'] ?? 'Withdrawal failed');
        }
      } else {
        throw Exception('Withdrawal failed: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error withdrawing money: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => withdrawMoney(amount, currency, method),
          ),
        ),
      );
    }
  }

  Future<void> exchangeCurrency(double amount, String fromCurrency, String toCurrency) async {
    if (amount <= 0 || fromCurrency == toCurrency) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid amount or currency')),
      );
      return;
    }

    double amountInKES = amount / _exchangeRates[fromCurrency]!;
    if ((walletData?['balance'] ?? 0.0) < amountInKES) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance')),
      );
      return;
    }

    if (!await _authenticate(reason: 'Authenticate to exchange currency')) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');
      final response = await http.post(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/wallet/exchange'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': widget.userId,
          'amount': amountInKES,
          'from_currency': 'KES',
          'to_currency': toCurrency,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          double convertedAmount = amount * _exchangeRates[toCurrency]! / _exchangeRates[fromCurrency]!;
          setState(() {
            walletData!['balance'] -= amountInKES;
            transactions?.insert(0, {
              'type': 'Exchange',
              'amount': convertedAmount,
              'currency': toCurrency,
              'date': DateTime.now().toString().split(' ')[0],
            });
            isLoading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exchanged $fromCurrency ${amount.toStringAsFixed(2)} to $toCurrency ${convertedAmount.toStringAsFixed(2)}'),
            ),
          );
        } else {
          throw Exception(data['message'] ?? 'Exchange failed');
        }
      } else {
        throw Exception('Exchange failed: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exchanging currency: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => exchangeCurrency(amount, fromCurrency, toCurrency),
          ),
        ),
      );
    }
  }

  void _showP2PTransferDialog() {
    final recipientController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCurrency = _selectedCurrency;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Send Money', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: recipientController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Recipient User ID',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFF5BB1B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter recipient ID';
                    if (value == widget.userId) return 'Cannot send to self';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount ($selectedCurrency)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFF5BB1B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter amount';
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) return 'Enter a valid amount';
                    if (amount * _exchangeRates[_selectedCurrency]! > (walletData?['balance'] ?? 0.0)) {
                      return 'Insufficient balance';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCurrency,
                  decoration: InputDecoration(
                    labelText: 'Currency',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFF5BB1B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  dropdownColor: const Color(0xFF374151),
                  style: const TextStyle(color: Colors.white),
                  items: ['KES', 'USD', 'EUR'].map((currency) {
                    return DropdownMenuItem(value: currency, child: Text(currency));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedCurrency = value!),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                initiateP2PTransfer(recipientController.text, double.parse(amountController.text), selectedCurrency);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5BB1B),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showAddMoneyDialog() {
    final amountController = TextEditingController();
    String selectedCurrency = _selectedCurrency;
    String selectedMethod = 'M-Pesa';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add Money', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount ($selectedCurrency)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFF5BB1B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter amount';
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCurrency,
                  decoration: InputDecoration(
                    labelText: 'Currency',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFF5BB1B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  dropdownColor: const Color(0xFF374151),
                  style: const TextStyle(color: Colors.white),
                  items: ['KES', 'USD', 'EUR'].map((currency) {
                    return DropdownMenuItem(value: currency, child: Text(currency));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedCurrency = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  decoration: InputDecoration(
                    labelText: 'Payment Method',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFF5BB1B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  dropdownColor: const Color(0xFF374151),
                  style: const TextStyle(color: Colors.white),
                  items: ['M-Pesa', 'PayPal', 'Bank Transfer'].map((method) {
                    return DropdownMenuItem(value: method, child: Text(method));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedMethod = value!),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                addMoney(double.parse(amountController.text), selectedCurrency, selectedMethod);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5BB1B),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog() {
    final amountController = TextEditingController();
    String selectedCurrency = _selectedCurrency;
    String selectedMethod = 'M-Pesa';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Withdraw Money', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount ($selectedCurrency)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFF5BB1B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter amount';
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) return 'Enter a valid amount';
                    if (amount * _exchangeRates[_selectedCurrency]! > (walletData?['balance'] ?? 0.0)) {
                      return 'Insufficient balance';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCurrency,
                  decoration: InputDecoration(
                    labelText: 'Currency',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFF5BB1B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  dropdownColor: const Color(0xFF374151),
                  style: const TextStyle(color: Colors.white),
                  items: ['KES', 'USD', 'EUR'].map((currency) {
                    return DropdownMenuItem(value: currency, child: Text(currency));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedCurrency = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  decoration: InputDecoration(
                    labelText: 'Withdrawal Method',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFF5BB1B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  dropdownColor: const Color(0xFF374151),
                  style: const TextStyle(color: Colors.white),
                  items: ['M-Pesa', 'Bank Transfer'].map((method) {
                    return DropdownMenuItem(value: method, child: Text(method));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedMethod = value!),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                withdrawMoney(double.parse(amountController.text), selectedCurrency, selectedMethod);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5BB1B),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }

  void _showExchangeDialog() {
    final amountController = TextEditingController();
    String fromCurrency = _selectedCurrency;
    String toCurrency = 'USD';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Exchange Currency', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount ($fromCurrency)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFF5BB1B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter amount';
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) return 'Enter a valid amount';
                    if (amount * _exchangeRates[fromCurrency]! > (walletData?['balance'] ?? 0.0)) {
                      return 'Insufficient balance';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: fromCurrency,
                  decoration: InputDecoration(
                    labelText: 'From Currency',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFF5BB1B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  dropdownColor: const Color(0xFF374151),
                  style: const TextStyle(color: Colors.white),
                  items: ['KES', 'USD', 'EUR'].map((currency) {
                    return DropdownMenuItem(value: currency, child: Text(currency));
                  }).toList(),
                  onChanged: (value) => setState(() => fromCurrency = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: toCurrency,
                  decoration: InputDecoration(
                    labelText: 'To Currency',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFF5BB1B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  dropdownColor: const Color(0xFF374151),
                  style: const TextStyle(color: Colors.white),
                  items: ['KES', 'USD', 'EUR'].map((currency) {
                    return DropdownMenuItem(value: currency, child: Text(currency));
                  }).toList(),
                  onChanged: (value) => setState(() => toCurrency = value!),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                exchangeCurrency(double.parse(amountController.text), fromCurrency, toCurrency);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5BB1B),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Exchange'),
          ),
        ],
      ),
    );
  }

  void _showPinSetupDialog() {
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Set PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: pinController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'New PIN',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFF5BB1B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length != 4) return 'Enter a 4-digit PIN';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPinController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Confirm PIN',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFF5BB1B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value != pinController.text) return 'PINs do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  _pin = pinController.text;
                });
                _savePreferences();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN set successfully')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5BB1B),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _showTransactionFilterDialog() {
    String tempFilterType = _filterType;
    DateTimeRange? tempDateRange = _dateRange;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Filter Transactions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          child: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: tempFilterType,
                  decoration: InputDecoration(
                    labelText: 'Transaction Type',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFF5BB1B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  dropdownColor: const Color(0xFF374151),
                  style: const TextStyle(color: Colors.white),
                  items: ['All', 'Deposit', 'Withdrawal', 'Transfer', 'Exchange'].map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) => setState(() => tempFilterType = value!),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Color(0xFFF5BB1B),
                            surface: Color(0xFF374151),
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        tempDateRange = picked;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5BB1B),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(tempDateRange == null
                      ? 'Select Date Range'
                      : '${DateFormat('yyyy-MM-dd').format(tempDateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(tempDateRange!.end)}'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _filterType = tempFilterType;
                _dateRange = tempDateRange;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5BB1B),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> exportTransactions() async {
    try {
      final csvData = [
        ['Type', 'Amount', 'Currency', 'Date'],
        ...(transactions ?? []).map((tx) => [
              tx['type'] ?? 'N/A',
              tx['amount']?.toStringAsFixed(2) ?? '0.00',
              tx['currency'] ?? _selectedCurrency,
              tx['date'] ?? 'N/A',
            ]),
      ];
      String csv = const ListToCsvConverter().convert(csvData);
      if (Platform.isAndroid || Platform.isIOS) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/wallet_transactions_${widget.userId}.csv');
        await file.writeAsString(csv);
        await OpenFilex.open(file.path);
      } else {
        final bytes = utf8.encode(csv);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'wallet_transactions_${widget.userId}.csv')
          ..click();
        html.Url.revokeObjectUrl(url);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transactions exported as CSV')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting transactions: $e')),
      );
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
    );
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      // Stay on WalletPage
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoansCreditScore(userId: widget.userId)),
      );
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

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFF5BB1B),
            child: Icon(icon, color: Colors.black, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(String category, double amount, double maxAmount) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            category,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
        Expanded(
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFFF5BB1B),
              borderRadius: BorderRadius.circular(5),
            ),
            width: MediaQuery.of(context).size.width * 0.6 * (amount / maxAmount),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$_selectedCurrency ${amount.toStringAsFixed(2)}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final balance = walletData != null ? walletData!['balance']?.toDouble() ?? 0.0 : 0.0;
    final convertedBalance = balance * _exchangeRates[_selectedCurrency]!;
    final inflow = transactions?.fold<double>(0, (sum, tx) => sum + (tx['type'] == 'Deposit' ? (tx['amount']?.toDouble() ?? 0) * (_exchangeRates[tx['currency'] ?? _selectedCurrency] ?? 1.0) : 0)) ?? 0.0;
    final outflow = transactions?.fold<double>(0, (sum, tx) => sum + ((tx['type'] == 'Withdrawal' || tx['type'] == 'Transfer') ? (tx['amount']?.toDouble() ?? 0) * (_exchangeRates[tx['currency'] ?? _selectedCurrency] ?? 1.0) : 0)) ?? 0.0;
    final filteredTransactions = transactions?.where((tx) {
      bool matchesType = _filterType == 'All' || tx['type'] == _filterType;
      bool matchesDate = _dateRange == null ||
          (DateTime.tryParse(tx['date'] ?? '')?.isAfter(_dateRange!.start) ?? true) &&
              (DateTime.tryParse(tx['date'] ?? '')?.isBefore(_dateRange!.end.add(const Duration(days: 1))) ?? true);
      return matchesType && matchesDate;
    }).toList();

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1F2937),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF5BB1B),
          surface: Color(0xFF374151),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF2D3748),
          elevation: 8,
          shadowColor: Colors.black45,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF5BB1B),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF1F2937),
        body: isLoading
            ? const Center(
                child: SpinKitFadingCircle(
                  color: Color(0xFFF5BB1B),
                  size: 50.0,
                ),
              )
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 180,
                    floating: false,
                    pinned: true,
                    backgroundColor: const Color(0xFF374151),
                    leading: IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    actions: [
                      DropdownButton<String>(
                        value: _selectedCurrency,
                        dropdownColor: const Color(0xFF374151),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        underline: Container(),
                        items: ['KES', 'USD', 'EUR'].map((currency) {
                          return DropdownMenuItem(
                            value: currency,
                            child: Text(currency),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCurrency = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(bottom: 16),
                      title: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            userDetails != null ? userDetails!['full_name'] ?? 'User' : 'Loading...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$_selectedCurrency ${convertedBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFFF5BB1B),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF374151), Color(0xFF1F2937)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Actions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            elevation: 8,
                            shadowColor: Colors.black45,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildActionButton(
                                    icon: Icons.add_circle,
                                    label: 'Add Money',
                                    onTap: _showAddMoneyDialog,
                                  ),
                                  _buildActionButton(
                                    icon: Icons.arrow_downward,
                                    label: 'Withdraw',
                                    onTap: _showWithdrawDialog,
                                  ),
                                  _buildActionButton(
                                    icon: Icons.send,
                                    label: 'Send Money',
                                    onTap: _showP2PTransferDialog,
                                  ),
                                  _buildActionButton(
                                    icon: Icons.swap_horiz,
                                    label: 'Exchange',
                                    onTap: _showExchangeDialog,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Transactions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.filter_list, color: Color(0xFFF5BB1B)),
                            onPressed: _showTransactionFilterDialog,
                          ),
                        ],
                      ),
                    ),
                  ),
                  filteredTransactions == null || filteredTransactions.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Card(
                              elevation: 8,
                              shadowColor: Colors.black45,
                              child: const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: Text(
                                    'No transactions found',
                                    style: TextStyle(color: Colors.white70, fontSize: 16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final tx = filteredTransactions[index];
                              return Card(
                                elevation: 8,
                                shadowColor: Colors.black45,
                                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16.0),
                                  title: Text(
                                    '${tx['type']}: ${tx['currency'] ?? _selectedCurrency} ${tx['amount']?.toStringAsFixed(2) ?? '0.00'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Date: ${tx['date'] ?? 'N/A'}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                                  ),
                                ),
                              );
                            },
                            childCount: filteredTransactions.length,
                          ),
                        ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Linked Accounts',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final account = walletData!['accounts'][index];
                        final accountBalance = (account['balance']?.toDouble() ?? 0.0) * _exchangeRates[_selectedCurrency]!;
                        return Card(
                          elevation: 8,
                          shadowColor: Colors.black45,
                          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16.0),
                            title: Text(
                              '${account['name']} (${account['last4']})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              '${account['type']}: $_selectedCurrency ${accountBalance.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF374151),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    title: Text('Manage ${account['name']}', style: const TextStyle(color: Colors.white)),
                                    content: const Text('Account management not implemented yet.', style: TextStyle(color: Colors.white70)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close', style: TextStyle(color: Colors.white70)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF5BB1B),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Manage'),
                            ),
                          ),
                        );
                      },
                      childCount: walletData?['accounts']?.length ?? 0,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Insights',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            elevation: 8,
                            shadowColor: Colors.black45,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Monthly Inflow vs Outflow',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Text(
                                              'Inflow: $_selectedCurrency ${inflow.toStringAsFixed(2)}',
                                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF5BB1B),
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              width: MediaQuery.of(context).size.width * 0.4 * (inflow / (inflow + outflow + 1)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Text(
                                              'Outflow: $_selectedCurrency ${outflow.toStringAsFixed(2)}',
                                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent,
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              width: MediaQuery.of(context).size.width * 0.4 * (outflow / (inflow + outflow + 1)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Spending Categories',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildCategoryBar('Bills', 3000.0 * _exchangeRates[_selectedCurrency]!, 5000.0),
                                  const SizedBox(height: 8),
                                  _buildCategoryBar('Shopping', 1500.0 * _exchangeRates[_selectedCurrency]!, 5000.0),
                                  const SizedBox(height: 8),
                                  _buildCategoryBar('Others', 1000.0 * _exchangeRates[_selectedCurrency]!, 5000.0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Security',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            elevation: 8,
                            shadowColor: Colors.black45,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  ListTile(
                                    title: const Text('PIN Setup', style: TextStyle(color: Colors.white, fontSize: 16)),
                                    trailing: ElevatedButton(
                                      onPressed: _showPinSetupDialog,
                                      child: const Text('Set PIN'),
                                    ),
                                  ),
                                  ListTile(
                                    title: const Text('Quick Transfer', style: TextStyle(color: Colors.white, fontSize: 16)),
                                    trailing: Switch(
                                      value: _isQuickTransferEnabled,
                                      activeColor: const Color(0xFFF5BB1B),
                                      onChanged: (value) {
                                        setState(() {
                                          _isQuickTransferEnabled = value;
                                        });
                                        _savePreferences();
                                      },
                                    ),
                                  ),
                                  ListTile(
                                    title: const Text('Biometric Lock', style: TextStyle(color: Colors.white, fontSize: 16)),
                                    trailing: Switch(
                                      value: _isBiometricEnabled,
                                      activeColor: const Color(0xFFF5BB1B),
                                      onChanged: (value) async {
                                        if (value) {
                                          bool canAuthenticate = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
                                          if (!canAuthenticate) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Biometric authentication not supported')),
                                            );
                                            return;
                                          }
                                        }
                                        setState(() {
                                          _isBiometricEnabled = value;
                                        });
                                        _savePreferences();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        elevation: 8,
                        shadowColor: Colors.black45,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ElevatedButton(
                            onPressed: exportTransactions,
                            child: const Text('Export Transactions'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        drawer: Drawer(
          backgroundColor: const Color(0xFF374151),
          width: 250,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: Color(0xFF1F2937),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey[300],
                      child: userDetails != null && userDetails!['selfie_path'] != null
                          ? CachedNetworkImage(
                              imageUrl: userDetails!['selfie_path'],
                              fit: BoxFit.cover,
                              width: 56,
                              height: 56,
                            )
                          : const Icon(Icons.person, size: 28, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userDetails != null ? userDetails!['full_name'] ?? 'User' : 'Loading...',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      userDetails != null ? userDetails!['email'] ?? 'No email' : 'Loading...',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: Colors.white70),
                title: const Text('Wallet', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.work, color: Colors.white70),
                title: const Text('Jobs', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => JobsPage(userId: widget.userId)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.school, color: Colors.white70),
                title: const Text('Scholarships', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ScholarshipsPage(userId: widget.userId)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.white70),
                title: const Text('Chat', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatPage(userId: widget.userId)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.leaderboard, color: Colors.white70),
                title: const Text('Leaderboard', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LeaderboardPage(userId: widget.userId)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.class_, color: Colors.white70),
                title: const Text('Classes', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ClassesPage(userId: widget.userId)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.white70),
                title: const Text('Profile', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Profile(userId: widget.userId)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white70),
                title: const Text('Logout', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: const Color(0xFF374151),
          selectedItemColor: const Color(0xFFF5BB1B),
          unselectedItemColor: Colors.white70,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet),
              label: 'Wallet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance),
              label: 'Loans',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: 'Buy Goods',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
