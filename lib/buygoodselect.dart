import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'graph.dart'; // SavingsDashboard
import 'addtofavourites.dart';
import 'homepage.dart';
import 'favourites.dart';

class ProcessingDialog extends StatelessWidget {
  final VoidCallback? onCancel;
  const ProcessingDialog({super.key, this.onCancel});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Color(0xFF9CA3AF),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFFF5BB1B)),
          const SizedBox(height: 16),
          const Text(
            'Waiting for PIN entry...\nPlease complete the M-PESA prompt.',
            style: TextStyle(color: Colors.black, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (onCancel != null)
            TextButton(
              onPressed: onCancel,
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFFF5BB1B), fontSize: 16),
              ),
            ),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

class BuyGoodsSelect extends StatefulWidget {
  final String userId;
  const BuyGoodsSelect({super.key, required this.userId});

  @override
  State<BuyGoodsSelect> createState() => _BuyGoodsSelectState();
}

class _BuyGoodsSelectState extends State<BuyGoodsSelect> {
  bool isBuyGoods = true;
  bool showAddToFavourites = true;
  final TextEditingController tillNumberController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  Map<String, dynamic>? lastPayment;
  Map<String, dynamic>? roundupSettings;
  Map<String, dynamic>? userDetails;
  double roundUpSavings = 0.0;
  double paymentAmount = 0.0;
  double totalAmount = 0.0;
  bool isLoadingSettings = true;
  bool isLoadingPayment = false;
  bool isLoadingUserDetails = true;

  @override
  void initState() {
    super.initState();
    tillNumberController.text = '';
    accountNumberController.text = '';
    amountController.text = '';
    fetchUserDetails();
    fetchLastPayment();
    fetchRoundupSettings();
    amountController.addListener(() {
      if (!isLoadingSettings) {
        calculateRoundUp();
      }
    });
  }

  @override
  void dispose() {
    tillNumberController.dispose();
    accountNumberController.dispose();
    amountController.removeListener(() {
      if (!isLoadingSettings) {
        calculateRoundUp();
      }
    });
    amountController.dispose();
    super.dispose();
  }

  Future<void> fetchUserDetails() async {
    setState(() {
      isLoadingUserDetails = true;
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
            isLoadingUserDetails = false;
            debugPrint('User details fetched: $userDetails');
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load user details');
        }
      } else {
        throw Exception('Failed to load user details: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching user details: $e');
      _showSnackBar('Error loading user details: $e');
      setState(() {
        isLoadingUserDetails = false;
      });
    }
  }

  Future<void> fetchRoundupSettings() async {
    setState(() {
      isLoadingSettings = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/roundup-settings/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        data['is_enabled'] = (data['is_enabled'] == 1 || data['is_enabled'] == true);
        data['pay_bill_round_up'] = (data['pay_bill_round_up'] == 1 || data['pay_bill_round_up'] == true);
        data['buy_goods_round_up'] = (data['buy_goods_round_up'] == 1 || data['buy_goods_round_up'] == true);
        data['retail_purchases_round_up'] = (data['retail_purchases_round_up'] == 1 || data['retail_purchases_round_up'] == true);
        setState(() {
          roundupSettings = data;
          isLoadingSettings = false;
          debugPrint('Round-up settings fetched: $roundupSettings');
        });
        calculateRoundUp();
      } else {
        debugPrint('Failed to fetch round-up settings: ${response.statusCode}');
        _showSnackBar('Failed to fetch round-up settings: ${response.statusCode}');
        setState(() {
          isLoadingSettings = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching round-up settings: $e');
      _showSnackBar('Error fetching round-up settings');
      setState(() {
        isLoadingSettings = false;
      });
    }
  }

  Future<void> fetchLastPayment() async {
    setState(() {
      isLoadingPayment = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/last-payment/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint('Last payment response: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            lastPayment = data['data'];
            debugPrint('Last payment fetched: $lastPayment');
          });
        } else {
          setState(() {
            lastPayment = null;
            debugPrint('No payments found: ${data['message']}');
          });
        }
      } else if (response.statusCode == 404) {
        setState(() {
          lastPayment = null;
          debugPrint('No payments found: 404');
        });
      } else {
        debugPrint('Failed to fetch last payment: ${response.statusCode}');
        _showSnackBar('Failed to fetch last payment: ${response.statusCode}');
        setState(() {
          lastPayment = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching last payment: $e');
      _showSnackBar('Error fetching last payment');
      setState(() {
        lastPayment = null;
      });
    } finally {
      setState(() {
        isLoadingPayment = false;
      });
    }
  }

  void calculateRoundUp() {
    if (roundupSettings == null) {
      debugPrint('Round-up settings not yet fetched, skipping calculation');
      return;
    }

    double enteredAmount = double.tryParse(amountController.text) ?? 0.0;
    double roundUpValue = 0.0;

    bool isRoundUpEnabled = roundupSettings!['is_enabled'] ?? false;
    bool applyRoundUp = isBuyGoods
        ? (roundupSettings!['buy_goods_round_up'] ?? false)
        : (roundupSettings!['pay_bill_round_up'] ?? false);

    debugPrint('Calculating round-up: isRoundUpEnabled=$isRoundUpEnabled, applyRoundUp=$applyRoundUp');

    if (isRoundUpEnabled && applyRoundUp && enteredAmount > 0) {
      String roundingValueStr = roundupSettings!['rounding_value']?.toString() ?? '1';
      double roundingValue = double.tryParse(roundingValueStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 1.0;

      if (roundingValue == 0) {
        roundingValue = 1.0;
        debugPrint('Rounding value is 0, defaulting to 1.0');
      }

      double maxRoundUp = double.tryParse(roundupSettings!['max_round_up']?.toString() ?? '400.00') ?? 400.00;

      debugPrint('Payment Amount: $enteredAmount, Rounding Value: $roundingValue, Max Round-Up: $maxRoundUp');

      double roundedAmount;
      if (enteredAmount % roundingValue == 0) {
        roundedAmount = enteredAmount + roundingValue;
      } else {
        roundedAmount = ((enteredAmount / roundingValue).ceil()) * roundingValue;
      }
      roundUpValue = roundedAmount - enteredAmount;

      if (roundUpValue > maxRoundUp) {
        roundUpValue = maxRoundUp;
        roundedAmount = enteredAmount + roundUpValue;
        debugPrint('Round-up value exceeds max_round_up, capping at $maxRoundUp');
      }

      debugPrint('Rounded Amount: $roundedAmount, Round-up Value: $roundUpValue');
    } else {
      debugPrint('Round-up not applied: isRoundUpEnabled=$isRoundUpEnabled, applyRoundUp=$applyRoundUp, enteredAmount=$enteredAmount');
    }

    setState(() {
      paymentAmount = enteredAmount;
      roundUpSavings = roundUpValue;
      totalAmount = paymentAmount + roundUpSavings;
      debugPrint('Updated UI: paymentAmount=$paymentAmount, roundUpSavings=$roundUpSavings, totalAmount=$totalAmount');
    });
  }

  Future<Map<String, dynamic>?> fetchTransactionStatus(String transactionId) async {
    try {
      debugPrint('Fetching transaction status for ID: $transactionId');
      final response = await http.get(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/transaction-status/$transactionId'),
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint('Transaction status response: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          debugPrint('Transaction status fetched: ${data['data']}');
          return data['data'];
        } else {
          debugPrint('Transaction not found: ${data['message']}');
          return null;
        }
      } else {
        debugPrint('Failed to fetch transaction status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching transaction status: $e');
      return null;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Color(0xFF9CA3AF),
        content: Text(
          message,
          style: TextStyle(color: Colors.black),
        ),
      ),
    );
  }

  Future<void> savePaymentData() async {
    if (tillNumberController.text.isEmpty || amountController.text.isEmpty) {
      _showSnackBar('Please fill in all required fields');
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(tillNumberController.text)) {
      _showSnackBar('Till number must be 6 digits');
      return;
    }

    double enteredAmount = double.tryParse(amountController.text) ?? 0.0;
    if (enteredAmount <= 0) {
      _showSnackBar('Please enter a valid amount');
      return;
    }

    if (!isBuyGoods && accountNumberController.text.isEmpty) {
      _showSnackBar('Please enter an account number for Pay Bill');
      return;
    }

    if (userDetails == null || userDetails?['phone_number'] == null) {
      _showSnackBar('User phone number not available');
      return;
    }

    final url = Uri.parse('https://apis.gnmprimesource.co.ke/apis/process-paybill-payment');
    final timestamp = DateTime.now();
    final payload = {
      'user_id': int.parse(widget.userId),
      'phone_number': userDetails!['phone_number'].startsWith('0')
          ? '254${userDetails!['phone_number'].substring(1)}'
          : userDetails!['phone_number'],
      'amount': totalAmount,
      'savings_amount': roundUpSavings,
      'merchant_paybill': tillNumberController.text,
      'merchant_account': isBuyGoods ? '' : accountNumberController.text,
    };

    debugPrint('Saving payment data with payload: $payload');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      debugPrint('Raw response body: ${response.body}');
      debugPrint('Response status code: ${response.statusCode}');

      Map<String, dynamic>? responseData;
      try {
        if (response.body.isNotEmpty) {
          responseData = jsonDecode(response.body) as Map<String, dynamic>?;
        }
      } catch (e) {
        debugPrint('JSON parsing error: $e');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Color(0xFF9CA3AF),
            content: TransactionResult(
              status: 'error',
              amount: totalAmount.toStringAsFixed(2),
              transactionId: 'TRX${timestamp.millisecondsSinceEpoch}',
              mpesaReceipt: 'N/A',
              merchantReference: 'N/A',
              errorMessage: 'Invalid server response: $e',
              dateTime: timestamp.toLocal().toString().split('.')[0],
              tillNumber: tillNumberController.text,
              accountNumber: isBuyGoods ? '' : accountNumberController.text,
              businessName: 'Global Tech Solutions',
              isBuyGoods: isBuyGoods,
              onExportPdf: null,
            ),
            contentPadding: EdgeInsets.zero,
            insetPadding: const EdgeInsets.all(10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      if (responseData == null) {
        debugPrint('Response data is null or not a map');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Color(0xFF9CA3AF),
            content: TransactionResult(
              status: 'error',
              amount: totalAmount.toStringAsFixed(2),
              transactionId: 'TRX${timestamp.millisecondsSinceEpoch}',
              mpesaReceipt: 'N/A',
              merchantReference: 'N/A',
              errorMessage: 'Invalid server response: Empty or malformed data',
              dateTime: timestamp.toLocal().toString().split('.')[0],
              tillNumber: tillNumberController.text,
              accountNumber: isBuyGoods ? '' : accountNumberController.text,
              businessName: 'Global Tech Solutions',
              isBuyGoods: isBuyGoods,
              onExportPdf: null,
            ),
            contentPadding: EdgeInsets.zero,
            insetPadding: const EdgeInsets.all(10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      final initialStatus = responseData['status']?.toString().toLowerCase() ?? 'error';
      final transactionId = responseData['transactionId']?.toString() ?? 'TRX${timestamp.millisecondsSinceEpoch}';

      if (initialStatus != 'success') {
        final errorMessage = responseData['error_message']?.toString() ??
            responseData['message']?.toString() ??
            'Failed to initiate payment';
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Color(0xFF9CA3AF),
            content: TransactionResult(
              status: 'error',
              amount: totalAmount.toStringAsFixed(2),
              transactionId: transactionId,
              mpesaReceipt: 'N/A',
              merchantReference: 'N/A',
              errorMessage: errorMessage,
              dateTime: timestamp.toLocal().toString().split('.')[0],
              tillNumber: tillNumberController.text,
              accountNumber: isBuyGoods ? '' : accountNumberController.text,
              businessName: 'Global Tech Solutions',
              isBuyGoods: isBuyGoods,
              onExportPdf: null,
            ),
            contentPadding: EdgeInsets.zero,
            insetPadding: const EdgeInsets.all(10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      bool isCancelled = false;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ProcessingDialog(
          onCancel: () {
            isCancelled = true;
            Navigator.of(context).pop();
          },
        ),
      );

      Map<String, dynamic>? transaction;
      String transactionStatus = 'error';
      String? errorMessage;
      String mpesaReceipt = 'N/A';
      String merchantReference = 'N/A';
      String amount = totalAmount.toStringAsFixed(2);
      String dateTime = timestamp.toLocal().toString().split('.')[0];
      String tillNumber = tillNumberController.text;
      String accountNumber = isBuyGoods ? '' : accountNumberController.text;

      const maxAttempts = 2;
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        if (isCancelled) {
          transactionStatus = 'error';
          errorMessage = 'Transaction cancelled by user';
          debugPrint('Transaction cancelled by user at attempt $attempt');
          break;
        }

        transaction = await fetchTransactionStatus(transactionId);
        if (transaction != null) {
          String status = transaction['transaction_status']?.toString().toLowerCase() ?? 'pending';
          mpesaReceipt = transaction['mpesa_receipt']?.toString() ?? 'N/A';
          merchantReference = transaction['merchant_reference']?.toString() ?? 'N/A';

          debugPrint('Polling attempt $attempt: status=$status, mpesa_receipt=$mpesaReceipt, merchant_reference=$merchantReference');

          if (status == 'completed' || (mpesaReceipt != 'N/A' && merchantReference != 'N/A')) {
            transactionStatus = 'success';
            amount = transaction['total_amount']?.toStringAsFixed(2) ?? amount;
            dateTime = transaction['created_at']?.toString() ?? dateTime;
            tillNumber = transaction['merchant_paybill']?.toString() ?? tillNumber;
            accountNumber = transaction['merchant_account']?.toString() ?? accountNumber;
            debugPrint('Transaction successful at attempt $attempt');
            break;
          } else if (status == 'failed') {
            transactionStatus = 'error';
            errorMessage = transaction['error_message']?.toString() ?? 'Payment failed';
            debugPrint('Transaction failed at attempt $attempt: $errorMessage');
            break;
          }
        } else {
          debugPrint('Polling attempt $attempt: No transaction data');
        }
        await Future.delayed(const Duration(seconds: 10));
      }

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (transactionStatus != 'success' && errorMessage == null) {
        errorMessage = isCancelled
            ? 'Transaction cancelled by user'
            : transaction?['error_message']?.toString() ?? 'Payment timed out: Please try again';
        debugPrint('Transaction result: $errorMessage');
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Color(0xFF9CA3AF),
          content: TransactionResult(
            status: transactionStatus,
            amount: amount,
            transactionId: transactionId,
            mpesaReceipt: mpesaReceipt,
            merchantReference: merchantReference,
            errorMessage: errorMessage,
            dateTime: dateTime,
            tillNumber: tillNumber,
            accountNumber: accountNumber,
            businessName: 'Global Tech Solutions',
            isBuyGoods: isBuyGoods,
            onExportPdf: transactionStatus == 'success'
                ? () => generatePdf(
                      amount: amount,
                      transactionId: transactionId,
                      mpesaReceipt: mpesaReceipt,
                      merchantReference: merchantReference,
                      dateTime: dateTime,
                      tillNumber: tillNumber,
                      accountNumber: accountNumber,
                      businessName: 'Global Tech Solutions',
                    )
                : null,
          ),
          contentPadding: EdgeInsets.zero,
          insetPadding: const EdgeInsets.all(10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      if (transactionStatus == 'success') {
        await fetchLastPayment();
      }
    } catch (e) {
      debugPrint('Error saving payment data: $e');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Color(0xFF9CA3AF),
          content: TransactionResult(
            status: 'error',
            amount: totalAmount.toStringAsFixed(2),
            transactionId: 'TRX${timestamp.millisecondsSinceEpoch}',
            mpesaReceipt: 'N/A',
            merchantReference: 'N/A',
            errorMessage: 'Network error: $e',
            dateTime: timestamp.toLocal().toString().split('.')[0],
            tillNumber: tillNumberController.text,
            accountNumber: isBuyGoods ? '' : accountNumberController.text,
            businessName: 'Global Tech Solutions',
            isBuyGoods: isBuyGoods,
            onExportPdf: null,
          ),
          contentPadding: EdgeInsets.zero,
          insetPadding: const EdgeInsets.all(10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> generatePdf({
    required String amount,
    required String transactionId,
    required String mpesaReceipt,
    required String merchantReference,
    required String dateTime,
    required String tillNumber,
    required String accountNumber,
    required String businessName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Payment Receipt', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Business Name: $businessName', style: pw.TextStyle(fontSize: 16)),
            pw.Text('Date & Time: $dateTime', style: pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 10),
            pw.Text('Amount: KSh $amount', style: pw.TextStyle(fontSize: 16)),
            pw.Text('Transaction ID: $transactionId', style: pw.TextStyle(fontSize: 16)),
            pw.Text('M-PESA Receipt: $mpesaReceipt', style: pw.TextStyle(fontSize: 16)),
            pw.Text('Merchant Reference: $merchantReference', style: pw.TextStyle(fontSize: 16)),
            pw.Text(isBuyGoods ? 'Till Number: $tillNumber' : 'Pay Bill Number: $tillNumber',
                style: pw.TextStyle(fontSize: 16)),
            if (accountNumber.isNotEmpty)
              pw.Text('Account Number: $accountNumber', style: pw.TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/receipt_${transactionId}.pdf');
      await file.writeAsBytes(await pdf.save());

      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        _showSnackBar('Failed to open PDF: ${result.message}');
      }
    } catch (e) {
      _showSnackBar('Error generating PDF: $e');
    }
  }

  // Modified saveToFavourites to navigate to Favourites screen
  Future<void> saveToFavourites() async {
    if (tillNumberController.text.isEmpty) {
      _showSnackBar('Please enter a till or pay bill number');
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(tillNumberController.text)) {
      _showSnackBar('Till number must be 6 digits');
      return;
    }

    final payload = {
      'user_id': widget.userId,
      'name': 'Favourite ${isBuyGoods ? 'Till' : 'Pay Bill'} - ${tillNumberController.text}',
      'till_number': tillNumberController.text,
      'account_number': isBuyGoods ? '' : accountNumberController.text,
      'type': isBuyGoods ? 'buy_goods' : 'pay_bill',
    };

    debugPrint('Saving to favourites with payload: $payload');

    try {
      final response = await http.post(
        Uri.parse('https://apis.gnmprimesource.co.ke/apis/favourites'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      debugPrint('Save to favourites response: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          setState(() {
            showAddToFavourites = false;
          });
          _showSnackBar('Added to favourites successfully');
          // Navigate to Favourites screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Favourites(userId: widget.userId),
            ),
          );
        } else {
          _showSnackBar('Failed to save to favourites: ${responseData['message'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = jsonDecode(response.body);
        debugPrint('Failed to save favourite: ${response.statusCode}, Response: ${response.body}');
        _showSnackBar('Failed to save to favourites: ${errorData['message'] ?? response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error saving favourite: $e');
      _showSnackBar('Error saving to favourites: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        title: const Text(
          'Payment',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SavingsDashboard(userId: widget.userId),
              ),
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'assets/logo.png',
              width: 30,
              height: 30,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      body: isLoadingSettings || isLoadingPayment || isLoadingUserDetails
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF5BB1B)))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                isBuyGoods = true;
                                if (!isLoadingSettings) {
                                  calculateRoundUp();
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isBuyGoods ? const Color(0xFFF5BB1B) : Color(0xFF9CA3AF),
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                              ),
                              child: Center(
                                child: Text(
                                  'Buy Goods',
                                  style: TextStyle(
                                    color: isBuyGoods ? Colors.black : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                isBuyGoods = false;
                                if (!isLoadingSettings) {
                                  calculateRoundUp();
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !isBuyGoods ? const Color(0xFFF5BB1B) : Color(0xFF9CA3AF),
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                              ),
                              child: Center(
                                child: Text(
                                  'Pay Bill',
                                  style: TextStyle(
                                    color: !isBuyGoods ? Colors.black : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showAddToFavourites) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: Color(0xFF9CA3AF),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.15),
                            spreadRadius: 0.5,
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Favourite',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: saveToFavourites,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.add,
                                  color: Colors.black,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isBuyGoods ? 'Save current till number' : 'Save current pay bill number',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBuyGoods ? 'Till Number' : 'Pay Bill Number',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: tillNumberController,
                          decoration: InputDecoration(
                            hintText: isBuyGoods ? 'Enter till number' : 'Enter pay bill number',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Color(0xFF9CA3AF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: const TextStyle(color: Colors.black),
                          keyboardType: TextInputType.number,
                        ),
                        if (!isBuyGoods) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Account Number',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: accountNumberController,
                            decoration: InputDecoration(
                              hintText: 'Enter account number',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Color(0xFF9CA3AF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(color: Colors.black),
                            keyboardType: TextInputType.text,
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          'Amount',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: amountController,
                          decoration: InputDecoration(
                            hintText: 'Enter amount',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Color(0xFF9CA3AF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: const TextStyle(color: Colors.black),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Color(0xFF9CA3AF),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          spreadRadius: 0.5,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Summary',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryItem('Payment Amount', 'KSh ${paymentAmount.toStringAsFixed(2)}'),
                        _buildSummaryItem('Round-up Savings', 'KSh ${roundUpSavings.toStringAsFixed(2)}'),
                        _buildSummaryItem('Total Amount', 'KSh ${totalAmount.toStringAsFixed(2)}', isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: savePaymentData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF5BB1B),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Confirm Payment',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionResult extends StatelessWidget {
  final String status;
  final String amount;
  final String transactionId;
  final String mpesaReceipt;
  final String merchantReference;
  final String? errorMessage;
  final String dateTime;
  final String tillNumber;
  final String accountNumber;
  final String businessName;
  final bool isBuyGoods;
  final VoidCallback? onExportPdf;

  const TransactionResult({
    super.key,
    required this.status,
    required this.amount,
    required this.transactionId,
    required this.mpesaReceipt,
    required this.merchantReference,
    this.errorMessage,
    required this.dateTime,
    required this.tillNumber,
    required this.accountNumber,
    required this.businessName,
    required this.isBuyGoods,
    this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = status.toLowerCase() == 'success';

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Color(0xFF9CA3AF),
        borderRadius: BorderRadius.circular(10),
      ),
      width: MediaQuery.of(context).size.width * 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? Colors.green : Colors.red,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isSuccess ? 'Payment Successful' : 'Payment Failed',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isSuccess) ...[
            _buildDetailRow('Amount', 'KSh $amount'),
            _buildDetailRow('M-PESA Receipt', mpesaReceipt),
            _buildDetailRow('Merchant Reference', merchantReference),
            _buildDetailRow('Transaction ID', transactionId),
            _buildDetailRow('Date & Time', dateTime),
            _buildDetailRow(isBuyGoods ? 'Till Number' : 'Pay Bill Number', tillNumber),
            if (accountNumber.isNotEmpty) _buildDetailRow('Account Number', accountNumber),
            _buildDetailRow('Business Name', businessName),
          ] else ...[
            _buildDetailRow('Reason', errorMessage ?? 'Unknown error'),
            _buildDetailRow('Amount Attempted', 'KSh $amount'),
            _buildDetailRow('Date & Time', dateTime),
            _buildDetailRow(isBuyGoods ? 'Till Number' : 'Pay Bill Number', tillNumber),
            if (accountNumber.isNotEmpty) _buildDetailRow('Account Number', accountNumber),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSuccess && onExportPdf != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: ElevatedButton(
                    onPressed: onExportPdf,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Export to PDF',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (isSuccess) {
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuccess ? const Color(0xFFF5BB1B) : Colors.grey[700],
                  foregroundColor: isSuccess ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isSuccess ? 'Done' : 'Try Again',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}