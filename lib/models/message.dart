enum MessageRole { user, assistant, system }

class Message {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final bool isLoading;
  final String? error;

  Message({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isLoading = false,
    this.error,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'],
      role: MessageRole.values.byName(json['role']),
      timestamp: DateTime.parse(json['timestamp']),
      isLoading: json['isLoading'] ?? false,
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'role': role.name,
      'timestamp': timestamp.toIso8601String(),
      'isLoading': isLoading,
      'error': error,
    };
  }

  Message copyWith({
    String? id,
    String? content,
    MessageRole? role,
    DateTime? timestamp,
    bool? isLoading,
    String? error,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
} 