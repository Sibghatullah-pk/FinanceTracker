class Household {
  final String id;
  final List<String> memberIds;
  final Map<String, String> roles; // uid: "admin" or "contributor"
  final double monthlyLimit;
  final double spent;
  final String inviteCode;

  Household({
    required this.id,
    required this.memberIds,
    required this.roles,
    required this.monthlyLimit,
    this.spent = 0,
    required this.inviteCode,
  });

  double get remaining => monthlyLimit - spent;
  double get spentPercentage => spent / monthlyLimit;
  bool get isOverBudget => spent > monthlyLimit;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberIds': memberIds,
      'roles': roles,
      'monthlyLimit': monthlyLimit,
      'spent': spent,
      'inviteCode': inviteCode,
    };
  }

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: json['id'] as String,
      memberIds: List<String>.from(json['memberIds']),
      roles: Map<String, String>.from(json['roles']),
      monthlyLimit: (json['monthlyLimit'] as num).toDouble(),
      spent: (json['spent'] as num).toDouble(),
      inviteCode: json['inviteCode'] as String,
    );
  }

  Household copyWith({
    String? id,
    List<String>? memberIds,
    Map<String, String>? roles,
    double? monthlyLimit,
    double? spent,
    String? inviteCode,
  }) {
    return Household(
      id: id ?? this.id,
      memberIds: memberIds ?? this.memberIds,
      roles: roles ?? this.roles,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      spent: spent ?? this.spent,
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }
}
