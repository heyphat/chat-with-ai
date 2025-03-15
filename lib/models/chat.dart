import 'message.dart';

enum AIProvider { openai, anthropic, gemini }

// New class to store only metadata for faster loading
class ChatMetadata {
  final String id;
  final String title;
  final int messageCount;
  final AIProvider provider;
  final String model;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessagePreview;

  ChatMetadata({
    required this.id,
    required this.title,
    required this.messageCount,
    required this.provider,
    required this.model,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessagePreview,
  });

  factory ChatMetadata.fromJson(Map<String, dynamic> json) {
    return ChatMetadata(
      id: json['id'],
      title: json['title'],
      messageCount: json['messageCount'] ?? 0,
      provider: AIProvider.values.byName(json['provider']),
      model: json['model'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      lastMessagePreview: json['lastMessagePreview'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messageCount': messageCount,
      'provider': provider.name,
      'model': model,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastMessagePreview': lastMessagePreview,
    };
  }

  // Create metadata from a full Chat object
  factory ChatMetadata.fromChat(Chat chat) {
    String? preview;
    if (chat.messages.isNotEmpty) {
      final lastMessage = chat.messages.last;
      // Create a truncated preview of the last message
      preview =
          lastMessage.content.length > 100
              ? '${lastMessage.content.substring(0, 100)}...'
              : lastMessage.content;
      preview = preview.replaceAll('\n', ' ');
    }

    return ChatMetadata(
      id: chat.id,
      title: chat.title,
      messageCount: chat.messages.length,
      provider: chat.provider,
      model: chat.model,
      createdAt: chat.createdAt,
      updatedAt: chat.updatedAt,
      lastMessagePreview: preview,
    );
  }
}

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
      messages:
          (json['messages'] as List)
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
