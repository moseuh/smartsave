/// Loan model
class Loan {
  final String id;
  final String userId;
  final double amount;
  final double interestRate;
  final int durationMonths;
  final String status; // 'pending', 'approved', 'rejected', 'active', 'closed'
  final String? purpose;
  final double? outstandingBalance;
  final DateTime? approvedAt;
  final DateTime? dueDate;
  final DateTime createdAt;

  Loan({
    required this.id,
    required this.userId,
    required this.amount,
    required this.interestRate,
    required this.durationMonths,
    required this.status,
    this.purpose,
    this.outstandingBalance,
    this.approvedAt,
    this.dueDate,
    required this.createdAt,
  });

  double get totalAmount => amount + (amount * interestRate / 100);
  double get monthlyPayment => totalAmount / durationMonths;
  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      interestRate: double.tryParse(json['interest_rate']?.toString() ?? '0') ?? 0.0,
      durationMonths: int.tryParse(json['duration_months']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'pending',
      purpose: json['purpose']?.toString(),
      outstandingBalance: json['outstanding_balance'] != null
          ? double.tryParse(json['outstanding_balance'].toString())
          : null,
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'].toString())
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'interest_rate': interestRate,
      'duration_months': durationMonths,
      'status': status,
      'purpose': purpose,
      'outstanding_balance': outstandingBalance,
      'approved_at': approvedAt?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
