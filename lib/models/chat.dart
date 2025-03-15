import 'message.dart';

enum AIProvider { openai, anthropic, gemini }

class Chat {
  final String id;
  final String title;
  final List<Message> messages;
  final AIProvider provider;
  final String model;
  final DateTime createdAt;
  final DateTime updatedAt;

  Chat({
    required this.id,
    required this.title,
    required this.messages,
    required this.provider,
    required this.model,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'],
      title: json['title'],
      messages: (json['messages'] as List)
          .map((msg) => Message.fromJson(msg))
          .toList(),
      provider: AIProvider.values.byName(json['provider']),
      model: json['model'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((msg) => msg.toJson()).toList(),
      'provider': provider.name,
      'model': model,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Chat copyWith({
    String? id,
    String? title,
    List<Message>? messages,
    AIProvider? provider,
    String? model,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Chat(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 