import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_theme.dart';
import '../config/api_config.dart';

class ConfirmPayment extends StatefulWidget {
  const ConfirmPayment({super.key});

  @override
  State<ConfirmPayment> createState() => _ConfirmPaymentState();
}

class _ConfirmPaymentState extends State<ConfirmPayment> {
  bool isBuyGoods = true;
  bool _loading = false;

  final _tillCtrl      = TextEditingController();
  final _accountCtrl   = TextEditingController();
  final _amountCtrl    = TextEditingController();
  final _paybillCtrl   = TextEditingController();

  String? _userId;
  double _walletBalance = 0;
  double _roundUpSavings = 0;
  String _roundingValue = '5';

  @override
  void initState() {
    super.initState();
    _loadUser();
    _amountCtrl.addListener(_recalc);
  }

  @override
  void dispose() {
    _tillCtrl.dispose();
    _accountCtrl.dispose();
    _amountCtrl.dispose();
    _paybillCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('userId') ?? prefs.getInt('userId')?.toString();
    if (id == null) return;
    setState(() => _userId = id);
    await Future.wait([_fetchWallet(id), _fetchRoundupSettings(id)]);
  }

  Future<void> _fetchWallet(String userId) async {
    try {
      final res = await http.get(Uri.parse(ApiConfig.walletById(userId)));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _walletBalance = double.tryParse(data['balance']?.toString() ?? '0') ?? 0);
      }
    } catch (_) {}
  }

  Future<void> _fetchRoundupSettings(String userId) async {
    try {
      final res = await http.get(Uri.parse(ApiConfig.roundupSettingsById(userId)));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['is_enabled'] == true) {
          final rv = data['rounding_value']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '5';
          setState(() => _roundingValue = rv.isEmpty ? '5' : rv);
          _recalc();
        }
      }
    } catch (_) {}
  }

  void _recalc() {
    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    if (amt <= 0) { setState(() => _roundUpSavings = 0); return; }
    final rv = double.tryParse(_roundingValue) ?? 5;
    final rounded = (amt / rv).ceil() * rv;
    setState(() => _roundUpSavings = rounded - amt);
  }

  double get _total => (double.tryParse(_amountCtrl.text) ?? 0) + _roundUpSavings;

  String _formatPhone(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+'), '');
    if (phone.startsWith('0')) return '254${phone.substring(1)}';
    if (phone.startsWith('+')) return phone.substring(1);
    return phone;
  }

  Future<void> _confirmPayment() async {
    if (_loading) return; // guard against double-tap firing this twice
    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    if (_userId == null) return _show('Not logged in');
    if (amt < 10) return _show('Minimum amount is KES 10');

    if (isBuyGoods && _tillCtrl.text.trim().isEmpty) return _show('Enter till number');
    if (!isBuyGoods && _paybillCtrl.text.trim().isEmpty) return _show('Enter paybill number');

    setState(() => _loading = true);
    try {
      final Map<String, dynamic> body;
      final String url;

      if (isBuyGoods) {
        url = ApiConfig.payMerchant;
        body = {
          'user_id': int.tryParse(_userId!) ?? _userId,
          'till_number': _tillCtrl.text.trim(),
          'account_number': _accountCtrl.text.trim(),
          'amount': amt,
          'round_up_savings': _roundUpSavings,
        };
      } else {
        url = ApiConfig.paybillPayment;
        body = {
          'user_id': int.tryParse(_userId!) ?? _userId,
          'phone_number': _formatPhone(_paybillCtrl.text.trim()),
          'amount': amt,
          'merchant_paybill': _paybillCtrl.text.trim(),
          'merchant_account': _accountCtrl.text.trim(),
        };
      }

      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final method = data['payment_method'] ?? 'mpesa_stk';
        if (method == 'wallet') {
          _show('Payment successful from wallet!', success: true);
        } else {
          _show('STK push sent — check your phone to enter M-Pesa PIN.', success: true);
        }
        _amountCtrl.clear();
        _tillCtrl.clear();
        _accountCtrl.clear();
        _paybillCtrl.clear();
        if (_userId != null) _fetchWallet(_userId!);
      } else {
        _show(data['message'] ?? 'Payment failed');
      }
    } catch (e) {
      _show('Network error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _show(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF1B6631) : Colors.red[700],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    final canUseWallet = _walletBalance >= _total && _total > 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        title: const Text('Payment', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Wallet balance chip
            if (_walletBalance > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: canUseWallet ? const Color(0xFFDEFBD7) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: canUseWallet ? const Color(0xFF1B6631) : Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet,
                        size: 16, color: canUseWallet ? const Color(0xFF1B6631) : Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Wallet: KSh ${_walletBalance.toStringAsFixed(2)}${canUseWallet ? ' · will pay from wallet' : ''}',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: canUseWallet ? const Color(0xFF1B6631) : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

            // Buy Goods / Pay Bill toggle
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => isBuyGoods = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBuyGoods ? Colors.yellow : Colors.grey[900],
                      foregroundColor: isBuyGoods ? Colors.black : AppTheme.cardLight,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Buy Goods'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => isBuyGoods = false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isBuyGoods ? AppTheme.textPrimary : Colors.yellow,
                      side: BorderSide(color: isBuyGoods ? Colors.grey : Colors.yellow),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Pay Bill'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Till number (Buy Goods) or Paybill (Pay Bill)
            _field(
              controller: isBuyGoods ? _tillCtrl : _paybillCtrl,
              hint: isBuyGoods ? 'Enter till number' : 'Enter paybill number',
              inputType: TextInputType.number,
            ),
            const SizedBox(height: 14),

            // Account number (both modes)
            _field(
              controller: _accountCtrl,
              hint: isBuyGoods ? 'Account number (optional)' : 'Account number',
              inputType: TextInputType.text,
            ),
            const SizedBox(height: 14),

            // Amount
            _field(
              controller: _amountCtrl,
              hint: 'Enter amount (KSh)',
              inputType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 20),

            // Payment Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Summary',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _summaryRow('Amount', 'KSh ${amt.toStringAsFixed(2)}'),
                  if (_roundUpSavings > 0)
                    _summaryRow('Round-up Savings', '+ KSh ${_roundUpSavings.toStringAsFixed(2)}'),
                  const Divider(color: Colors.grey, height: 20),
                  _summaryRow('Total', 'KSh ${_total.toStringAsFixed(2)}', bold: true),
                  const SizedBox(height: 6),
                  _summaryRow(
                    'Pay via',
                    canUseWallet ? 'Nebo Wallet' : 'M-Pesa STK Push',
                    color: canUseWallet ? const Color(0xFF78FF86) : Colors.orange[300],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _confirmPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(
                        canUseWallet ? 'Pay from Wallet' : 'Send STK Push',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({required TextEditingController controller, required String hint, required TextInputType inputType}) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.textSecondary),
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      style: const TextStyle(color: AppTheme.cardLight),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          Text(value, style: TextStyle(
            color: color ?? (bold ? Colors.yellow : AppTheme.cardLight),
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          )),
        ],
      ),
    );
  }
}
