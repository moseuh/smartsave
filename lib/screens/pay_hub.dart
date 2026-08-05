import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants/app_theme.dart';
import '../config/api_config.dart';
import '../utils/validation_utils.dart';

// Deposit and Withdraw sheets, shared by Home's floating action bubble menu
// (Deposit / Withdraw / Pay) so the logic lives in one place instead of
// being duplicated across screens.

// ── Deposit sheet (moved from home_tab.dart, unchanged logic) ─────────────
class PayDepositSheet extends StatefulWidget {
  final String userId;
  final TextEditingController phoneCtrl;
  final TextEditingController amtCtrl;
  final VoidCallback onSuccess;
  const PayDepositSheet(
      {super.key,
      required this.userId,
      required this.phoneCtrl,
      required this.amtCtrl,
      required this.onSuccess});

  @override
  State<PayDepositSheet> createState() => _PayDepositSheetState();
}

class _PayDepositSheetState extends State<PayDepositSheet> {
  bool _loading = false;
  String? _error;
  String? _checkoutRef;
  bool _polling = false;
  bool _paid = false;
  int _pollCount = 0;
  static const int _maxPolls = 22;

  @override
  void dispose() {
    _polling = false;
    super.dispose();
  }

  Future<void> _sendSTK() async {
    final amt = double.tryParse(widget.amtCtrl.text.replaceAll(',', ''));
    if (amt == null || amt < 10) {
      setState(() => _error = 'Minimum amount is KES 10');
      return;
    }
    final phoneError = ValidationUtils.validateKenyanPhone(widget.phoneCtrl.text);
    if (phoneError != null) {
      setState(() => _error = phoneError);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .post(
            Uri.parse(ApiConfig.getUrl('deposit')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': widget.userId,
              'amount': amt,
              'phone': widget.phoneCtrl.text.trim()
            }),
          )
          .timeout(const Duration(seconds: 20));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          _loading = false;
          _checkoutRef = data['checkout_id']?.toString() ?? '';
        });
        _startPolling();
      } else {
        setState(() {
          _loading = false;
          _error = data['message'] ?? 'Failed to send STK Push';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Network error — check your connection';
      });
    }
  }

  void _startPolling() {
    _polling = true;
    _pollCount = 0;
    Future.doWhile(() async {
      if (!_polling || !mounted) return false;
      await Future.delayed(const Duration(seconds: 8));
      if (!_polling || !mounted) return false;
      _pollCount++;
      if (_pollCount >= _maxPolls) {
        if (mounted) {
          setState(() {
            _polling = false;
            _checkoutRef = null;
            _error = 'Timed out. If debited, balance will update shortly.';
          });
        }
        return false;
      }
      try {
        final ref = _checkoutRef ?? '';
        if (ref.isEmpty) return false;
        final res = await http
            .get(Uri.parse(ApiConfig.transactionStatus(ref)))
            .timeout(const Duration(seconds: 10));
        final data = jsonDecode(res.body);
        final status = (data['payment_status'] ?? data['status'] ?? '').toString().toUpperCase();
        if (status == 'SUCCESS' || status == 'COMPLETE' || status == 'COMPLETED') {
          if (mounted) {
            setState(() {
              _paid = true;
              _polling = false;
            });
            widget.onSuccess();
          }
          return false;
        } else if (status == 'FAILED' || status == 'CANCELLED' || status == 'EXPIRED') {
          if (mounted) {
            setState(() {
              _polling = false;
              _checkoutRef = null;
              _error = 'Payment ${status.toLowerCase()} — please try again';
            });
          }
          return false;
        }
      } catch (_) {}
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPadding = mq.viewInsets.bottom + mq.padding.bottom + 24;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          if (_paid) ...[
            Center(child: Column(children: [
              Container(width: 64, height: 64,
                  decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.financeGreen, size: 40)),
              const SizedBox(height: 16),
              const Text('Deposit Successful!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              const SizedBox(height: 6),
              Text('KES ${widget.amtCtrl.text} added to your wallet',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.financeGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: const Text('Done',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)))),
            ])),
          ] else if (_checkoutRef != null) ...[
            Center(child: Column(children: [
              Container(width: 64, height: 64,
                  decoration: BoxDecoration(color: AppColors.financeGreenV3.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const CircularProgressIndicator(color: AppColors.financeGreen, strokeWidth: 3)),
              const SizedBox(height: 16),
              const Text('Check your phone',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              const SizedBox(height: 6),
              const Text('Enter your M-Pesa PIN to complete the deposit.\nWaiting for confirmation...',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextButton(
                  onPressed: () => setState(() { _checkoutRef = null; _polling = false; }),
                  child: const Text('Cancel / Try again', style: TextStyle(color: Colors.red))),
            ])),
          ] else ...[
            const Text('Add Money via M-Pesa',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 20),
            _field(widget.amtCtrl, 'Amount (KES)',
                isNumber: true,
                prefix: const Text('KES ', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 8),
            Builder(builder: (_) {
              final amt = double.tryParse(widget.amtCtrl.text.replaceAll(',', '')) ?? 0;
              if (amt <= 0) return const SizedBox.shrink();
              final charge = (amt * 0.015).ceil().toDouble();
              final total = amt + charge;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Deposit', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    Text('KES ${amt.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Fee', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    Text('KES ${charge.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
                  ]),
                  const Divider(height: 12, color: Color(0xFFD1FAE5)),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('M-Pesa total',
                        style: TextStyle(fontSize: 13, color: Color(0xFF111827), fontWeight: FontWeight.bold)),
                    Text('KES ${total.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.financeGreen, fontWeight: FontWeight.bold)),
                  ]),
                ]),
              );
            }),
            const SizedBox(height: 12),
            _field(widget.phoneCtrl, 'M-Pesa Phone Number',
                isNumber: true,
                prefix: const Icon(Icons.phone_android_rounded, size: 18, color: AppColors.financeGreen)),
            const SizedBox(height: 6),
            const Text('Your registered M-Pesa number', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)))
                ]),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: _loading ? null : _sendSTK,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.financeGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Send STK Push',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)))),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint,
      {bool isNumber = false, Widget? prefix, void Function(String)? onChanged}) {
    return TextField(
      controller: ctrl,
      onChanged: onChanged,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        prefixIcon: prefix != null ? Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: prefix) : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ── Withdraw sheet (moved from home_tab.dart, unchanged logic) ────────────
class PayWithdrawSheet extends StatefulWidget {
  final String userId;
  final TextEditingController phoneCtrl;
  final TextEditingController amtCtrl;
  final VoidCallback onSuccess;
  const PayWithdrawSheet(
      {super.key,
      required this.userId,
      required this.phoneCtrl,
      required this.amtCtrl,
      required this.onSuccess});

  @override
  State<PayWithdrawSheet> createState() => _PayWithdrawSheetState();
}

class _PayWithdrawSheetState extends State<PayWithdrawSheet> {
  bool _loading = false;
  String? _error;
  bool _done = false;

  Future<void> _withdraw() async {
    final amt = double.tryParse(widget.amtCtrl.text.replaceAll(',', ''));
    if (amt == null || amt < 10) {
      setState(() => _error = 'Enter a valid amount (min KES 10)');
      return;
    }
    final phoneError = ValidationUtils.validateKenyanPhone(widget.phoneCtrl.text);
    if (phoneError != null) {
      setState(() => _error = phoneError);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      String phone = widget.phoneCtrl.text.trim();
      if (phone.startsWith('0')) phone = '254${phone.substring(1)}';
      if (phone.startsWith('+')) phone = phone.substring(1);
      final res = await http
          .post(
            Uri.parse(ApiConfig.getUrl('withdraw')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': widget.userId,
              'amount': amt.toInt(),
              'phone': phone
            }),
          )
          .timeout(const Duration(seconds: 20));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          _loading = false;
          _done = true;
        });
        widget.onSuccess();
      } else {
        setState(() {
          _loading = false;
          _error = data['message'] ?? 'Withdrawal failed';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Network error — check your connection';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPadding = mq.viewInsets.bottom + mq.padding.bottom + 24;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          if (_done) ...[
            Center(child: Column(children: [
              Container(width: 64, height: 64,
                  decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.financeGreen, size: 40)),
              const SizedBox(height: 16),
              const Text('Withdrawal Sent!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              const SizedBox(height: 6),
              const Text('M-Pesa will confirm shortly.', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.financeGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
            ])),
          ] else ...[
            Row(children: [
              Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFDC2626).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFFDC2626), size: 22)),
              const SizedBox(width: 12),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Withdraw to M-Pesa',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                Text('Funds sent directly to your phone', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ]),
            ]),
            const SizedBox(height: 20),
            _wField(widget.amtCtrl, 'Amount (KES)',
                isNumber: true,
                prefix: const Text('KES ', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 8),
            Builder(builder: (_) {
              final amt = double.tryParse(widget.amtCtrl.text.replaceAll(',', '')) ?? 0;
              if (amt <= 0) return const SizedBox.shrink();
              final charge = (amt * 0.015).ceil().toDouble();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Withdraw', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    Text('KES ${amt.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Fee', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    Text('KES ${charge.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('From your wallet', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    Text('KES ${(amt + charge).toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
                  ]),
                  const Divider(height: 12, color: Color(0xFFFCA5A5)),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('You receive',
                        style: TextStyle(fontSize: 13, color: Color(0xFF111827), fontWeight: FontWeight.bold)),
                    Text('KES ${amt.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                  ]),
                ]),
              );
            }),
            const SizedBox(height: 12),
            _wField(widget.phoneCtrl, 'M-Pesa Phone Number',
                isNumber: true,
                prefix: const Icon(Icons.phone_android_rounded, size: 18, color: Color(0xFFDC2626))),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)))
                ]),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: _loading ? null : _withdraw,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Withdraw',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)))),
          ],
        ],
      ),
    );
  }

  Widget _wField(TextEditingController ctrl, String hint,
      {bool isNumber = false, Widget? prefix, void Function(String)? onChanged}) {
    return TextField(
      controller: ctrl,
      onChanged: onChanged,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        prefixIcon: prefix != null ? Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: prefix) : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
