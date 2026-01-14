/// Transaction model
class Transaction {
  final String id;
  final String userId;
  final double amount;
  final String type; // 'debit', 'credit', 'savings', 'payment'
  final String? description;
  final String? category;
  final String? reference;
  final String status; // 'pending', 'completed', 'failed'
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    this.description,
    this.category,
    this.reference,
    required this.status,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      type: json['type']?.toString() ?? 'debit',
      description: json['description']?.toString(),
      category: json['category']?.toString(),
      reference: json['reference']?.toString(),
      status: json['status']?.toString() ?? 'pending',
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
      'type': type,
      'description': description,
      'category': category,
      'reference': reference,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
