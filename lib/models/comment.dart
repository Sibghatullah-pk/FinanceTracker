import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String userId;
  final String text;
  final DateTime timestamp;
  final String userName;

  Comment({
    required this.id,
    required this.userId,
    required this.text,
    required this.timestamp,
    required this.userName,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory Comment.fromJson(String id, Map<String, dynamic> json) {
    return Comment(
      id: id,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      text: json['text'] as String,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
    );
  }
}
