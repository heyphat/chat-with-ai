import 'message.dart';
import 'token_usage.dart';

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
  final int? totalTokens; // Total token count for the chat
  final double? totalCost; // Estimated total cost

  ChatMetadata({
    required this.id,
    required this.title,
    required this.messageCount,
    required this.provider,
    required this.model,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessagePreview,
    this.totalTokens,
    this.totalCost,
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
      totalTokens: json['totalTokens'],
      totalCost:
          json['totalCost'] != null
              ? (json['totalCost'] as num).toDouble()
              : null,
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
      'totalTokens': totalTokens,
      'totalCost': totalCost,
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

    // Calculate token usage
    final tokenInfo = chat.totalTokens;
    final costInfo = chat.totalCost;

    return ChatMetadata(
      id: chat.id,
      title: chat.title,
      messageCount: chat.messages.length,
      provider: chat.provider,
      model: chat.model,
      createdAt: chat.createdAt,
      updatedAt: chat.updatedAt,
      lastMessagePreview: preview,
      totalTokens: tokenInfo['totalTokens'],
      totalCost: costInfo['totalCost'],
    );
  }

  // Add a copyWith method to create a new instance with some fields updated
  ChatMetadata copyWith({
    String? id,
    String? title,
    int? messageCount,
    AIProvider? provider,
    String? model,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessagePreview,
    int? totalTokens,
    double? totalCost,
  }) {
    return ChatMetadata(
      id: id ?? this.id,
      title: title ?? this.title,
      messageCount: messageCount ?? this.messageCount,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      totalTokens: totalTokens ?? this.totalTokens,
      totalCost: totalCost ?? this.totalCost,
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

  // Get the total token usage across all messages
  Map<String, int> get totalTokens {
    int totalPromptTokens = 0;
    int totalCompletionTokens = 0;
    int totalAllTokens = 0;

    for (final message in messages) {
      if (message.tokenUsage != null) {
        totalPromptTokens += message.tokenUsage!.promptTokens ?? 0;
        totalCompletionTokens += message.tokenUsage!.completionTokens ?? 0;
        totalAllTokens += message.tokenUsage!.totalTokens ?? 0;
      }
    }

    return {
      'promptTokens': totalPromptTokens,
      'completionTokens': totalCompletionTokens,
      'totalTokens': totalAllTokens,
    };
  }

  // Calculate the total cost of this chat
  Map<String, double> get totalCost {
    double totalPromptCost = 0;
    double totalCompletionCost = 0;
    double totalCostAll = 0;

    for (final message in messages) {
      if (message.tokenUsage != null) {
        totalPromptCost += message.tokenUsage!.promptCost ?? 0;
        totalCompletionCost += message.tokenUsage!.completionCost ?? 0;
        totalCostAll += message.tokenUsage!.totalCost ?? 0;
      }
    }

    return {
      'promptCost': totalPromptCost,
      'completionCost': totalCompletionCost,
      'totalCost': totalCostAll,
    };
  }

  // Calculate estimated cost based on a pricing model
  Map<String, double> calculateEstimatedCost(TokenPricing pricing) {
    double promptCost = 0;
    double completionCost = 0;
    double totalCost = 0;

    for (final message in messages) {
      if (message.tokenUsage != null) {
        final tokenUsage = message.tokenUsage!;

        if (tokenUsage.promptTokens != null) {
          promptCost += pricing.calculateCost(
            model,
            tokenUsage.promptTokens!,
            isPrompt: true,
          );
        }

        if (tokenUsage.completionTokens != null) {
          completionCost += pricing.calculateCost(
            model,
            tokenUsage.completionTokens!,
            isPrompt: false,
          );
        }
      }
    }

    totalCost = promptCost + completionCost;

    return {
      'promptCost': promptCost,
      'completionCost': completionCost,
      'totalCost': totalCost,
    };
  }

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
