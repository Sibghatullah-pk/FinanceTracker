import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final CollectionReference users =
  FirebaseFirestore.instance.collection('users');

  /// Save a new user to Firestore with name and monthly budget
  Future<void> saveUser(String uid, String email, String name, double budget) async {
    await users.doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'monthlyBudget': budget,
      'createdAt': Timestamp.now(),
    });
  }

  /// Update existing user data (optional helper)
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await users.doc(uid).update(data);
  }

  /// Fetch a user document
  Future<DocumentSnapshot> getUser(String uid) async {
    return await users.doc(uid).get();
  }
}
