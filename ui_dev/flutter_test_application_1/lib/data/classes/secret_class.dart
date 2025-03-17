class Secret {
  final int id;
  final String secret;
  final int emScore;
  final String username;
  final String timestamp;

  const Secret({
    required this.id,
    required this.secret,
    required this.emScore,
    required this.username,
    required this.timestamp,
  });

  factory Secret.fromJson(Map<String, dynamic> json) {
    return Secret(
      id: json['id'] as int,
      secret: json['secret'] as String,
      emScore: json['emScore'] as int,
      username: json['username'] as String,
      timestamp: json['timestamp'] as String,
    );
  }
}
