import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
// Changed to open_file
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'modern_login_screen.dart';

class LoansPage extends StatefulWidget {
  final String userId;
  const LoansPage({super.key, required this.userId});

  @override
  State<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends State<LoansPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? userDetails;
  List<dynamic>? loanDetails;
  Map<String, dynamic>? loanEligibility;
  bool isLoading = true;
  final _formKey = GlobalKey<FormState>();
  String _selectedLoanType = 'salary_advance';
  final _amountController = TextEditingController();
  final _termController = TextEditingController();
  final _repayAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _validateAndFetchData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _termController.dispose();
    _repayAmountController.dispose();
    super.dispose();
  }

  Future<void> _validateAndFetchData() async {
    if (widget.userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid user ID. Please log in again.')),
        );
        await _logout();
      }
      return;
    }
    await fetchUserDetails();
    if (userDetails != null && userDetails!['face_verified'] == true) {
      await Future.wait([
        fetchLoanDetails(),
        fetchLoanEligibility(),
      ]);
    } else {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face verification required. Please update your profile.')),
        );
      }
    }
  }

  Future<void> fetchUserDetails() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/user-details/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            userDetails = data['data'];
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
      if (mounted) {
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
  }

  Future<void> fetchLoanDetails() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/loans/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            loanDetails = data['data'];
            isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load loan details');
        }
      } else {
        throw Exception('Failed to load loan details: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading loan details: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: fetchLoanDetails,
            ),
          ),
        );
      }
    }
  }

  Future<void> fetchLoanEligibility() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/loan-eligibility/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            loanEligibility = data['data'];
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load loan eligibility');
        }
      } else {
        throw Exception('Failed to load loan eligibility: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading loan eligibility: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: fetchLoanEligibility,
            ),
          ),
        );
      }
    }
  }

  Future<void> applyForLoan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/apply-loan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'loan_type': _selectedLoanType,
          'amount': double.parse(_amountController.text),
          'term_months': int.parse(_termController.text),
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loan application submitted: ${data['message']}')),
          );
          await fetchLoanDetails(); // Refresh loan list
        }
      } else {
        throw Exception(data['message'] ?? 'Failed to apply for loan');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error applying for loan: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> repayLoan(String loanId) async {
    if (_repayAmountController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter repayment amount')),
        );
      }
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/repay-loan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'loan_id': loanId,
          'amount': double.parse(_repayAmountController.text),
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loan repayment initiated: ${data['message']}')),
          );
          await fetchLoanDetails(); // Refresh loan list
        }
      } else {
        throw Exception(data['message'] ?? 'Failed to initiate loan repayment');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initiating repayment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ModernLoginScreen()),
      );
    }
  }


  Future<void> generateLoanReport() async {
    final pdf = pw.Document();
    final date = DateTime.now().toString().split(' ')[0];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 1)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Loan Report',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Date: $date',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(width: 1)),
          ),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 16),
          pw.Text(
            'User Details',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Name: ${userDetails?['full_name'] ?? 'Unknown'}'),
          pw.Text('National ID: ${userDetails?['national_id'] ?? 'N/A'}'),
          pw.Text('Email: ${userDetails?['email'] ?? 'N/A'}'),
          pw.SizedBox(height: 24),
          pw.Text(
            'Loan Eligibility',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Credit Score: ${loanEligibility?['credit_score']?.toString() ?? 'N/A'}'),
          pw.Text('Active Loans: ${loanEligibility?['active_loans']?.toString() ?? '0'}'),
          pw.Text('Outstanding Debt: ${loanEligibility?['outstanding_debt']?.toStringAsFixed(2) ?? '0.00'}'),
          pw.SizedBox(height: 16),
          pw.Text(
            'Loan Limits',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (loanEligibility != null && loanEligibility!['loan_limits'] != null)
            for (var entry in (loanEligibility!['loan_limits'] as Map<String, dynamic>).entries)
              pw.Text('${entry.key}: ${entry.value.toStringAsFixed(2)}'),
          pw.SizedBox(height: 24),
          pw.Text(
            'Loan Details',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          if (loanDetails == null || loanDetails!.isEmpty)
            pw.Text('Total Loan Amount: 0.0')
          else ...[
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FractionColumnWidth(0.1),
                1: const pw.FractionColumnWidth(0.2),
                2: const pw.FractionColumnWidth(0.2),
                3: const pw.FractionColumnWidth(0.2),
                4: const pw.FractionColumnWidth(0.3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'No.',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Type',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Amount',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Status',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Due Date',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                for (var i = 0; i < loanDetails!.length; i++)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${i + 1}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(loanDetails![i]['loan_type'] ?? 'N/A'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(loanDetails![i]['amount']?.toStringAsFixed(2) ?? 'N/A'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(loanDetails![i]['status'] ?? 'N/A'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(loanDetails![i]['repayment_due_date'] ?? 'N/A'),
                      ),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Total Loan Amount: ${loanDetails!.fold<double>(0, (sum, loan) => sum + (loan['amount']?.toDouble() ?? 0)).toStringAsFixed(2)}',
            ),
          ],
        ],
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/loan_report_${widget.userId}.pdf');
      await file.writeAsBytes(await pdf.save());
      if (mounted) {
        // Using OpenFile.open instead of OpenFilex.open
        await OpenFile.open(file.path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loan report downloaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  void _showLoanApplicationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardLight,
        title: const Text(
          'Apply for a Loan',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedLoanType,
                  decoration: const InputDecoration(
                    labelText: 'Loan Type',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.textSecondary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.financeGreenV3),
                    ),
                  ),
                  dropdownColor: AppColors.coreWhiteW1,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 'salary_advance', child: Text('Salary Advance')),
                    DropdownMenuItem(value: 'emergency', child: Text('Emergency')),
                    DropdownMenuItem(value: 'business', child: Text('Business')),
                    DropdownMenuItem(value: 'p2p', child: Text('P2P')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedLoanType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (KSh)',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.textSecondary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.financeGreenV3),
                    ),
                  ),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Please enter a valid amount';
                    }
                    if (loanEligibility != null && loanEligibility!['loan_limits'] != null) {
                      final maxLimit = loanEligibility!['loan_limits'][_selectedLoanType] ?? 0;
                      if (amount > maxLimit) {
                        return 'Amount exceeds limit of KSh $maxLimit';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _termController,
                  decoration: const InputDecoration(
                    labelText: 'Term (Months)',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.textSecondary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.financeGreenV3),
                    ),
                  ),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter term in months';
                    }
                    final term = int.tryParse(value);
                    if (term == null || term <= 0) {
                      return 'Please enter a valid term';
                    }
                    final maxTerms = {
                      'salary_advance': 3,
                      'emergency': 1,
                      'business': 6,
                      'p2p': 3,
                    };
                    if (term > maxTerms[_selectedLoanType]!) {
                      return 'Term exceeds max of ${maxTerms[_selectedLoanType]} months';
                    }
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
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: applyForLoan,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.financeGreenV3,
              foregroundColor: Colors.black,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showRepayLoanDialog(String loanId, double totalRepayable) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardLight,
        title: const Text(
          'Repay Loan',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total Repayable: KSh ${totalRepayable.toStringAsFixed(2)}',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _repayAmountController,
              decoration: const InputDecoration(
                labelText: 'Repayment Amount (KSh)',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.textSecondary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.financeGreenV3),
                ),
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => repayLoan(loanId),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.financeGreenV3,
              foregroundColor: Colors.black,
            ),
            child: const Text('Repay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalLoanAmount = loanDetails != null && loanDetails!.isNotEmpty
        ? loanDetails!.fold<double>(0, (sum, loan) => sum + (loan['amount']?.toDouble() ?? 0)).toStringAsFixed(2)
        : '0.00';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.backgroundLight,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundLight,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: Color(0xFF111827)),
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
                          color: Color(0xFF111827),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Member since 2022',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications, color: AppColors.financeGreen),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: AppTheme.cardLight,
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
                    backgroundColor: AppColors.coreWhiteW2,
                    child: userDetails != null && userDetails!['selfie_path'] != null
                        ? CachedNetworkImage(
                            imageUrl: userDetails!['selfie_path'],
                            fit: BoxFit.cover,
                            width: 56,
                            height: 56,
                          )
                        : const Icon(Icons.person, size: 28, color: AppTheme.cardLight),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userDetails != null ? userDetails!['full_name'] ?? 'User' : 'Loading...',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    userDetails != null ? userDetails!['email'] ?? '' : '',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: AppColors.financeGreenV3),
              title: const Text('Wallet', style: TextStyle(color: AppTheme.cardLight)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Wallet page
              },
            ),
            ListTile(
              leading: const Icon(Icons.work, color: AppColors.financeGreenV3),
              title: const Text('Jobs', style: TextStyle(color: AppTheme.cardLight)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Jobs page
              },
            ),
            ListTile(
              leading: const Icon(Icons.school, color: AppColors.financeGreenV3),
              title: const Text('Scholarships & Funding', style: TextStyle(color: AppTheme.cardLight)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Scholarships page
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: AppColors.financeGreenV3),
              title: const Text('Chat', style: TextStyle(color: AppTheme.cardLight)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Chat page
              },
            ),
            ListTile(
              leading: const Icon(Icons.leaderboard, color: AppColors.financeGreenV3),
              title: const Text('Leaderboard', style: TextStyle(color: AppTheme.cardLight)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Leaderboard page
              },
            ),
            ListTile(
              leading: const Icon(Icons.class_, color: AppColors.financeGreenV3),
              title: const Text('Classes', style: TextStyle(color: AppTheme.cardLight)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Classes page
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance, color: AppColors.financeGreenV3),
              title: const Text('Loans & Credit', style: TextStyle(color: AppTheme.cardLight)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoansPage(userId: widget.userId)),
                );
              },
            ),
          ],
        ),
      ),
      drawerEnableOpenDragGesture: true,
      body: isLoading
          ? const Center(
              child: SpinKitFadingCircle(
                color: AppColors.financeGreenV3,
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
                        'Your Loans',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: userDetails?['face_verified'] == true ? _showLoanApplicationDialog : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: userDetails?['face_verified'] == true
                              ? AppColors.financeGreenV3
                              : Colors.grey,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Apply for Loan'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: AppTheme.cardLight,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credit Score: ${loanEligibility?['credit_score']?.toString() ?? 'N/A'}',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total Loan Amount: KSh $totalLoanAmount',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Number of Loans: ${loanDetails?.length ?? 0}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Outstanding Debt: KSh ${loanEligibility?['outstanding_debt']?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Loan Limits:',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (loanEligibility != null && loanEligibility!['loan_limits'] != null)
                            for (var entry in (loanEligibility!['loan_limits'] as Map<String, dynamic>).entries)
                              Text(
                                '${entry.key}: KSh ${entry.value.toStringAsFixed(2)}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  loanDetails == null || loanDetails!.isEmpty
                      ? const Center(
                          child: Text(
                            'No loans found',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: loanDetails!.length,
                          itemBuilder: (context, index) {
                            final loan = loanDetails![index];
                            return Card(
                              color: AppColors.coreWhiteW1,
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16.0),
                                title: Text(
                                  'Loan ${index + 1}: ${loan['loan_type']} - KSh ${loan['amount']?.toStringAsFixed(2) ?? 'N/A'}',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Status: ${loan['status'] ?? 'N/A'}',
                                      style: const TextStyle(color: AppTheme.textSecondary),
                                    ),
                                    Text(
                                      'Due Date: ${loan['repayment_due_date'] ?? 'N/A'}',
                                      style: const TextStyle(color: AppTheme.textSecondary),
                                    ),
                                    Text(
                                      'Total Repayable: KSh ${loan['total_repayable']?.toStringAsFixed(2) ?? 'N/A'}',
                                      style: const TextStyle(color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                                trailing: loan['status'] == 'disbursed'
                                    ? IconButton(
                                        icon: const Icon(Icons.payment, color: AppColors.financeGreenV3),
                                        onPressed: () => _showRepayLoanDialog(
                                          loan['id'].toString(),
                                          loan['total_repayable'].toDouble(),
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: AppTheme.backgroundLight,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: generateLoanReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.financeGreenV3,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: const Text('Download Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

