import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../models/transaction.dart' as app;
import 'expense_detail_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('All Expenses'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final appState = context.read<AppState>();
              await appState.refresh();
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(content: Text('Refreshed')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          List<app.Transaction> filteredTransactions = appState.transactions;

          if (_selectedFilter == 'Income') {
            filteredTransactions = filteredTransactions
                .where((t) => t.type == app.TransactionType.income)
                .toList();
          } else if (_selectedFilter == 'Expense') {
            filteredTransactions = filteredTransactions
                .where((t) => t.type == app.TransactionType.expense)
                .toList();
          }

          return Column(
            children: [
              // Filter Chips
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildFilterChip(context, 'All'),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, 'Expense'),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, 'Income'),
                  ],
                ),
              ),

              // Transaction List
              Expanded(
                child: filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 64, color: theme.disabledColor),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions yet',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredTransactions.length,
                        itemBuilder: (context, index) {
                          final transaction = filteredTransactions[index];
                          return _buildTransactionItem(
                              context, transaction, appState);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label) {
    final theme = Theme.of(context);
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
      BuildContext context, app.Transaction transaction, AppState appState) {
    final theme = Theme.of(context);
    final isExpense = transaction.type == app.TransactionType.expense;
    final comments = appState.getComments(transaction.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExpenseDetailScreen(transaction: transaction),
            ),
          );
        },
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isExpense
                ? theme.colorScheme.error.withOpacity(0.1)
                : theme.colorScheme.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getCategoryIcon(transaction.category),
            color: isExpense
                ? theme.colorScheme.error
                : theme.colorScheme.secondary,
          ),
        ),
        title: Text(transaction.title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            )),
        subtitle: Row(
          children: [
            Text(transaction.createdByName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                )),
            if (comments.isNotEmpty) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showCommentsSheet(context, transaction, appState),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 14, color: theme.disabledColor),
                    const SizedBox(width: 4),
                    Text('${comments.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.disabledColor,
                        )),
                  ],
                ),
              ),
            ],
          ],
        ),
        trailing: Text(
          '${isExpense ? '-' : '+'}Rs. ${transaction.amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isExpense
                ? theme.colorScheme.error
                : theme.colorScheme.secondary,
          ),
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

  void _showAddExpenseDialog(BuildContext context) {
    final theme = Theme.of(context);
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = 'Food & Dining';
    String selectedType = 'Expense';

    showDialog(
      context: context,
      builder: (context) {
        final appState = context.read<AppState>();
        final isAdmin = appState.isAdmin;
        return AlertDialog(
          title: const Text('Add Transaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                items: const [
                  'Food & Dining',
                  'Transportation',
                  'Shopping',
                  'Entertainment',
                  'Bills & Utilities',
                  'Healthcare',
                  'Others',
                ]
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedCategory = value);
                  }
                },
              ),
              if (isAdmin)
                DropdownButton<String>(
                  value: selectedType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'Expense', child: Text('Expense')),
                    DropdownMenuItem(value: 'Income', child: Text('Income')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedType = value);
                    }
                  },
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('Contributors can only add expenses',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final appState = context.read<AppState>();
                if (appState.currentUser == null ||
                    appState.household == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Please login and create/join a household first')),
                  );
                  return;
                }

                final title = titleController.text.trim();
                final amount =
                    double.tryParse(amountController.text.trim()) ?? 0;

                if (title.isEmpty || amount <= 0) return;

                // Only admin can add income
                if (!isAdmin && selectedType == 'Income') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Only Admin can add income transactions.')),
                  );
                  return;
                }

                final transaction = app.Transaction(
                  id: '',
                  title: title,
                  amount: amount,
                  category: selectedCategory,
                  type: selectedType == 'Income'
                      ? app.TransactionType.income
                      : app.TransactionType.expense,
                  date: DateTime.now(),
                  note: null,
                  createdBy: appState.currentUser!.uid,
                  createdByName: appState.currentUser!.name,
                );

                await appState.addTransaction(transaction);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showCommentsSheet(BuildContext context, app.Transaction transaction,
      AppState appState) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    await appState.subscribeToComments(transaction.id);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text('Comments',
                      style: Theme.of(ctx).textTheme.titleMedium),
                ),
                Expanded(
                  child: Consumer<AppState>(builder: (c, state, _) {
                    final list = state.getComments(transaction.id);
                    if (list.isEmpty) {
                      return const Center(child: Text('No comments yet'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final cm = list[index];
                        return ListTile(
                          title: Text(cm.userName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(cm.text),
                          trailing: Text(
                            TimeOfDay.fromDateTime(cm.timestamp)
                                .format(context),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        );
                      },
                    );
                  }),
                ),
                SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                                hintText: 'Write a comment...'),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () async {
                          final text = controller.text.trim();
                          if (text.isEmpty) return;
                          try {
                            await appState.addComment(transaction.id, text);
                            controller.clear();
                          } catch (e) {
                            messenger.showSnackBar(const SnackBar(
                                content: Text('Failed to send comment')));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // when sheet is closed, unsubscribe
    await appState.unsubscribeFromComments(transaction.id);
  }
}
