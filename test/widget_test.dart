import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/models/transaction.dart';
import 'package:expense_tracker/providers/transaction_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Set up shared preferences for testing
    SharedPreferences.setMockInitialValues({});
  });

  group('Transaction Management Tests', () {
    late TransactionProvider provider;

    setUp(() async {
      provider = TransactionProvider();
      // Wait for the provider to initialize
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('Adding transactions', () async {
      // Add an income transaction
      provider.addTransaction(Transaction(
        id: '1',
        amount: 1000.0,
        description: 'Salary',
        date: DateTime(2025, 7, 1),
        type: TransactionType.income,
        categoryId: 'default',
        accountId: 'default',
      ));

      // Add an expense transaction
      provider.addTransaction(Transaction(
        id: '2',
        amount: 50.0,
        description: 'Groceries',
        date: DateTime(2025, 7, 1),
        type: TransactionType.expense,
        categoryId: 'default',
        accountId: 'default',
      ));

      expect(provider.transactions.length, 2);
      expect(provider.getTotalBalance(), 950.0); // 1000 - 50
      expect(provider.getTotalIncome(), 1000.0);
      expect(provider.getTotalExpenses(), 50.0);
    });

    test('Editing transactions', () async {
      // Add initial transaction
      final transaction = Transaction(
        id: '1',
        amount: 100.0,
        description: 'Original',
        date: DateTime(2025, 7, 1),
        type: TransactionType.expense,
        categoryId: 'default',
        accountId: 'default',
      );
      provider.addTransaction(transaction);

      // Edit the transaction
      final editedTransaction = Transaction(
        id: '1', // Same ID
        amount: 150.0, // Changed amount
        description: 'Updated', // Changed description
        date: DateTime(2025, 7, 1),
        type: TransactionType.expense,
        categoryId: 'default',
        accountId: 'default',
      );
      provider.updateTransaction(editedTransaction);

      expect(provider.transactions.first.amount, 150.0);
      expect(provider.transactions.first.description, 'Updated');
      expect(provider.getTotalExpenses(), 150.0);
    });
  });

  group('Monthly Summary Tests', () {
    late TransactionProvider provider;

    setUp(() async {
      provider = TransactionProvider();
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('Monthly calculations should be correct', () async {
      // Add transactions for June
      provider.addTransaction(Transaction(
        id: '1',
        amount: 1000.0,
        description: 'June Salary',
        date: DateTime(2025, 6, 30),
        type: TransactionType.income,
        categoryId: 'default',
        accountId: 'default',
      ));

      provider.addTransaction(Transaction(
        id: '2',
        amount: 300.0,
        description: 'June Rent',
        date: DateTime(2025, 6, 15),
        type: TransactionType.expense,
        categoryId: 'default',
        accountId: 'default',
      ));

      // Add transactions for July
      provider.addTransaction(Transaction(
        id: '3',
        amount: 1200.0,
        description: 'July Salary',
        date: DateTime(2025, 7, 1),
        type: TransactionType.income,
        categoryId: 'default',
        accountId: 'default',
      ));

      expect(provider.getMonthlyIncome(DateTime(2025, 6)), 1000.0);
      expect(provider.getMonthlyExpenses(DateTime(2025, 6)), 300.0);
      expect(provider.getMonthlyIncome(DateTime(2025, 7)), 1200.0);
    });
  });

  group('Search Functionality Tests', () {
    late TransactionProvider provider;

    setUp(() async {
      provider = TransactionProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      // Add test transactions
      provider.addTransaction(Transaction(
        id: '1',
        amount: 100.0,
        description: 'Grocery Shopping',
        date: DateTime(2025, 7, 1),
        type: TransactionType.expense,
        categoryId: 'default',
        accountId: 'default',
      ));

      provider.addTransaction(Transaction(
        id: '2',
        amount: 50.0,
        description: 'Gas Station',
        date: DateTime(2025, 7, 1),
        type: TransactionType.expense,
        categoryId: 'default',
        accountId: 'default',
      ));
    });

    test('Search should filter transactions correctly', () async {
      provider.setSearchQuery('Grocery');
      expect(provider.transactions.length, 1);
      
      provider.setSearchQuery('Gas');
      expect(provider.transactions.length, 1);
      
      provider.setSearchQuery('xyz');
      expect(provider.transactions.isEmpty, true);
      
      provider.setSearchQuery('');
      expect(provider.transactions.length, 2);
    });

    test('Search should be case insensitive', () async {
      provider.setSearchQuery('grocery');
      expect(provider.transactions.length, 1);
      
      provider.setSearchQuery('GROCERY');
      expect(provider.transactions.length, 1);
    });
  });

  group('Widget Tests', () {
    testWidgets('App should show add transaction form', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Tap the FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Find form fields
      expect(find.byType(TextFormField), findsNWidgets(2));
      
      // Enter text in form fields
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount').first,
        '100'
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description').first,
        'Test Transaction'
      );

      // Find and tap the submit button
      await tester.tap(find.widgetWithText(FilledButton, 'Add Transaction'));
      await tester.pumpAndSettle();

      // Verify the transaction was added
      expect(find.text('Test Transaction'), findsOneWidget);
    });
  });
}