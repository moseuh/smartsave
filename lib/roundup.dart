import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RoundUpSettings extends StatefulWidget {
  const RoundUpSettings({super.key});

  @override
  State<RoundUpSettings> createState() => _RoundUpSettingsState();
}

class _RoundUpSettingsState extends State<RoundUpSettings> {
  bool payBillRoundUp = false;
  bool buyGoodsRoundUp = false;
  String? roundingValue = 'KSh 5'; // Default to KSh 5
  TextEditingController maxRoundUpController = TextEditingController();
  TextEditingController monthlyCapController = TextEditingController();

  final double originalAmount = 100.0;

  @override
  void initState() {
    super.initState();
    maxRoundUpController.text = '';
    monthlyCapController.text = '';
    _loadRoundUpSettings();
    debugPrint('RoundUpSettings initState called');
  }

  @override
  void dispose() {
    maxRoundUpController.dispose();
    monthlyCapController.dispose();
    super.dispose();
  }

  Future<void> _loadRoundUpSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    if (userId == null) {
      debugPrint('No user_id found in SharedPreferences');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('http://apis.gnmprimesource.co.ke/apis/roundup-settings/$userId'),
        headers: {"Content-Type": "application/json"},
      );
      debugPrint('Load API Response Status: ${response.statusCode}');
      debugPrint('Load API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          payBillRoundUp = (data['pay_bill_round_up'] is int ? data['pay_bill_round_up'] == 1 : data['pay_bill_round_up']) ?? false;
          buyGoodsRoundUp = (data['buy_goods_round_up'] is int ? data['buy_goods_round_up'] == 1 : data['buy_goods_round_up']) ?? false;
          roundingValue = data['rounding_value']?.toString() ?? 'KSh 5';
          // Ensure roundingValue matches one of the options
          if (!['KSh 5', 'KSh 10', 'KSh 100', 'KSh 1000'].contains(roundingValue)) {
            roundingValue = 'KSh 5'; // Fallback to default if invalid
          }
          maxRoundUpController.text = data['max_round_up']?.toString() ?? '';
          monthlyCapController.text = data['monthly_cap']?.toString() ?? '';
          debugPrint('Loaded data - payBillRoundUp: $payBillRoundUp, buyGoodsRoundUp: $buyGoodsRoundUp, roundingValue: $roundingValue');
        });
      } else {
        debugPrint('Failed to load round-up settings: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Error loading round-up settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading settings')),
      );
    }
  }

  Future<void> _saveRoundUpSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    if (userId == null) {
      debugPrint('No user_id found in SharedPreferences');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID not found. Please log in again.')),
      );
      return;
    }

    // Extract the numeric value from roundingValue (e.g., "KSh 5" -> "5")
    final String numericRoundingValue = roundingValue?.replaceAll('KSh ', '') ?? '5';

    final payload = {
      'user_id': userId,
      'is_enabled': payBillRoundUp || buyGoodsRoundUp,
      'pay_bill_round_up': payBillRoundUp,
      'buy_goods_round_up': buyGoodsRoundUp,
      'rounding_value': numericRoundingValue, // Send only the numeric part
      'max_round_up': maxRoundUpController.text.isNotEmpty ? double.parse(maxRoundUpController.text) : null,
      'monthly_cap': monthlyCapController.text.isNotEmpty ? double.parse(monthlyCapController.text) : null,
    };

    debugPrint('Saving round-up settings with payload: $payload');

    try {
      final response = await http.post(
        Uri.parse('http://apis.gnmprimesource.co.ke/apis/roundup-settings'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
      debugPrint('Save API Response Status: ${response.statusCode}');
      debugPrint('Save API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: ${response.statusCode} - ${response.body}')),
        );
      }
    } catch (e) {
      debugPrint('Error saving round-up settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving settings')),
      );
    }
  }

  double calculateRoundedUpAmount(double original, String roundingValueStr) {
    try {
      final int roundingFactor = int.parse(roundingValueStr.replaceAll('KSh ', ''));
      if (roundingFactor == 0) {
        debugPrint('Rounding factor is 0, returning original amount');
        return original;
      }
      final int quotient = (original / roundingFactor).ceil(); // Use ceil to round up
      return quotient * roundingFactor.toDouble();
    } catch (e) {
      debugPrint('Error calculating rounded amount: $e');
      return original; // Fallback to original amount if parsing fails
    }
  }

  double calculateAmountSaved(double original, double roundedUp) {
    return roundedUp - original;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building RoundUpSettings - roundingValue: $roundingValue, payBillRoundUp: $payBillRoundUp');
    final double roundedUp = calculateRoundedUpAmount(originalAmount, roundingValue ?? 'KSh 5'); // Fallback to default
    final double amountSaved = calculateAmountSaved(originalAmount, roundedUp);

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        title: const Text('Round-Up Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Automatically save the change from your transactions by rounding up to the nearest shilling.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transaction Types',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildSwitchTile('Pay Bill Round-Up', payBillRoundUp, (value) {
                    setState(() => payBillRoundUp = value);
                  }),
                  _buildSwitchTile('Buy Goods Round-Up', buyGoodsRoundUp, (value) {
                    setState(() => buyGoodsRoundUp = value);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rounding Rules',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildRoundingOption('KSh 5', roundingValue == 'KSh 5', () {
                          setState(() => roundingValue = 'KSh 5');
                        }),
                        const SizedBox(width: 8),
                        _buildRoundingOption('KSh 10', roundingValue == 'KSh 10', () {
                          setState(() => roundingValue = 'KSh 10');
                        }),
                        const SizedBox(width: 8),
                        _buildRoundingOption('KSh 100', roundingValue == 'KSh 100', () {
                          setState(() => roundingValue = 'KSh 100');
                        }),
                        const SizedBox(width: 8),
                        _buildRoundingOption('KSh 1000', roundingValue == 'KSh 1000', () {
                          setState(() => roundingValue = 'KSh 1000');
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Maximum round-up per transaction',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: maxRoundUpController,
                    decoration: InputDecoration(
                      hintText: 'Enter amount',
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monthly round-up cap (optional)',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: monthlyCapController,
                    decoration: InputDecoration(
                      hintText: 'Enter amount',
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preview Example',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildPreviewItem('Original amount:', 'KSh ${originalAmount.toStringAsFixed(2)}'),
                  _buildPreviewItem('Rounded up to:', 'KSh ${roundedUp.toStringAsFixed(2)}'),
                  _buildPreviewItem('Amount saved:', 'KSh ${amountSaved.toStringAsFixed(2)}', isBold: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _saveRoundUpSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5BB1B), // Changed from Colors.yellow
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFF5BB1B), // Changed from Colors.yellow
        activeTrackColor: const Color(0xFFF5BB1B).withOpacity(0.7), // Adjusted for contrast
        inactiveThumbColor: Colors.grey,
        inactiveTrackColor: Colors.grey[700],
      ),
    );
  }

  Widget _buildRoundingOption(String value, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5BB1B) : Colors.grey[900], // Changed from Colors.yellow
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey, width: 1),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              color: isBold ? const Color(0xFFF5BB1B) : Colors.white, // Changed from Colors.yellow
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}