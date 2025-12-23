import 'package:cloud_firestore/cloud_firestore.dart';

class SavingsGoal {
  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime deadline;
  final String createdBy;
  final DateTime createdAt;
  final String? notes;
  final bool archived;

  SavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
    required this.createdBy,
    required this.createdAt,
    this.notes,
    this.archived = false,
  });

  factory SavingsGoal.fromMap(String id, Map<String, dynamic> data) {
    return SavingsGoal(
      id: id,
      title: data['title'] as String,
      targetAmount: (data['targetAmount'] as num).toDouble(),
      currentAmount: (data['currentAmount'] as num).toDouble(),
      deadline: (data['deadline'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      notes: data['notes'] as String?,
      archived: (data['archived'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'deadline': Timestamp.fromDate(deadline),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
      'archived': archived,
    };
  }

  double get progress =>
      targetAmount == 0 ? 0 : (currentAmount / targetAmount).clamp(0.0, 1.0);
}
