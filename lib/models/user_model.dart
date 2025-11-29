class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? householdId;
  final String? profilePic;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.householdId,
    this.profilePic,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'householdId': householdId,
      'profilePic': profilePic,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      householdId: json['householdId'] as String?,
      profilePic: json['profilePic'] as String?,
    );
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? householdId,
    String? profilePic,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      householdId: householdId ?? this.householdId,
      profilePic: profilePic ?? this.profilePic,
    );
  }
}
