import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';

class MonthlySummary extends StatelessWidget {
  final DateTime month;

  const MonthlySummary({
    super.key,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
        final monthlyIncome = provider.getMonthlyIncome(month);
        final monthlyExpenses = provider.getMonthlyExpenses(month);
        final monthlyBalance = monthlyIncome - monthlyExpenses;

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  '${_getMonthName(month.month)} ${month.year}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Divider(),
                _buildSummaryRow(
                  context,
                  'Monthly Income',
                  monthlyIncome,
                  Colors.green,
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  context,
                  'Monthly Expenses',
                  monthlyExpenses,
                  Colors.red,
                ),
                const Divider(),
                _buildSummaryRow(
                  context,
                  'Monthly Balance',
                  monthlyBalance,
                  monthlyBalance >= 0 ? Colors.green : Colors.red,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    double amount,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          '\$${amount.abs().toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'
    ];
    return monthNames[month - 1];
  }
}