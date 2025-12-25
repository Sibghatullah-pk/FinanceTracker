import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_state.dart';
import '../models/transaction.dart';
import 'add_expense_screen.dart';
import 'expense_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, ${appState.currentUser?.name ?? 'User'} 👋',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              appState.hasHousehold
                                  ? 'Shared Budget'
                                  : 'Personal Budget',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: theme.colorScheme.primary
                              .withAlpha((0.1 * 255).round()),
                          child: Text(
                            appState.currentUser?.name
                                    .substring(0, 1)
                                    .toUpperCase() ??
                                'U',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Budget Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildBudgetCard(context, appState),
                  ),

                  const SizedBox(height: 24),

                  // Charts: Income vs Expense and Category breakdown
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: LayoutBuilder(builder: (ctx, constraints) {
                      final narrow = constraints.maxWidth < 700;
                      if (narrow) {
                        return Column(
                          children: [
                            _buildIncomeExpenseChart(context, appState),
                            const SizedBox(height: 12),
                            _buildCategoryPie(context, appState),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: 2,
                              child:
                                  _buildIncomeExpenseChart(context, appState)),
                          const SizedBox(width: 12),
                          Expanded(
                              flex: 3,
                              child: _buildCategoryPie(context, appState)),
                        ],
                      );
                    }),
                  ),

                  const SizedBox(height: 24),

                  // Member contribution summary
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildMemberContributions(context, appState),
                  ),

                  const SizedBox(height: 12),

                  // AI Insights Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildAIInsightsCard(context, appState),
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuickAction(
                            context,
                            icon: Icons.add,
                            label: 'Add Expense',
                            color: theme.colorScheme.error,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddExpenseScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickAction(
                            context,
                            icon: Icons.trending_up,
                            label: 'Add Income',
                            color: theme.colorScheme.secondary,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AddExpenseScreen(isIncome: true),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Recent Expenses Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Expenses',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('See All'),
                        ),
                      ],
                    ),
                  ),

                  // Expenses List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: appState.transactions.length > 5
                        ? 5
                        : appState.transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = appState.transactions[index];
                      return _buildTransactionItem(
                          context, transaction, appState);
                    },
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBudgetCard(BuildContext context, AppState appState) {
    final theme = Theme.of(context);
    final percentage = appState.monthlyLimit > 0
        ? (appState.totalSpent / appState.monthlyLimit).clamp(0.0, 1.0)
        : 0.0;
    final isOverBudget = appState.totalSpent > appState.monthlyLimit;
    if (appState.isAdmin) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withAlpha((0.8 * 255).round()),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withAlpha((0.3 * 255).round()),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Budget',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Text(
              'Rs. ${appState.monthlyLimit.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 8,
                backgroundColor: Colors.white.withAlpha((0.3 * 255).round()),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverBudget ? theme.colorScheme.error : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Spent',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.white70)),
                    Text('Rs. ${appState.totalSpent.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Remaining',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.white70)),
                    Text('Rs. ${appState.remaining.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Contributor / non-admin view (read-only)
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Shared Monthly Budget', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text('Rs. ${appState.monthlyLimit.toStringAsFixed(0)}',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: theme.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(isOverBudget
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary)),
          const SizedBox(height: 8),
          Text('Spent: Rs. ${appState.totalSpent.toStringAsFixed(0)}',
              style: theme.textTheme.bodySmall),
          Text('Remaining: Rs. ${appState.remaining.toStringAsFixed(0)}',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseChart(BuildContext context, AppState appState) {
    final theme = Theme.of(context);
    final incomes = appState.totalIncomes;
    final expenses = appState.totalExpenses;
    final maxVal =
        ((incomes.abs() > expenses.abs() ? incomes : expenses) * 1.25)
            .ceilToDouble();
    String fmt(double v) {
      if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
      if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
      return v.toStringAsFixed(0);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Income vs Expense', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal <= 0 ? 1 : maxVal,
                  barTouchData: const BarTouchData(enabled: false),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                            toY: incomes,
                            color: Colors.green,
                            width: 18,
                            borderRadius: BorderRadius.circular(6)),
                      ],
                      showingTooltipIndicators: [0],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                            toY: expenses.abs(),
                            color: Colors.redAccent,
                            width: 18,
                            borderRadius: BorderRadius.circular(6)),
                      ],
                      showingTooltipIndicators: [0],
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: maxVal / 4,
                            getTitlesWidget: (v, meta) {
                              return Text(fmt(v),
                                  style: const TextStyle(fontSize: 10));
                            })),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, meta) {
                              final idx = v.toInt();
                              if (idx == 0) {
                                return const Padding(
                                    padding: EdgeInsets.only(top: 6),
                                    child: Text('Income'));
                              }
                              return const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text('Expense'));
                            })),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Income: ${fmt(incomes)}',
                    style: theme.textTheme.bodySmall),
                Text('Expense: ${fmt(expenses)}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPie(BuildContext context, AppState appState) {
    final theme = Theme.of(context);
    final data = appState.categoryTotals;
    final total = data.values.fold(0.0, (s, v) => s + v);
    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
              child: Text('No category data yet',
                  style: theme.textTheme.bodyMedium)),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    int i = 0;
    final colors = [
      Colors.purple,
      Colors.orange,
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.cyan
    ];
    data.forEach((cat, value) {
      final pct = total > 0 ? (value / total) * 100 : 0;
      sections.add(PieChartSectionData(
        color: colors[i % colors.length],
        value: value,
        title: pct >= 3 ? '${pct.toStringAsFixed(0)}%' : '',
        radius: 56,
        titleStyle: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        showTitle: pct >= 3,
      ));
      i++;
    });

    Widget legend() {
      final entries = data.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.take(6).map((e) {
          final idx = data.keys.toList().indexOf(e.key);
          final color = colors[idx % colors.length];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Text(e.key, style: theme.textTheme.bodySmall),
                ]),
                Text('Rs. ${e.value.toStringAsFixed(0)}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          );
        }).toList(),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spending by Category', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 160,
                    child: PieChart(PieChartData(
                        sections: sections,
                        centerSpaceRadius: 36,
                        sectionsSpace: 4)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: legend()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberContributions(BuildContext context, AppState appState) {
    final theme = Theme.of(context);
    final contributions = appState.memberContributions;
    if (contributions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
              child: Text('No contributions yet',
                  style: theme.textTheme.bodyMedium)),
        ),
      );
    }
    // Map userId -> name
    final names = {for (var m in appState.members) m.uid: m.name};
    final items = contributions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Member Contributions', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...items.map((e) {
              final name = names[e.key] ?? e.key;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: theme.textTheme.bodySmall),
                    Text('Rs. ${e.value.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
      BuildContext context, Transaction transaction, AppState appState) {
    final theme = Theme.of(context);
    final isExpense = transaction.type == TransactionType.expense;

    return Card(
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExpenseDetailScreen(transaction: transaction),
            ),
          );
        },
        leading: Icon(
          _getCategoryIcon(transaction.category),
          color:
              isExpense ? theme.colorScheme.error : theme.colorScheme.secondary,
        ),
        title: Text(transaction.title),
        subtitle: Text(transaction.createdByName),
        trailing: Text(
          '${isExpense ? '-' : '+'}Rs. ${transaction.amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isExpense
                ? theme.colorScheme.error
                : theme.colorScheme.secondary,
          ),
        ),
      ),
    );
  }

  Widget _buildAIInsightsCard(BuildContext context, AppState appState) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Insights', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<String?>(
              future: appState.fetchLatestAIPrediction(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                      height: 40,
                      child: Center(child: CircularProgressIndicator()));
                }
                final text = snap.data;
                if (text == null || text.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                        'No insights yet. Request an AI advisory for your household.',
                        style: theme.textTheme.bodySmall),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: theme.textTheme.bodySmall),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      messenger.showSnackBar(const SnackBar(
                          content: Text('Requesting AI insights...')));
                      await appState.requestAIPrediction();
                      messenger.showSnackBar(
                          const SnackBar(content: Text('AI insights updated')));
                    } catch (e) {
                      messenger.showSnackBar(
                          SnackBar(content: Text('AI request failed: $e')));
                    }
                  },
                  child: const Text('Request AI Insights'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food & dining':
        return Icons.restaurant;
      case 'transportation':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'entertainment':
        return Icons.movie;
      case 'bills & utilities':
        return Icons.receipt_long;
      case 'salary':
        return Icons.account_balance_wallet;
      case 'freelance':
        return Icons.work;
      default:
        return Icons.attach_money;
    }
  }
}
