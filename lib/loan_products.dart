import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'sign_in_screen.dart';
import 'wallet_page.dart';
import 'loans_credit_score.dart';
import 'profile.dart';
import 'buygoodselect.dart';

class LoanProducts extends StatefulWidget {
  final String userId;
  const LoanProducts({super.key, required this.userId});

  @override
  State<LoanProducts> createState() => _LoanProductsState();
}

class _LoanProductsState extends State<LoanProducts> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? userDetails;
  bool isLoading = true;
  bool isP2PExpanded = false;
  String _selectedCurrency = 'KES';

  @override
  void initState() {
    super.initState();
    _validateAndFetchUserDetails();
  }

  Future<void> _validateAndFetchUserDetails() async {
    if (widget.userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid user ID. Please log in again.')),
      );
      await _logout();
      return;
    }
    await fetchUserDetails();
  }

  Future<void> fetchUserDetails() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/user-details/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
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

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
    );
  }

  Future<void> _requestLoan(String loanType, double maxLimit, {String? recipientId, String? groupId, double? interestRate}) async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/loan/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'loan_type': loanType,
          'amount': maxLimit,
          'currency': _selectedCurrency,
          if (recipientId != null) 'recipient_id': recipientId,
          if (groupId != null) 'group_id': groupId,
          if (interestRate != null) 'interest_rate': interestRate,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$loanType loan request submitted successfully')),
          );
        } else {
          throw Exception(data['message'] ?? 'Loan request failed');
        }
      } else {
        throw Exception('Loan request failed: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error requesting $loanType loan: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _requestLoan(loanType, maxLimit, recipientId: recipientId, groupId: groupId, interestRate: interestRate),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _lendMoney(String loanType, double maxLimit, {String? borrowerId, String? groupId, double? interestRate}) async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/loan/lend'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lender_id': widget.userId,
          'loan_type': loanType,
          'amount': maxLimit,
          'currency': _selectedCurrency,
          if (borrowerId != null) 'borrower_id': borrowerId,
          if (groupId != null) 'group_id': groupId,
          if (interestRate != null) 'interest_rate': interestRate,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$loanType lending offer submitted successfully')),
          );
        } else {
          throw Exception(data['message'] ?? 'Lending offer failed');
        }
      } else {
        throw Exception('Lending offer failed: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error offering $loanType loan: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _lendMoney(loanType, maxLimit, borrowerId: borrowerId, groupId: groupId, interestRate: interestRate),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showSalaryAdvanceDialog() {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Request Salary Advance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Max: $_selectedCurrency ${userDetails?['earned_salary']?.toStringAsFixed(2) ?? 'N/A'}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount ($_selectedCurrency)',
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
                  if (value == null || value.isEmpty) {
                    return 'Enter amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }
                  if (amount > (userDetails?['earned_salary'] ?? 0.0)) {
                    return 'Amount exceeds earned salary';
                  }
                  return null;
                },
              ),
            ],
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
                _requestLoan('Salary Advance', double.parse(amountController.text));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5BB1B),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  void _showEmergencyLoanDialog() {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    const maxLimit = 10000.0; // KES 10,000

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Request Emergency Loan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Max: $_selectedCurrency ${maxLimit.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount ($_selectedCurrency)',
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
                  if (value == null || value.isEmpty) {
                    return 'Enter amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }
                  if (amount > maxLimit) {
                    return 'Amount exceeds max limit';
                  }
                  return null;
                },
              ),
            ],
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
                _requestLoan('Emergency', double.parse(amountController.text));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5BB1B),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  void _showBusinessLoanDialog() {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    const maxLimit = 50000.0; // Example: KES 50,000 based on credit score

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Request Business/Side Hustle Loan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Max: $_selectedCurrency ${maxLimit.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount ($_selectedCurrency)',
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
                  if (value == null || value.isEmpty) {
                    return 'Enter amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }
                  if (amount > maxLimit) {
                    return 'Amount exceeds max limit';
                  }
                  return null;
                },
              ),
            ],
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
                _requestLoan('Business/Side Hustle', double.parse(amountController.text));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5BB1B),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  void _showP2PFriendLoanDialog(bool isLending) {
    final recipientController = TextEditingController();
    final amountController = TextEditingController();
    final interestController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    const maxLimit = 20000.0; // Example: KES 20,000

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          isLending ? 'Lend to Friend' : 'Borrow from Friend',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Max: $_selectedCurrency ${maxLimit.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: recipientController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: isLending ? 'Friend\'s Phone Number' : 'Friend\'s User ID',
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
                  if (value == null || value.isEmpty) {
                    return 'Enter friend\'s details';
                  }
                  if (isLending && !RegExp(r'^\+?\d{10,12}$').hasMatch(value)) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount ($_selectedCurrency)',
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
                  if (value == null || value.isEmpty) {
                    return 'Enter amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }
                  if (amount > maxLimit) {
                    return 'Amount exceeds max limit';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: interestController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Interest Rate (%) - Optional',
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
                  if (value == null || value.isEmpty) {
                    return null; // Interest is optional
                  }
                  final rate = double.tryParse(value);
                  if (rate == null || rate < 0) {
                    return 'Enter a valid interest rate';
                  }
                  return null;
                },
              ),
            ],
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
                final interestRate = interestController.text.isEmpty ? 0.0 : double.parse(interestController.text);
                if (isLending) {
                  _lendMoney('P2P Friend-to-Friend', double.parse(amountController.text),
                      borrowerId: recipientController.text, interestRate: interestRate);
                } else {
                  _requestLoan('P2P Friend-to-Friend', double.parse(amountController.text),
                      recipientId: recipientController.text, interestRate: interestRate);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5BB1B),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isLending ? 'Lend' : 'Borrow'),
          ),
        ],
      ),
    );
  }

  void _showP2PRelativeLoanDialog(bool isLending) {
    final recipientController = TextEditingController();
    final amountController = TextEditingController();
    final interestController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    const maxLimit = 20000.0; // Example: KES 20,000

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          isLending ? 'Lend to Relative' : 'Borrow from Relative',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Max: $_selectedCurrency ${maxLimit.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: recipientController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: isLending ? 'Relative\'s Phone Number' : 'Relative\'s User ID',
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
                  if (value == null || value.isEmpty) {
                    return 'Enter relative\'s details';
                  }
                  if (isLending && !RegExp(r'^\+?\d{10,12}$').hasMatch(value)) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount ($_selectedCurrency)',
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
                  if (value == null || value.isEmpty) {
                    return 'Enter amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }
                  if (amount > maxLimit) {
                    return 'Amount exceeds max limit';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: interestController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Interest Rate (%) - Optional',
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
                  if (value == null || value.isEmpty) {
                    return null; // Interest is optional
                  }
                  final rate = double.tryParse(value);
                  if (rate == null || rate < 0) {
                    return 'Enter a valid interest rate';
                  }
                  return null;
                },
              ),
            ],
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
                final interestRate = interestController.text.isEmpty ? 0.0 : double.parse(interestController.text);
                if (isLending) {
                  _lendMoney('P2P Relative-to-Relative', double.parse(amountController.text),
                      borrowerId: recipientController.text, interestRate: interestRate);
                } else {
                  _requestLoan('P2P Relative-to-Relative', double.parse(amountController.text),
                      recipientId: recipientController.text, interestRate: interestRate);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5BB1B),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isLending ? 'Lend' : 'Borrow'),
          ),
        ],
      ),
    );
  }

  void _showP2PGroupLoanDialog(bool isLending) {
    final groupController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    const maxLimit = 30000.0; // Example: KES 30,000

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF374151),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          isLending ? 'Contribute to Group Lending' : 'Borrow from Group',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Max: $_selectedCurrency ${maxLimit.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: groupController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Group ID',
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
                  if (value == null || value.isEmpty) {
                    return 'Enter group ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount ($_selectedCurrency)',
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
                  if (value == null || value.isEmpty) {
                    return 'Enter amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }
                  if (amount > maxLimit) {
                    return 'Amount exceeds max limit';
                  }
                  return null;
                },
              ),
            ],
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
                if (isLending) {
                  _lendMoney('P2P Group Lending', double.parse(amountController.text), groupId: groupController.text);
                } else {
                  _requestLoan('P2P Group Lending', double.parse(amountController.text), groupId: groupController.text);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5BB1B),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isLending ? 'Contribute' : 'Borrow'),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => WalletPage(userId: widget.userId)),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoanProducts(userId: widget.userId)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF1F2937),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF374151),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        userDetails != null ? userDetails!['full_name'] ?? 'User' : 'Loading...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Member since 2022',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    userDetails != null ? userDetails!['email'] ?? '' : '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: Color(0xFFF5BB1B)),
              title: const Text('Wallet', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => WalletPage(userId: widget.userId)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.work, color: Color(0xFFF5BB1B)),
              title: const Text('Jobs', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Jobs page
              },
            ),
            ListTile(
              leading: const Icon(Icons.school, color: Color(0xFFF5BB1B)),
              title: const Text('Scholarships & Funding', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Scholarships page
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFFF5BB1B)),
              title: const Text('Chat', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Chat page
              },
            ),
            ListTile(
              leading: const Icon(Icons.leaderboard, color: Color(0xFFF5BB1B)),
              title: const Text('Leaderboard', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Leaderboard page
              },
            ),
            ListTile(
              leading: const Icon(Icons.class_, color: Color(0xFFF5BB1B)),
              title: const Text('Classes', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Classes page
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance, color: Color(0xFFF5BB1B)),
              title: const Text('Loans & Credit', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      drawerEnableOpenDragGesture: true,
      body: isLoading
          ? const Center(
              child: SpinKitFadingCircle(
                color: Color(0xFFF5BB1B),
                size: 50.0,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Loan Products',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      DropdownButton<String>(
                        value: _selectedCurrency,
                        dropdownColor: const Color(0xFF374151),
                        style: const TextStyle(color: Colors.white),
                        underline: Container(),
                        items: ['KES', 'USD', 'EUR'].map((currency) {
                          return DropdownMenuItem(
                            value: currency,
                            child: Text(currency),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCurrency = value!;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Salary Advance Loan
                  _buildLoanCard(
                    icon: Icons.work,
                    title: 'Salary Advance',
                    description: 'For employees, up to your earned salary. Repaid directly from your employer.',
                    maxLimit: userDetails?['earned_salary']?.toDouble() ?? 0.0,
                    onRequest: _showSalaryAdvanceDialog,
                  ),
                  const SizedBox(height: 16),
                  // Emergency Loan
                  _buildLoanCard(
                    icon: Icons.bolt,
                    title: 'Emergency Loan',
                    description: 'Small, instant loans for urgent needs.',
                    maxLimit: 10000.0,
                    onRequest: _showEmergencyLoanDialog,
                  ),
                  const SizedBox(height: 16),
                  // Business/Side Hustle Loan
                  _buildLoanCard(
                    icon: Icons.business,
                    title: 'Business/Side Hustle',
                    description: 'For side hustles, based on repayment history & credit score.',
                    maxLimit: 50000.0,
                    onRequest: _showBusinessLoanDialog,
                  ),
                  const SizedBox(height: 16),
                  // P2P Loans
                  Card(
                    color: const Color(0xFF374151),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.group, color: Color(0xFFF5BB1B)),
                          title: const Text(
                            'P2P Loans',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text(
                            'Borrow or lend directly with other users.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              isP2PExpanded ? Icons.expand_less : Icons.expand_more,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                isP2PExpanded = !isP2PExpanded;
                              });
                            },
                          ),
                        ),
                        if (isP2PExpanded)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Column(
                              children: [
                                _buildP2PSubOption(
                                  title: 'Friend-to-Friend',
                                  description: 'Borrow or lend directly with friends. Optional low/no interest.',
                                  maxLimit: 20000.0,
                                  onBorrow: () => _showP2PFriendLoanDialog(false),
                                  onLend: () => _showP2PFriendLoanDialog(true),
                                ),
                                const SizedBox(height: 8),
                                _buildP2PSubOption(
                                  title: 'Relative-to-Relative',
                                  description: 'Family support with tracked repayments.',
                                  maxLimit: 20000.0,
                                  onBorrow: () => _showP2PRelativeLoanDialog(false),
                                  onLend: () => _showP2PRelativeLoanDialog(true),
                                ),
                                const SizedBox(height: 8),
                                _buildP2PSubOption(
                                  title: 'Group Lending',
                                  description: 'Join a lending circle, contribute, and borrow in turns.',
                                  maxLimit: 30000.0,
                                  onBorrow: () => _showP2PGroupLoanDialog(false),
                                  onLend: () => _showP2PGroupLoanDialog(true),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
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
            currentIndex: 1, // Loans & Credit
            onTap: _onItemTapped,
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

  Widget _buildLoanCard({
    required IconData icon,
    required String title,
    required String description,
    required double maxLimit,
    required VoidCallback onRequest,
  }) {
    return Card(
      color: const Color(0xFF374151),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFF5BB1B), size: 28),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Max: $_selectedCurrency ${maxLimit.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: onRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5BB1B),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Request Loan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildP2PSubOption({
    required String title,
    required String description,
    required double maxLimit,
    required VoidCallback onBorrow,
    required VoidCallback onLend,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D3748),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12.0),
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
          Text(
            description,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            'Max: $_selectedCurrency ${maxLimit.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: onBorrow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5BB1B),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Borrow'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onLend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5BB1B),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Lend'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}