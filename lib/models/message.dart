import 'token_usage.dart';

enum MessageRole { user, assistant, system }

class Message {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final bool isLoading;
  final String? error;
  final TokenUsage? tokenUsage;

  Message({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isLoading = false,
    this.error,
    this.tokenUsage,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'],
      role: MessageRole.values.byName(json['role']),
      timestamp: DateTime.parse(json['timestamp']),
      isLoading: json['isLoading'] ?? false,
      error: json['error'],
      tokenUsage:
          json['tokenUsage'] != null
              ? TokenUsage.fromJson(json['tokenUsage'])
              : null,
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
      'tokenUsage': tokenUsage?.toJson(),
    };
  }

  Message copyWith({
    String? id,
    String? content,
    MessageRole? role,
    DateTime? timestamp,
    bool? isLoading,
    String? error,
    TokenUsage? tokenUsage,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      tokenUsage: tokenUsage ?? this.tokenUsage,
    );
  }
}
