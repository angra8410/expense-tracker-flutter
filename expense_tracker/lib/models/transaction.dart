enum TransactionType { income, expense }

class Transaction {
  final String id;
  final double amount;
  final String description;
  final DateTime date;
  final TransactionType type;
  final String categoryId;
  final String accountId;

  Transaction({
    required this.id,
    required this.amount,
    required this.description,
    required this.date,
    required this.type,
    required this.categoryId,
    required this.accountId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'type': type.toString(),
      'categoryId': categoryId,
      'accountId': accountId,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      date: DateTime.parse(json['date'] as String),
      type: TransactionType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      categoryId: json['categoryId'] as String,
      accountId: json['accountId'] as String,
    );
  }
}