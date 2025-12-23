import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { income, expense }

class Transaction {
  final String id;
  final String title;
  final double amount;
  final String category;
  final TransactionType type;
  final DateTime date;
  final String? note;
  final String createdBy;
  final String createdByName;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.type,
    required this.date,
    this.note,
    required this.createdBy,
    required this.createdByName,
  });

  /// Save to Firestore with consistent schema
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'type': type == TransactionType.expense ? 'expense' : 'income',
      'date': Timestamp.fromDate(date),
      'note': note,
      'createdBy': createdBy,
      'createdByName': createdByName,
    };
  }

  /// Build from Firestore map
  factory Transaction.fromMap(String id, Map<String, dynamic> json) {
    final rawDate = json['date'];

    DateTime parsedDate;
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final rawType = json['type'];
    TransactionType parsedType;
    if (rawType == 'income') {
      parsedType = TransactionType.income;
    } else {
      parsedType = TransactionType.expense;
    }

    return Transaction(
      id: id,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      type: parsedType,
      date: parsedDate,
      note: json['note'] as String?,
      createdBy: json['createdBy'] as String? ?? '',
      createdByName: json['createdByName'] as String? ?? '',
    );
  }

  /// Create a copy with optional overrides
  Transaction copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    TransactionType? type,
    DateTime? date,
    String? note,
    String? createdBy,
    String? createdByName,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      type: type ?? this.type,
      date: date ?? this.date,
      note: note ?? this.note,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
    );
  }
}
