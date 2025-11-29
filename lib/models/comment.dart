class Comment {
  final String id;
  final String oderId;
  final String text;
  final DateTime timestamp;
  final String userName;

  Comment({
    required this.id,
    required this.oderId,
    required this.text,
    required this.timestamp,
    required this.userName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': oderId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'userName': userName,
    };
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      oderId: json['userId'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userName: json['userName'] as String,
    );
  }
}
