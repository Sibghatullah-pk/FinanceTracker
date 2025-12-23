import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/savings_goal.dart';
import 'goal_create_screen.dart';

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
            return Center(child: Text('No goals yet', style: theme.textTheme.bodyLarge));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            itemBuilder: (_, i) => _GoalCard(goal: goals[i]),
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
    final remaining = (goal.targetAmount - goal.currentAmount).clamp(0, double.infinity);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(goal.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
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
            Text('Remaining: Rs. ${remaining.toStringAsFixed(0)} • Due: ${goal.deadline.toLocal().toString().split(' ').first}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _allocateDialog(context, goal),
                  icon: const Icon(Icons.savings),
                  label: const Text('Allocate'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _archive(context, goal),
                  child: Text('Archive', style: TextStyle(color: theme.colorScheme.error)),
                ),
              ],
            ),
          ],
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goal archived')));
  }
}
