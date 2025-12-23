import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/transaction.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          // Calculate totals
          double totalIncome = 0;
          double totalExpense = 0;
          Map<String, double> categorySpending = {};

          for (var t in appState.transactions) {
            if (t.type == TransactionType.income) {
              totalIncome += t.amount;
            } else {
              totalExpense += t.amount;
              categorySpending[t.category] =
                  (categorySpending[t.category] ?? 0) + t.amount;
            }
          }

          final balance = totalIncome - totalExpense;
          final maxCategoryAmount = categorySpending.isEmpty
              ? 1.0
              : categorySpending.values.reduce((a, b) => a > b ? a : b);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month Selector
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getCurrentMonth(),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.calendar_today,
                          size: 20, color: theme.iconTheme.color),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Budget Progress Card
                if (appState.household != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Monthly Budget',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              )),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Rs. ${appState.totalSpent.toStringAsFixed(0)} spent',
                                style: theme.textTheme.bodyMedium,
                              ),
                              Text(
                                'Rs. ${appState.monthlyLimit.toStringAsFixed(0)} budget',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: (appState.totalSpent /
                                      appState.monthlyLimit)
                                  .clamp(0.0, 1.0),
                              minHeight: 12,
                              backgroundColor: theme.dividerColor,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                appState.totalSpent > appState.monthlyLimit
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rs. ${appState.remaining.toStringAsFixed(0)} remaining',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: appState.remaining < 0
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Income vs Expense Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Income vs Expense',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            )),
                        const SizedBox(height: 20),
                        _buildStatRow(
                            context,
                            'Income',
                            'Rs. ${totalIncome.toStringAsFixed(0)}',
                            theme.colorScheme.secondary),
                        const SizedBox(height: 12),
                        _buildStatRow(
                            context,
                            'Expense',
                            'Rs. ${totalExpense.toStringAsFixed(0)}',
                            theme.colorScheme.error),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        _buildStatRow(
                          context,
                          'Balance',
                          'Rs. ${balance.toStringAsFixed(0)}',
                          balance >= 0
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.error,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Spending by Category
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Spending by Category',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            )),
                        const SizedBox(height: 20),
                        if (categorySpending.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text('No expenses yet',
                                  style: theme.textTheme.bodyMedium),
                            ),
                          )
                        else
                          ...categorySpending.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildCategoryBar(
                                context,
                                entry.key,
                                entry.value,
                                maxCategoryAmount * 1.2,
                                theme.colorScheme.primary,
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Export Report Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      await appState.exportMonthlyReport(now.year, now.month);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Report exported successfully!')),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Export Monthly Report'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getCurrentMonth() {
    final now = DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  Widget _buildStatRow(
      BuildContext context, String label, String amount, Color color) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(amount,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            )),
      ],
    );
  }

  Widget _buildCategoryBar(
      BuildContext context, String category, double amount, double total, Color color) {
    final theme = Theme.of(context);
    final percentage = (amount / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(category,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis),
            ),
            Text('Rs. ${amount.toStringAsFixed(0)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 8,
            backgroundColor: theme.dividerColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
