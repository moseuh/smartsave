/// M-Pesa usage data model
class MpesaUsage {
  final String userId;
  final double totalSpent;
  final double weeklyAvg;
  final double monthlyAvg;
  final double yearlyAvg;
  final String usageBand;
  final int transactionCount;
  final DateTime lastUpdated;

  MpesaUsage({
    required this.userId,
    required this.totalSpent,
    required this.weeklyAvg,
    required this.monthlyAvg,
    required this.yearlyAvg,
    required this.usageBand,
    required this.transactionCount,
    required this.lastUpdated,
  });

  factory MpesaUsage.fromJson(Map<String, dynamic> json) {
    return MpesaUsage(
      userId: json['user_id']?.toString() ?? '',
      totalSpent: double.tryParse(json['total_spent']?.toString() ?? '0') ?? 0.0,
      weeklyAvg: double.tryParse(json['weekly_avg']?.toString() ?? '0') ?? 0.0,
      monthlyAvg: double.tryParse(json['monthly_avg']?.toString() ?? '0') ?? 0.0,
      yearlyAvg: double.tryParse(json['yearly_avg']?.toString() ?? '0') ?? 0.0,
      usageBand: json['usage_band']?.toString() ?? '',
      transactionCount: int.tryParse(json['transaction_count']?.toString() ?? '0') ?? 0,
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'total_spent': totalSpent,
      'weekly_avg': weeklyAvg,
      'monthly_avg': monthlyAvg,
      'yearly_avg': yearlyAvg,
      'usage_band': usageBand,
      'transaction_count': transactionCount,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}
