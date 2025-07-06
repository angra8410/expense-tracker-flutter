import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/models/transaction.dart';
import 'package:expense_tracker/providers/transaction_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TransactionProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    provider = TransactionProvider();
    // Wait for provider to initialize
    await Future.delayed(const Duration(milliseconds: 100));
    await provider.clearAllTransactions();
  });

  group('Basic Operations', () {
    test('Initial state', () async {
      expect(provider.transactions, isEmpty);
      expect(provider.getTotalBalance(), 0.0);
      expect(provider.getTotalIncome(), 0.0);
      expect(provider.getTotalExpenses(), 0.0);
    });

    test('Add transaction', () async {
      await provider.clearAllTransactions();

      final transaction = Transaction(
        id: '1',
        amount: 100.0,
        description: 'Test Income',
        date: DateTime(2025, 7, 1),
        type: TransactionType.income,
        categoryId: 'default',
        accountId: 'default',
      );

      provider.addTransaction(transaction);
      await Future.delayed(const Duration(milliseconds: 100)); // Wait for save

      expect(provider.transactions.length, 1);
      expect(provider.getTotalIncome(), 100.0);
      expect(provider.getTotalExpenses(), 0.0);
      expect(provider.getTotalBalance(), 100.0);
    });

    test('Update transaction', () async {
      final original = Transaction(
        id: '1',
        amount: 100.0,
        description: 'Original',
        date: DateTime(2025, 7, 1),
        type: TransactionType.expense,
        categoryId: 'default',
        accountId: 'default',
      );

      provider.addTransaction(original);
      await Future.delayed(const Duration(milliseconds: 100));

      final updated = Transaction(
        id: '1',
        amount: 150.0,
        description: 'Updated',
        date: DateTime(2025, 7, 1),
        type: TransactionType.expense,
        categoryId: 'default',
        accountId: 'default',
      );

      provider.updateTransaction(updated);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(provider.transactions.first.amount, 150.0);
      expect(provider.transactions.first.description, 'Updated');
      expect(provider.getTotalExpenses(), 150.0);
    });

    test('Remove transaction', () async {
      final transaction = Transaction(
        id: '1',
        amount: 100.0,
        description: 'To Remove',
        date: DateTime(2025, 7, 1),
        type: TransactionType.expense,
        categoryId: 'default',
        accountId: 'default',
      );

      provider.addTransaction(transaction);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(provider.transactions.length, 1);

      provider.removeTransaction('1');
      await Future.delayed(const Duration(milliseconds: 100));
      expect(provider.transactions.isEmpty, true);
    });
  });

  group('Search and Filter', () {
    setUp(() async {
      await provider.clearAllTransactions();

      final transactions = [
        Transaction(
          id: '1',
          amount: 100.0,
          description: 'Grocery Shopping',
          date: DateTime(2025, 7, 1),
          type: TransactionType.expense,
          categoryId: 'food',
          accountId: 'bank',
        ),
        Transaction(
          id: '2',
          amount: 50.0,
          description: 'Gas Station',
          date: DateTime(2025, 7, 1),
          type: TransactionType.expense,
          categoryId: 'transport',
          accountId: 'bank',
        ),
        Transaction(
          id: '3',
          amount: 75.0,
          description: 'Grocery Store',
          date: DateTime(2025, 7, 1),
          type: TransactionType.expense,
          categoryId: 'food',
          accountId: 'cash',
        ),
      ];

      for (final transaction in transactions) {
        provider.addTransaction(transaction);
      }
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('Search functionality', () async {
      provider.setSearchQuery('Grocery');
      expect(provider.transactions.length, 2);

      provider.setSearchQuery('gas');
      expect(provider.transactions.length, 1);

      provider.setSearchQuery('');
      expect(provider.transactions.length, 3);
    });

    test('Category filtering', () async {
      final foodTransactions = provider.getTransactionsByCategory('food');
      expect(foodTransactions.length, 2);

      final transportTransactions = provider.getTransactionsByCategory('transport');
      expect(transportTransactions.length, 1);
    });

    test('Account filtering', () async {
      final bankTransactions = provider.getTransactionsByAccount('bank');
      expect(bankTransactions.length, 2);

      final cashTransactions = provider.getTransactionsByAccount('cash');
      expect(cashTransactions.length, 1);
    });
  });

  group('Date-based Operations', () {
    setUp(() async {
      await provider.clearAllTransactions();

      final transactions = [
        Transaction(
          id: '1',
          amount: 1000.0,
          description: 'June Salary',
          date: DateTime(2025, 6, 30),
          type: TransactionType.income,
          categoryId: 'salary',
          accountId: 'bank',
        ),
        Transaction(
          id: '2',
          amount: 500.0,
          description: 'June Rent',
          date: DateTime(2025, 6, 15),
          type: TransactionType.expense,
          categoryId: 'housing',
          accountId: 'bank',
        ),
        Transaction(
          id: '3',
          amount: 1200.0,
          description: 'July Salary',
          date: DateTime(2025, 7, 1),
          type: TransactionType.income,
          categoryId: 'salary',
          accountId: 'bank',
        ),
      ];

      for (final transaction in transactions) {
        provider.addTransaction(transaction);
      }
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('Monthly calculations', () async {
      expect(provider.getMonthlyIncome(DateTime(2025, 6)), 1000.0);
      expect(provider.getMonthlyExpenses(DateTime(2025, 6)), 500.0);
      expect(provider.getMonthlyIncome(DateTime(2025, 7)), 1200.0);
      expect(provider.getMonthlyExpenses(DateTime(2025, 7)), 0.0);
    });

    test('Date range calculations', () async {
      final start = DateTime(2025, 6, 1);
      final end = DateTime(2025, 6, 30);

      expect(provider.getIncomeByDateRange(start, end), 1000.0);
      expect(provider.getExpensesByDateRange(start, end), 500.0);
      expect(provider.getBalanceByDateRange(start, end), 500.0);
    });

    test('Sorting by date', () async {
      final transactions = provider.transactions;
      expect(transactions[0].date.isAfter(transactions[1].date), true);
      expect(transactions[1].date.isAfter(transactions[2].date), true);
    });
  });
}