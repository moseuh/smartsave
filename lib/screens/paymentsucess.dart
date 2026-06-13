import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'buygoodselect.dart'; // Adjust import path
import 'homepage.dart'; // Adjust import path
import 'addtofavourites.dart'; // Adjust import path
import 'favourites.dart'; // Adjust import path

class PaymentSuccess extends StatelessWidget {
  final String userId;
  final String amount;
  final String transactionId;
  final String dateTime;
  final String tillNumber;
  final String reference;
  final String businessName;
  final bool isBuyGoods;

  const PaymentSuccess({
    super.key,
    required this.userId,
    required this.amount,
    required this.transactionId,
    required this.dateTime,
    required this.tillNumber,
    required this.reference,
    required this.businessName,
    required this.isBuyGoods,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const CircleAvatar(
                backgroundColor: Colors.green,
                radius: 30,
                child: Icon(Icons.check, color: AppTheme.textPrimary, size: 30),
              ),
              const SizedBox(height: 20),
              const Text(
                'Payment Successful!',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your transaction has been completed',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount Paid',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    Text(
                      'KSH $amount',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Transaction ID',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    Text(
                      transactionId,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Date & Time',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    Text(
                      dateTime,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Details',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDetailItem(isBuyGoods ? 'Till Number' : 'Pay Bill Number', tillNumber),
                    _buildDetailItem('Reference', reference),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payee Information',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDetailItem('Business Name', businessName),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    // Add logic for downloading receipt
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Download Receipt',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.download, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  // Add logic for viewing transaction history
                },
                child: const Text(
                  'View Transaction History',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text(
                  'Back to Home',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
