import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants/app_theme.dart';
import '../config/api_config.dart';
import 'validation_utils.dart';

/// Ensures the user has an M-Pesa phone number on file before a payment
/// proceeds. If [currentPhone] is already set, returns it immediately.
/// Otherwise shows a dialog to collect and save one, returning the number
/// entered (already saved to the profile) or null if the user cancelled.
Future<String?> ensurePhoneNumber(BuildContext context, String userId, String? currentPhone) async {
  if (currentPhone != null && currentPhone.trim().isNotEmpty) return currentPhone.trim();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PhonePromptDialog(userId: userId),
  );
}

class _PhonePromptDialog extends StatefulWidget {
  final String userId;
  const _PhonePromptDialog({required this.userId});

  @override
  State<_PhonePromptDialog> createState() => _PhonePromptDialogState();
}

class _PhonePromptDialogState extends State<_PhonePromptDialog> {
  final _ctrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final err = ValidationUtils.validateKenyanPhone(_ctrl.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() { _saving = true; _error = null; });
    final phone = _ctrl.text.trim();
    try {
      final r = await http.put(
        Uri.parse(ApiConfig.getUrl('update-profile/${widget.userId}')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phone}),
      );
      if (r.statusCode == 200) {
        if (mounted) Navigator.pop(context, phone);
      } else {
        final d = jsonDecode(r.body);
        setState(() { _saving = false; _error = d['message'] ?? 'Failed to save number'; });
      }
    } catch (_) {
      setState(() { _saving = false; _error = 'Network error — check your connection'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.phone_android_rounded, color: AppColors.financeGreen, size: 22),
          ),
          const SizedBox(height: 14),
          const Text('Add your M-Pesa number', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          const Text("We don't have a phone number on file for your account yet — add one to continue.",
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '0712345678',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.phone_android_rounded, size: 18, color: AppColors.financeGreen),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
          ],
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.financeGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
