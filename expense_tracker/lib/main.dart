import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/transaction_provider.dart';
import 'models/transaction.dart';
import 'widgets/transaction_form.dart';
import 'widgets/monthly_summary.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TransactionProvider(),
      child: MaterialApp(
        title: 'Expense Tracker',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () {
              final balance = context.read<TransactionProvider>().getTotalBalance();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Total Balance: \$${balance.toStringAsFixed(2)}'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                context.read<TransactionProvider>().setSearchQuery(value);
              },
            ),
          ),
          // Monthly Summary
          MonthlySummary(month: DateTime.now()),
          // Transaction List
          Expanded(
            child: Consumer<TransactionProvider>(
              builder: (context, provider, child) {
                final transactions = provider.transactions;
                return transactions.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No transactions yet!',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap + to add a new transaction',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = transactions[index];
                          return Dismissible(
                            key: Key(transaction.id),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            direction: DismissDirection.endToStart,
                            onDismissed: (direction) {
                              provider.removeTransaction(transaction.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Transaction deleted'),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    onPressed: () {
                                      provider.addTransaction(transaction);
                                    },
                                  ),
                                ),
                              );
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: InkWell(
                                onLongPress: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (context) => TransactionForm(
                                      transaction: transaction,
                                      onSubmit: (updatedTransaction) {
                                        provider.updateTransaction(updatedTransaction);
                                      },
                                    ),
                                  );
                                },
                                child: ListTile(
                                  leading: Icon(
                                    transaction.type == TransactionType.income
                                        ? Icons.arrow_circle_up
                                        : Icons.arrow_circle_down,
                                    color: transaction.type == TransactionType.income
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  title: Text(
                                    transaction.description,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  subtitle: Text(
                                    _formatDate(transaction.date),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  trailing: Text(
                                    '${transaction.type == TransactionType.income ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: transaction.type == TransactionType.income
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => TransactionForm(
              onSubmit: (transaction) {
                context.read<TransactionProvider>().addTransaction(transaction);
              },
            ),
          );
        },
        tooltip: 'Add Transaction',
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}