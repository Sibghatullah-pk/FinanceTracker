import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isExpense;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isExpense = true,
  });

  static List<Category> expenseCategories = [
    Category(
      id: 'food',
      name: 'Food & Dining',
      icon: Icons.restaurant,
      color: const Color(0xFFFF6B6B),
    ),
    Category(
      id: 'transport',
      name: 'Transportation',
      icon: Icons.directions_car,
      color: const Color(0xFF4ECDC4),
    ),
    Category(
      id: 'shopping',
      name: 'Shopping',
      icon: Icons.shopping_bag,
      color: const Color(0xFFFFBE0B),
    ),
    Category(
      id: 'entertainment',
      name: 'Entertainment',
      icon: Icons.movie,
      color: const Color(0xFFFB5607),
    ),
    Category(
      id: 'bills',
      name: 'Bills & Utilities',
      icon: Icons.receipt_long,
      color: const Color(0xFF8338EC),
    ),
    Category(
      id: 'health',
      name: 'Healthcare',
      icon: Icons.local_hospital,
      color: const Color(0xFF3A86FF),
    ),
    Category(
      id: 'others',
      name: 'Others',
      icon: Icons.more_horiz,
      color: const Color(0xFF9CA3AF),
    ),
  ];

  static List<Category> incomeCategories = [
    Category(
      id: 'salary',
      name: 'Salary',
      icon: Icons.account_balance_wallet,
      color: const Color(0xFF06D6A0),
      isExpense: false,
    ),
    Category(
      id: 'freelance',
      name: 'Freelance',
      icon: Icons.work,
      color: const Color(0xFF118AB2),
      isExpense: false,
    ),
    Category(
      id: 'investment',
      name: 'Investment',
      icon: Icons.trending_up,
      color: const Color(0xFF073B4C),
      isExpense: false,
    ),
    Category(
      id: 'other_income',
      name: 'Other Income',
      icon: Icons.attach_money,
      color: const Color(0xFF06D6A0),
      isExpense: false,
    ),
  ];
}
