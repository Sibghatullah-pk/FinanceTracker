import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../utils/format_helper.dart';
import '../utils/app_theme.dart';

class TransactionItem extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionItem({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isIncome
                ? AppTheme.successColor.withAlpha((0.1 * 255).round())
                : AppTheme.primaryColor.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIncome ? AppTheme.successColor : AppTheme.primaryColor,
          ),
        ),
        title: Text(
          transaction.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          '${transaction.category} • ${FormatHelper.formatDateShort(transaction.date)}',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'} ${FormatHelper.formatCurrency(transaction.amount)}',
          style: TextStyle(
            color: isIncome ? AppTheme.successColor : AppTheme.errorColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
