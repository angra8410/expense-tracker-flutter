import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../services/storage_service.dart';

class TransactionProvider with ChangeNotifier {
  final StorageService _storage = StorageService();
  List<Transaction> _transactions = [];
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';

  TransactionProvider() {
    _loadTransactions();
  }

  List<Transaction> get transactions {
    List<Transaction> filteredTransactions = [..._transactions];

    // Apply search filter if query exists
    if (_searchQuery.isNotEmpty) {
      filteredTransactions = filteredTransactions.where((transaction) {
        return transaction.description.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Sort by date (most recent first)
    filteredTransactions.sort((a, b) => b.date.compareTo(a.date));
    return filteredTransactions;
  }

  DateTime get selectedDate => _selectedDate;
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> _loadTransactions() async {
    _transactions = await _storage.loadTransactions();
    notifyListeners();
  }

  Future<void> _saveTransactions() async {
    await _storage.saveTransactions(_transactions);
  }

  void addTransaction(Transaction transaction) {
    _transactions.add(transaction);
    _saveTransactions();
    notifyListeners();
  }

  void removeTransaction(String id) {
    _transactions.removeWhere((transaction) => transaction.id == id);
    _saveTransactions();
    notifyListeners();
  }

  void updateTransaction(Transaction updatedTransaction) {
    final index = _transactions.indexWhere(
      (transaction) => transaction.id == updatedTransaction.id,
    );
    if (index >= 0) {
      _transactions[index] = updatedTransaction;
      _saveTransactions();
      notifyListeners();
    }
  }

  double getTotalBalance() {
    return _transactions.fold(0.0, (sum, transaction) {
      if (transaction.type == TransactionType.income) {
        return sum + transaction.amount;
      } else {
        return sum - transaction.amount;
      }
    });
  }

  double getTotalIncome() {
    return _transactions
        .where((transaction) => transaction.type == TransactionType.income)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double getTotalExpenses() {
    return _transactions
        .where((transaction) => transaction.type == TransactionType.expense)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  List<Transaction> getTransactionsByAccount(String accountId) {
    return _transactions
        .where((transaction) => transaction.accountId == accountId)
        .toList();
  }

  List<Transaction> getTransactionsByCategory(String categoryId) {
    return _transactions
        .where((transaction) => transaction.categoryId == categoryId)
        .toList();
  }

  List<Transaction> getTransactionsByDateRange(DateTime start, DateTime end) {
    return _transactions
        .where((transaction) =>
            transaction.date.isAfter(start.subtract(const Duration(days: 1))) &&
            transaction.date.isBefore(end.add(const Duration(days: 1))))
        .toList();
  }

  List<Transaction> getTransactionsByMonth(DateTime date) {
    return _transactions
        .where((transaction) =>
            transaction.date.year == date.year &&
            transaction.date.month == date.month)
        .toList();
  }

  double getBalanceByDateRange(DateTime start, DateTime end) {
    final transactionsInRange = getTransactionsByDateRange(start, end);
    return transactionsInRange.fold(0.0, (sum, transaction) {
      if (transaction.type == TransactionType.income) {
        return sum + transaction.amount;
      } else {
        return sum - transaction.amount;
      }
    });
  }

  double getIncomeByDateRange(DateTime start, DateTime end) {
    final transactionsInRange = getTransactionsByDateRange(start, end);
    return transactionsInRange
        .where((transaction) => transaction.type == TransactionType.income)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double getExpensesByDateRange(DateTime start, DateTime end) {
    final transactionsInRange = getTransactionsByDateRange(start, end);
    return transactionsInRange
        .where((transaction) => transaction.type == TransactionType.expense)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double getMonthlyIncome(DateTime date) {
    final monthlyTransactions = getTransactionsByMonth(date);
    return monthlyTransactions
        .where((transaction) => transaction.type == TransactionType.income)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double getMonthlyExpenses(DateTime date) {
    final monthlyTransactions = getTransactionsByMonth(date);
    return monthlyTransactions
        .where((transaction) => transaction.type == TransactionType.expense)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  // Helper method to clear all transactions (useful for testing)
  Future<void> clearAllTransactions() async {
    _transactions.clear();
    await _saveTransactions();
    notifyListeners();
  }
}