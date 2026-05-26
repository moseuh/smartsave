import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:smartsave/screens/modern_login_screen.dart';
import 'dart:convert';
import '../config/api_config.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:signature/signature.dart';
import 'wallet_page.dart';
import 'buygoodselect.dart';
import 'profile.dart';

const Map<String, Color> _kStatusColors = {
  'submitting': Colors.orange,
  'pending': Colors.grey,
  'reviewing': Colors.blue,
  'approved': Colors.green,
  'rejected': Colors.red,
  'active': Colors.green,
  'disbursed': Colors.green,
  'closed': Colors.grey,
};

const Map<String, String> _kStatusTexts = {
  'submitting': 'Submittingâ€¦',
  'pending': 'Pending',
  'reviewing': 'Reviewingâ€¦',
  'approved': 'Approved!',
  'rejected': 'Rejected',
};

class LoanProducts extends StatefulWidget {
  final String userId;
  const LoanProducts({super.key, required this.userId});

  @override
  State<LoanProducts> createState() => _LoanProductsState();
}

class _LoanProductsState extends State<LoanProducts> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? userDetails;
  bool isLoading = true;
  late AnimationController _knobController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _autoLendEnabled = false;

  @override
  void initState() {
    super.initState();
    _knobController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();
    _validateAndFetchUserDetails();
  }

  @override
  void dispose() {
    _knobController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ----------------- Helpers -----------------
  Widget _p2pBigButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.financeGreenV3,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  InputDecoration _inputDec(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.textSecondary),
        borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.financeGreenV3),
        borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _monthsSlider(TextEditingController controller, {required double min, required double max}) {
    return StatefulBuilder(
      builder: (ctx, setStateSlider) => Column(
        children: [
          Slider(
            value: double.tryParse(controller.text) ?? min,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            label: '${controller.text} months',
            activeColor: AppColors.financeGreenV3,
            onChanged: (v) {
              setStateSlider(() => controller.text = v.toInt().toString());
            },
          ),
          Text('Duration: ${controller.text} months', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  // ----------------- Public P2P Loan Request (Variable Interest Rate) -----------------
  void _showPublicP2PFlow() {
    final amountCtrl = TextEditingController();
    final monthsCtrl = TextEditingController(text: '6');
    final interestCtrl = TextEditingController(text: '15.0');
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Post Public P2P Loan Request', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.cardLight),
                decoration: _inputDec('Loan Amount (KES)'),
                validator: (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null || val <= 0) return 'Enter valid amount';
                  if (val < 1000) return 'Minimum KES 1,000';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _monthsSlider(monthsCtrl, min: 1, max: 36),
              const SizedBox(height: 20),
              const Text('Maximum Interest Rate You\'ll Accept (%)', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setState) => Column(
                  children: [
                    Slider(
                      value: double.tryParse(interestCtrl.text) ?? 15.0,
                      min: 8.0,
                      max: 225.0,
                      divisions: 134,
                      label: '${interestCtrl.text}%',
                      activeColor: AppColors.financeGreenV3,
                      onChanged: (value) {
                        setState(() => interestCtrl.text = value.toStringAsFixed(1));
                      },
                    ),
                    Text('You will accept offers up to ${interestCtrl.text}% p.a.', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    const Text('Lower rate = faster funding, but fewer offers', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descCtrl,
                maxLines: 3,
                style: const TextStyle(color: AppTheme.cardLight),
                decoration: _inputDec('Loan Purpose (optional)'),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.coreWhiteW1,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Lenders will see your max rate and offer at or below it.\nCurrent market: 10â€“20% p.a. (avg ~15%)',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreenV3),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                _submitPublicP2PLoanRequest(
                  amount: double.parse(amountCtrl.text),
                  tenureMonths: int.parse(monthsCtrl.text),
                  interestRate: double.parse(interestCtrl.text),
                  purpose: descCtrl.text.trim(),
                );
              }
            },
            child: const Text('submit', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPublicP2PLoanRequest({
    required double amount,
    required int tenureMonths,
    required double interestRate,
    required String purpose,
  }) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: AppTheme.cardLight,
        content: Column(mainAxisSize: MainAxisSize.min, children: [LoanStatusKnob(status: 'submitting')]),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.loanRequest),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'amount': amount,
          'tenure_months': tenureMonths,
          'interest_rate': interestRate,
          if (purpose.isNotEmpty) 'purpose': purpose,
        }),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final loanId = data['loan_id'] ?? 'N/A';

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppTheme.cardLight,
            title: const Text('Request Posted!', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 16),
                Text('KES ${amount.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Max ${interestRate.toStringAsFixed(1)}% p.a. â€¢ $tenureMonths months', style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                Text('Loan ID: $loanId', style: const TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      } else {
        String msg = 'Failed';
        try {
          final err = jsonDecode(response.body);
          msg = err['message'] ?? msg;
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $msg')));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ----------------- Friends & Family -----------------
  void _showFriendsFamilyFlow() async {
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts permission required')),
      );
      return;
    }
    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) return;
      final phoneRaw = contact.phones.isNotEmpty ? contact.phones.first.number : null;
      final phone = phoneRaw?.replaceAll(RegExp(r'\D'), '');
      if (phone == null || phone.length < 9) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid phone number')));
        return;
      }
      final name = contact.displayName ?? 'Unknown';

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.cardLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Deal with $name', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _p2pBigButton('I want to BORROW from $name', () => _friendLoanFlow(name, phone, true)),
            const SizedBox(height: 16),
            _p2pBigButton('I am LENDING to $name', () => _friendLoanFlow(name, phone, false)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _friendLoanFlow(String name, String phone, bool isBorrowing) {
    Navigator.pop(context);
    final amountCtrl = TextEditingController();
    final monthsCtrl = TextEditingController(text: '1');
    final reasonCtrl = TextEditingController();
    final sigCtrl = SignatureController(penStrokeWidth: 5, penColor: AppTheme.cardLight);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppTheme.cardLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isBorrowing ? 'Borrow from $name' : 'Lend to $name', style: const TextStyle(color: AppTheme.cardLight)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 35, child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 30, color: AppTheme.cardLight))),
              const SizedBox(height: 8),
              Text(phone, style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 20),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: _inputDec('Amount (KES)'), style: const TextStyle(color: AppTheme.cardLight)),
              const SizedBox(height: 12),
              _monthsSlider(monthsCtrl, min: 1, max: 36),
              const SizedBox(height: 12),
              TextField(controller: reasonCtrl, decoration: _inputDec('Reason (optional)'), style: const TextStyle(color: AppTheme.cardLight)),
              const SizedBox(height: 20),
              const Text('E-Signature', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              Container(
                height: 180,
                decoration: BoxDecoration(border: Border.all(color: AppTheme.textSecondary), borderRadius: BorderRadius.circular(12)),
                child: Signature(controller: sigCtrl, backgroundColor: AppColors.coreWhiteW1),
              ),
              TextButton(onPressed: () => sigCtrl.clear(), child: const Text('Clear Signature', style: TextStyle(color: Colors.red))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreenV3),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount <= 0) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid amount')));
                  return;
                }
                if (sigCtrl.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign')));
                  return;
                }
                final sigBytes = await sigCtrl.toPngBytes();
                if (!mounted) return;
                Navigator.pop(context);
                await _saveFriendFamilyLoan(
                  name: name,
                  phone: phone,
                  amount: amount,
                  months: int.parse(monthsCtrl.text),
                  reason: reasonCtrl.text,
                  isBorrowing: isBorrowing,
                  signature: sigBytes,
                );
              },
              child: const Text('Send Agreement'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveFriendFamilyLoan({
    required String name,
    required String phone,
    required double amount,
    required int months,
    required String reason,
    required bool isBorrowing,
    required Uint8List? signature,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final loan = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'contact_name': name,
      'phone': phone,
      'amount': amount,
      'months': months,
      'reason': reason.isEmpty ? null : reason,
      'is_borrowing': isBorrowing,
      'status': 'sent',
      'type': 'friend_family',
      'created_at': DateTime.now().toIso8601String(),
      'signature_base64': signature != null ? base64Encode(signature) : null,
    };
    final list = prefs.getStringList('friend_family_loans') ?? [];
    list.add(jsonEncode(loan));
    await prefs.setStringList('friend_family_loans', list);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isBorrowing ? 'Borrow request sent to $name!' : 'Lending offer sent to $name!'),
      backgroundColor: Colors.green,
    ));

    if (signature != null && mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.cardLight,
          title: const Text('Agreement Sent!', style: TextStyle(color: AppTheme.cardLight)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('KES ${amount.toStringAsFixed(0)} â€¢ $months months', style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            Image.memory(signature, height: 140),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
  }

  // ----------------- Bank Loans (Now POSTS TO BACKEND) -----------------
  Future<void> _submitBankLoanRequest({
    required double amount,
    required int months,
    required String loanType,
  }) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: AppTheme.cardLight,
        content: Column(mainAxisSize: MainAxisSize.min, children: [LoanStatusKnob(status: 'submitting')]),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.bankLoanRequest),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'amount': amount,
          'tenure_months': months,
          'loan_type': loanType,
        }),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final loanId = data['loan_id'] ?? 'N/A';

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppTheme.cardLight,
            title: const Text('Bank Loan Submitted!', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 16),
                Text('KES ${amount.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('$months months â€¢ ${loanType.replaceAll('_', ' ').toUpperCase()}', style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                Text('Request ID: $loanId', style: const TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      } else {
        String msg = 'Submission failed';
        try {
          final err = jsonDecode(response.body);
          msg = err['message'] ?? msg;
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  void _showLoanOffersDialog(String category) async {
    final allOffers = [
      {'id': 1, 'title': 'Salary Advance', 'max_amount': 50000.0, 'interest': 8.5, 'max_months': 3},
      {'id': 2, 'title': 'Emergency Loan', 'max_amount': 100000.0, 'interest': 12.0, 'max_months': 2},
      {'id': 3, 'title': 'Business Loan', 'max_amount': 500000.0, 'interest': 10.0, 'max_months': 6},
    ];
    final offers = allOffers.where((o) => (o['title'] as String).toLowerCase().contains(category.toLowerCase())).toList();
    if (offers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No offers available')));
      return;
    }
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.cardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Select $category Offer', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: offers.length,
            itemBuilder: (ctx, i) {
              final offer = offers[i];
              return Card(
                color: AppColors.coreWhiteW1,
                child: ListTile(
                  title: Text(offer['title'] as String, style: const TextStyle(color: AppTheme.cardLight)),
                  subtitle: Text('Max: KES ${(offer['max_amount'] as num).toStringAsFixed(0)} â€¢ ${(offer['interest'] as num).toStringAsFixed(1)}% â€¢ ${offer['max_months']} mo',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.textSecondary, size: 16),
                  onTap: () {
                    Navigator.pop(c);
                    _showAmountAndTermDialog(offer, category);
                  },
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)))],
      ),
    );
  }

  void _showAmountAndTermDialog(Map<String, dynamic> offer, String category) {
    final double userSavings = (userDetails?['savings'] as num?)?.toDouble() ?? 0.0;
    final double maxAllowed = userSavings * 2;
    final amountCtrl = TextEditingController();
    final monthsCtrl = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    String loanType = '';
    if (category.toLowerCase().contains('salary')) loanType = 'salary_advance';
    else if (category.toLowerCase().contains('emergency')) loanType = 'emergency';
    else if (category.toLowerCase().contains('business')) loanType = 'business';

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.cardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Request ${offer['title'] as String}', style: const TextStyle(color: AppTheme.cardLight)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Max Offer:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text('KES ${(offer['max_amount'] as num).toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Your Savings:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text('KES ${userSavings.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Max Loan (2Ã—):', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text('KES ${maxAllowed.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.cardLight),
                decoration: _inputDec('Amount (KES)'),
                validator: (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null || val <= 0) return 'Invalid amount';
                  if (val > (offer['max_amount'] as num).toDouble()) return 'Exceeds max';
                  if (val > maxAllowed) return 'Max 2Ã— savings';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _monthsSlider(monthsCtrl, min: 1, max: (offer['max_months'] as num).toDouble()),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreenV3),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(c);
                _submitBankLoanRequest(
                  amount: double.parse(amountCtrl.text),
                  months: int.parse(monthsCtrl.text),
                  loanType: loanType,
                );
              }
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  // ----------------- API Methods -----------------
  Future<List<Map<String, dynamic>>> _fetchPendingLoans() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.pendingLoans));
      if (response.statusCode == 200) {
        final dynamic json = jsonDecode(response.body);
        if (json is List) return List<Map<String, dynamic>>.from(json);
        if (json is Map && json['data'] is List) return List<Map<String, dynamic>>.from(json['data']);
      }
    } catch (e) {
      debugPrint('Fetch pending loans error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchP2PPortfolio() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.p2pPortfolio(widget.userId)));
      if (response.statusCode == 200) {
        final dynamic json = jsonDecode(response.body);
        if (json is List) return List<Map<String, dynamic>>.from(json);
        if (json is Map && json['data'] is List) return List<Map<String, dynamic>>.from(json['data']);
      }
    } catch (e) {
      debugPrint('Portfolio error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchMyLoanRequests() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.pendingLoans));
      if (response.statusCode == 200) {
        final dynamic json = jsonDecode(response.body);
        List<dynamic> allRequests = [];
        if (json is List) allRequests = json;
        if (json is Map && json['data'] is List) allRequests = json['data'];
        return allRequests
            .where((r) => (r['user_id']?.toString() ?? '') == widget.userId)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint('My requests error: $e');
    }
    return [];
  }

  Future<void> _makeManualLend({required String loanRequestId, required double amount}) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.manualLend),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'lender_id': widget.userId, 'loan_request_id': loanRequestId, 'amount': amount}),
      );
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lent successfully!'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error ${response.statusCode}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _toggleAutoLend(bool enabled) async {
    if (!enabled) {
      setState(() => _autoLendEnabled = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto-Lend disabled')));
      return;
    }

    final totalCtrl = TextEditingController(text: '100000');
    final maxPerCtrl = TextEditingController(text: '20000');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardLight,
        title: const Text('Activate Auto-Lend'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: totalCtrl, keyboardType: TextInputType.number, decoration: _inputDec('Total Amount (KES)')),
          const SizedBox(height: 12),
          TextField(controller: maxPerCtrl, keyboardType: TextInputType.number, decoration: _inputDec('Max per Loan (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreenV3),
            onPressed: () async {
              final total = double.tryParse(totalCtrl.text) ?? 0;
              final maxPer = double.tryParse(maxPerCtrl.text);
              if (total <= 0) return;
              Navigator.pop(context);
              try {
                final response = await http.post(
                  Uri.parse(ApiConfig.autoLend),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'lender_id': widget.userId,
                    'amount': total,
                    if (maxPer != null) 'max_per_loan': maxPer,
                  }),
                );
                if (!mounted) return;
                if (response.statusCode == 200) {
                  setState(() => _autoLendEnabled = true);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto-Lend enabled!'), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error ${response.statusCode}')));
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto-Lend error: $e')));
              }
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(String? risk) {
    switch (risk?.toLowerCase()) {
      case 'low': return Colors.green;
      case 'medium': return Colors.orange;
      case 'high': return Colors.red;
      default: return Colors.grey;
    }
  }

  // ----------------- Public P2P Panel -----------------
  void _openPublicP2PPanel() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.cardLight,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: DefaultTabController(
          length: 3,
          child: SizedBox(
            height: 560,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(color: AppColors.coreWhiteW1, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Public P2P', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(icon: const Icon(Icons.close, color: AppTheme.textSecondary), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                const TabBar(
                  labelColor: AppColors.financeGreenV3,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppColors.financeGreenV3,
                  tabs: [Tab(text: 'Portfolio'), Tab(text: 'My Requests'), Tab(text: 'Lend')],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Portfolio Tab
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _fetchP2PPortfolio(),
                        builder: (c, snap) {
                          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: AppColors.financeGreenV3));
                          final loans = snap.data ?? [];
                          if (loans.isEmpty) return const Center(child: Text('No active investments yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)));

                          final totalLent = loans.fold<double>(0.0, (s, l) => s + (l['amount'] as num).toDouble());
                          final totalReturn = loans.fold<double>(0.0, (sum, l) => sum + ((l['expected_return'] as num?)?.toDouble() ?? 0.0));

                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                                Column(children: [
                                  const Text('Total Lent', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text('KES ${totalLent.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontSize: 20, fontWeight: FontWeight.bold)),
                                ]),
                                Column(children: [
                                  const Text('Expected Return', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text('KES ${totalReturn.toStringAsFixed(0)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                                ]),
                              ]),
                              const SizedBox(height: 20),
                              ...loans.map((l) => Card(
                                color: AppColors.coreWhiteW1,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                        Expanded(child: Text((l['borrower_name'] ?? l['full_name'] ?? 'Unknown') as String, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18))),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(color: _getRiskColor(l['risk_level'] as String?), borderRadius: BorderRadius.circular(20)),
                                          child: Text(l['risk_level'] ?? 'N/A', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                      ]),
                                      const SizedBox(height: 12),
                                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          const Text('Lent Amount', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                          Text('KES ${(l['amount'] as num).toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                        ]),
                                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          const Text('Interest Rate', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                          Text('${l['interest_rate'] ?? l['interest'] ?? 'N/A'}%', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                                        ]),
                                      ]),
                                      const SizedBox(height: 12),
                                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          const Text('Tenure', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                          Text('${l['tenure_months'] ?? 'N/A'} months', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                                        ]),
                                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          const Text('Due Date', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                          Text(l['due_date'] ?? 'N/A', style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                                        ]),
                                      ]),
                                      const SizedBox(height: 12),
                                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          const Text('Status', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                          Text(l['status'] ?? 'Unknown', style: TextStyle(color: _kStatusColors[(l['status'] as String?)?.toLowerCase()] ?? Colors.grey, fontWeight: FontWeight.bold, fontSize: 15)),
                                        ]),
                                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                          const Text('Expected Return', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                          Text('KES ${(l['expected_return'] as num?)?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                                        ]),
                                      ]),
                                    ],
                                  ),
                                ),
                              )),
                            ],
                          );
                        },
                      ),

                      // My Requests Tab
                      Stack(
                        children: [
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _fetchMyLoanRequests(),
                            builder: (c, snap) {
                              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: AppColors.financeGreenV3));
                              final requests = snap.data ?? [];
                              if (requests.isEmpty) return const Center(child: Text('No active requests\nTap + to create one', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)));
                              return ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: requests.length,
                                itemBuilder: (_, i) {
                                  final r = requests[i];
                                  return Card(
                                    color: AppColors.coreWhiteW1,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                            Text('Request #${r['id']}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                                            Text(r['status'] ?? 'Pending', style: TextStyle(color: _kStatusColors[(r['status'] as String?)?.toLowerCase()] ?? Colors.grey)),
                                          ]),
                                          const SizedBox(height: 12),
                                          Text('Amount: KES ${(r['amount'] ?? r['amount_requested'])?.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                                          Text('Max Rate: ${r['interest_rate'] ?? 'N/A'}% â€¢ ${r['tenure_months']} months', style: const TextStyle(color: AppTheme.textSecondary)),
                                          Text('Created: ${r['created_at'] ?? 'N/A'}', style: const TextStyle(color: AppTheme.textSecondary)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          Positioned(
                            bottom: 20,
                            right: 20,
                            child: FloatingActionButton(
                              backgroundColor: AppColors.financeGreenV3,
                              onPressed: () {
                                Navigator.pop(context);
                                _showPublicP2PFlow();
                              },
                              child: const Icon(Icons.add, color: Colors.black),
                            ),
                          ),
                        ],
                      ),

                      // Lend Tab
                      StatefulBuilder(
                        builder: (lendCtx, setLendState) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Available Loan Requests', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 12),
                              Expanded(
                                child: FutureBuilder<List<Map<String, dynamic>>>(
                                  future: _fetchPendingLoans(),
                                  builder: (c, snap) {
                                    if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: AppColors.financeGreenV3));
                                    final requests = snap.data ?? [];
                                    if (requests.isEmpty) return const Center(child: Text('No open requests at the moment', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)));

                                    return ListView.builder(
                                      itemCount: requests.length,
                                      itemBuilder: (_, i) {
                                        final r = requests[i];
                                        final maxRate = r['interest_rate'] ?? 'N/A';
                                        return Card(
                                          color: AppColors.coreWhiteW1,
                                          margin: const EdgeInsets.only(bottom: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          child: ListTile(
                                            contentPadding: const EdgeInsets.all(16),
                                            title: Text('KES ${(r['amount'] ?? r['amount_requested'])}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                                            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Text('Max Rate: $maxRate% â€¢ ${r['tenure_months']} months', style: const TextStyle(color: AppTheme.textSecondary)),
                                              Text('Borrower: ${r['full_name'] ?? 'Anonymous'}', style: const TextStyle(color: AppTheme.textSecondary)),
                                            ]),
                                            trailing: ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreenV3),
                                              onPressed: () {
                                                final ctrl = TextEditingController(text: (r['amount'] ?? r['amount_requested']).toString());
                                                showDialog(
                                                  context: context,
                                                  builder: (_) => AlertDialog(
                                                    backgroundColor: AppTheme.cardLight,
                                                    title: const Text('How much to lend?', style: TextStyle(color: AppTheme.cardLight)),
                                                    content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: _inputDec('Amount (KES)')),
                                                    actions: [
                                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreenV3),
                                                        onPressed: () {
                                                          final amt = double.tryParse(ctrl.text) ?? 0;
                                                          if (amt > 0) {
                                                            Navigator.pop(context);
                                                            _makeManualLend(loanRequestId: r['id'].toString(), amount: amt);
                                                          }
                                                        },
                                                        child: const Text('Lend Now'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              child: const Text('Lend', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              const Divider(color: Colors.white24),
                              SwitchListTile(
                                title: const Text('Auto-Lending', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                                subtitle: const Text('Automatically lend to qualified requests', style: TextStyle(color: AppTheme.textSecondary)),
                                value: _autoLendEnabled,
                                onChanged: (v) {
                                  setLendState(() => _autoLendEnabled = v);
                                  _toggleAutoLend(v);
                                },
                                activeColor: AppColors.financeGreenV3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----------------- UI Build Methods -----------------
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.cardLight,
      elevation: 0,
      title: const Text('Loan Products', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
      leading: IconButton(icon: const Icon(Icons.menu, color: AppTheme.cardLight), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppTheme.cardLight,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.coreWhiteW1),
            child: Text(userDetails?['name'] as String? ?? 'User', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.textSecondary),
            title: const Text('Logout', style: TextStyle(color: AppTheme.cardLight)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: Card(
              color: AppTheme.cardLight,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome}!', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.coreWhiteW1, borderRadius: BorderRadius.circular(8)),
                      child: Text('Your Savings: KES ${(userDetails?['savings'] as num?)?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Bank Loans', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            color: AppTheme.cardLight,
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreenV3, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: () => _showLoanOffersDialog('Salary'), child: const Text('ðŸ’¼ Salary Advance', style: TextStyle(fontWeight: FontWeight.bold)))),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreenV3, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: () => _showLoanOffersDialog('Emergency'), child: const Text('ðŸš¨ Emergency Loan', style: TextStyle(fontWeight: FontWeight.bold)))),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreenV3, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: () => _showLoanOffersDialog('Business'), child: const Text('ðŸ“Š Business Loan', style: TextStyle(fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('P2P & Friends/Family', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            color: AppTheme.cardLight,
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.public, color: AppColors.financeGreenV3),
                  title: const Text('Public P2P', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Portfolio â€¢ Borrowers â€¢ Lenders', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.textSecondary, size: 16),
                  onTap: _openPublicP2PPanel,
                ),
                const Divider(color: Colors.white24, height: 1),
                ListTile(
                  leading: const Icon(Icons.contacts, color: AppColors.financeGreenV3),
                  title: const Text('Friends & Family', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Connect with known contacts', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.textSecondary, size: 16),
                  onTap: _showFriendsFamilyFlow,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      backgroundColor: AppTheme.cardLight,
      selectedItemColor: AppColors.financeGreenV3,
      unselectedItemColor: AppTheme.textSecondary,
      currentIndex: 1,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: 'Loans'),
        BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payments'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }

  Future<void> _validateAndFetchUserDetails() async {
    if (widget.userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid user ID')));
      await _logout();
      return;
    }
    await fetchUserDetails();
  }

  Future<void> fetchUserDetails() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(ApiConfig.userDetailsById(widget.userId)));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            userDetails = data['data'];
            isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed');
        }
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), action: SnackBarAction(label: 'Retry', onPressed: fetchUserDetails)));
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ModernLoginScreen()));
    }
  }

  void _onItemTapped(int index) {
    final pages = [
      WalletPage(userId: widget.userId),
      LoanProducts(userId: widget.userId),
      BuyGoodsSelect(userId: widget.userId),
      Profile(userId: widget.userId),
    ];
    if (index != 1 && index < pages.length) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => pages[index]));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.coreDark,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: isLoading
          ? Center(child: RotationTransition(turns: _knobController, child: const Icon(Icons.autorenew, size: 80, color: AppColors.financeGreenV3)))
          : _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}

class LoanStatusKnob extends StatefulWidget {
  final String status;
  const LoanStatusKnob({super.key, required this.status});

  @override
  State<LoanStatusKnob> createState() => _LoanStatusKnobState();
}

class _LoanStatusKnobState extends State<LoanStatusKnob> with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> rotation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    rotation = Tween<double>(begin: 0, end: 1).animate(controller);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isRotating = widget.status == 'submitting' || widget.status == 'reviewing';
    final color = _kStatusColors[widget.status] ?? Colors.grey;
    final text = _kStatusTexts[widget.status] ?? 'Processing';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RotationTransition(
          turns: isRotating ? rotation : const AlwaysStoppedAnimation(0),
          child: Icon(Icons.autorenew, size: 64, color: color),
        ),
        const SizedBox(height: 12),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
