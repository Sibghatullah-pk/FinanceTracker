import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../widgets/transaction_item.dart';
import '../utils/app_theme.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _selectedFilter = 'All';

  final List<Transaction> _allTransactions = [
    Transaction(
      id: '1',
      title: 'Monthly Salary',
      amount: 5000,
      category: 'Salary',
      type: TransactionType.income,
      date: DateTime.now(),
    ),
    Transaction(
      id: '2',
      title: 'Grocery Shopping',
      amount: 150,
      category: 'Food & Dining',
      type: TransactionType.expense,
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Transaction(
      id: '3',
      title: 'Uber Ride',
      amount: 25,
      category: 'Transportation',
      type: TransactionType.expense,
      date: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Transaction(
      id: '4',
      title: 'Netflix Subscription',
      amount: 15,
      category: 'Entertainment',
      type: TransactionType.expense,
      date: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Transaction(
      id: '5',
      title: 'Freelance Project',
      amount: 1200,
      category: 'Freelance',
      type: TransactionType.income,
      date: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  List<Transaction> get _filteredTransactions {
    if (_selectedFilter == 'Income') {
      return _allTransactions
          .where((t) => t.type == TransactionType.income)
          .toList();
    } else if (_selectedFilter == 'Expense') {
      return _allTransactions
          .where((t) => t.type == TransactionType.expense)
          .toList();
    }
    return _allTransactions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Income'),
                const SizedBox(width: 8),
                _buildFilterChip('Expense'),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: _filteredTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredTransactions.length,
                    itemBuilder: (context, index) {
                      return TransactionItem(
                        transaction: _filteredTransactions[index],
                        onTap: () {},
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
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
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
