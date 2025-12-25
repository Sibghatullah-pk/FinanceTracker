import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/savings_goal.dart';
import 'goal_create_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class GoalsListScreen extends StatelessWidget {
  const GoalsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Consumer<AppState>(
        builder: (context, app, _) {
          final goals = app.goals.where((g) => !g.archived).toList();
          if (goals.isEmpty) {
            return Center(
              child: Text('No goals yet', style: theme.textTheme.bodyLarge),
            );
          }

          return Column(
            children: [
              // Graph Section
              SizedBox(
                height: 220,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: true),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < goals.length) {
                                return Text(
                                  goals[index].title,
                                  style: const TextStyle(fontSize: 10),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (int i = 0; i < goals.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: goals[i].currentAmount,
                                color: theme.colorScheme.primary,
                                width: 12,
                              ),
                              BarChartRodData(
                                toY: goals[i].targetAmount,
                                color: theme.colorScheme.secondary,
                                width: 12,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Goals List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: goals.length,
                  itemBuilder: (_, i) => _GoalCard(goal: goals[i]),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GoalCreateScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Goal'),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = goal.progress;
    final remaining =
        (goal.targetAmount - goal.currentAmount).clamp(0, double.infinity);
    final now = DateTime.now();
    final daysLeft = goal.deadline.difference(now).inDays;
    final isCompleted = goal.currentAmount >= goal.targetAmount;

    return Card(
      color: goal.archived ? Colors.grey[100] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (goal.archived)
                  _statusChip('ARCHIVED', Colors.grey[300], Colors.black)
                else if (isCompleted)
                  _statusChip('COMPLETED', Colors.green[100], Colors.green),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Rs. ${goal.currentAmount.toStringAsFixed(0)} saved'),
                Text('Target: Rs. ${goal.targetAmount.toStringAsFixed(0)}'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress, minHeight: 10),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('${(progress * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall),
                const SizedBox(width: 12),
                Text('Remaining: Rs. ${remaining.toStringAsFixed(0)}',
                    style: theme.textTheme.bodySmall),
                const SizedBox(width: 12),
                Icon(Icons.calendar_today, size: 14, color: theme.hintColor),
                const SizedBox(width: 4),
                Text(
                  'Due: ${goal.deadline.toLocal().toString().split(' ').first}',
                  style: theme.textTheme.bodySmall,
                ),
                if (daysLeft >= 0)
                  Text(
                    ' (${daysLeft}d left)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
              ],
            ),
            if (goal.notes != null && goal.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notes: ${goal.notes}', style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Text(
              'Created: ${goal.createdAt.toLocal().toString().split(' ').first}',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: goal.archived
                      ? null
                      : () => _allocateDialog(context, goal),
                  icon: const Icon(Icons.savings),
                  label: const Text('Allocate'),
                ),
                const Spacer(),
                if (!goal.archived)
                  TextButton(
                    onPressed: () => _archive(context, goal),
                    child: Text(
                      'Archive',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String text, Color? bgColor, Color? textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  void _allocateDialog(BuildContext context, SavingsGoal goal) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Allocate to goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (Rs.)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text.trim()) ?? 0;
              if (amount > 0) {
                await context.read<AppState>().allocateToGoal(goal.id, amount);
                Navigator.pop(context);
              }
            },
            child: const Text('Allocate'),
          ),
        ],
      ),
    );
  }

  void _archive(BuildContext context, SavingsGoal goal) async {
    await context.read<AppState>().archiveGoal(goal.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Goal archived')),
    );
  }
}
