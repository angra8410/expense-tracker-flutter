class Account {
  final String id;
  final String name;
  final double initialBalance;
  final String? description;

  Account({
    required this.id,
    required this.name,
    required this.initialBalance,
    this.description,
  });
}