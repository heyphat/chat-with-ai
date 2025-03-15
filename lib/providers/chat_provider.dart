import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/ai_service.dart';
import '../services/openai_service.dart';
import '../services/anthropic_service.dart';
import '../services/gemini_service.dart';
import 'dart:developer' as developer;

class ChatProvider extends ChangeNotifier {
  // Metadata for all chats (lightweight)
  List<ChatMetadata> _chatMetadata = [];

  // Full chat data for active chat only (to reduce memory usage)
  Chat? _activeChat;

  // Cache of loaded chats (for quick access to recently used chats)
  final Map<String, Chat> _chatCache = {};

  // Maximum number of chats to keep in memory cache
  static const int _maxChatCacheSize = 5;

  bool _isLoading = false;
  final _uuid = const Uuid();

  // Keys for storage
  static const String _chatMetadataKey = 'chat_metadata';
  static const String _chatDataPrefix = 'chat_data_';
  static const String _activeChatKey = 'activeChat';
  static const int _maxChatHistory =
      50; // Maximum number of chats to keep in history

  // Add OpenAI model options
  static const Map<String, String> openAIModels = {
    'gpt-4o-mini': 'GPT-4o Mini',
    'gpt-4o': 'GPT-4o',
    'gpt-4': 'GPT-4',
    'gpt-4-turbo': 'GPT-4 Turbo',
    'gpt-3.5-turbo': 'GPT-3.5 Turbo',
  };

  // Add Anthropic model options
  static const Map<String, String> anthropicModels = {
    'claude-3-opus': 'Claude 3 Opus',
    'claude-3-sonnet': 'Claude 3 Sonnet',
    'claude-3-haiku': 'Claude 3 Haiku',
  };

  // Add Gemini model options
  static const Map<String, String> geminiModels = {
    //'gemini-2.0-pro': 'Gemini 2.0 Pro',
    //'gemini-2.0-flash': 'Gemini 2.0 Flash',
    'gemini-1.5-pro': 'Gemini 1.5 Pro',
    'gemini-1.5-flash': 'Gemini 1.5 Flash',
  };

  ChatProvider() {
    _loadChatMetadataFromPrefs();
  }

  // Getters
  List<ChatMetadata> get chatMetadata => _chatMetadata;
  Chat? get activeChat => _activeChat;
  bool get isLoading => _isLoading;

  // Helper method to sort metadata by most recent update
  void _sortChatMetadata() {
    _chatMetadata.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  // Create a new chat
  Future<String> createChat(AIProvider provider, String model) async {
    final modelName =
        provider == AIProvider.openai
            ? openAIModels[model] ?? model
            : provider == AIProvider.anthropic
            ? anthropicModels[model] ?? model
            : geminiModels[model] ?? model;

    final newChat = Chat(
      id: _uuid.v4(),
      title: 'Chat with $modelName',
      messages: [],
      provider: provider,
      model: model,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Create metadata
    final metadata = ChatMetadata.fromChat(newChat);

    // Update state
    _chatMetadata.add(metadata);
    _sortChatMetadata(); // Sort to ensure most recent is first
    _activeChat = newChat;
    _chatCache[newChat.id] = newChat;

    notifyListeners();

    // Save to storage
    await _saveChatMetadataToPrefs();
    await _saveChatToPrefs(newChat);

    // Return the new chat ID so caller can use it
    return newChat.id;
  }

  // Delete a chat
  Future<void> deleteChat(String chatId) async {
    // Remove from metadata
    _chatMetadata.removeWhere((metadata) => metadata.id == chatId);

    // Remove from cache
    _chatCache.remove(chatId);

    // Update active chat if needed
    if (_activeChat != null && _activeChat!.id == chatId) {
      if (_chatMetadata.isNotEmpty) {
        await loadChatContent(_chatMetadata[0].id);
      } else {
        _activeChat = null;
      }
    }

    notifyListeners();

    // Save state and remove chat data
    await _saveChatMetadataToPrefs();

    // Remove chat data from storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_chatDataPrefix$chatId');
  }

  // Set active chat - with lazy loading
  Future<void> setActiveChat(String chatId) async {
    try {
      // Check if requested chat is already active
      if (_activeChat?.id == chatId) {
        return; // Already active, nothing to do
      }

      // We no longer update the timestamp when selecting a chat
      // Just load the chat content without changing updatedAt or resorting
      await loadChatContent(chatId);

      // Save active chat ID to preferences (in background)
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_activeChatKey, chatId);
      });
    } catch (e) {
      developer.log('Error setting active chat: $e');
      // Try to load first chat if available
      if (_chatMetadata.isNotEmpty && _chatMetadata[0].id != chatId) {
        await loadChatContent(_chatMetadata[0].id);
      }
    }
  }

  // Load chat content (lazy loading)
  Future<void> loadChatContent(String chatId) async {
    try {
      // Check if chat is in memory cache first
      if (_chatCache.containsKey(chatId)) {
        _activeChat = _chatCache[chatId];
        notifyListeners();
        return;
      }

      // Otherwise load from storage
      final prefs = await SharedPreferences.getInstance();
      final chatJson = prefs.getString('$_chatDataPrefix$chatId');

      if (chatJson != null) {
        final chat = Chat.fromJson(jsonDecode(chatJson));

        // Update active chat
        _activeChat = chat;

        // Add to cache
        _chatCache[chatId] = chat;

        // Manage cache size
        if (_chatCache.length > _maxChatCacheSize) {
          // Remove oldest item from cache (not being viewed)
          final keysToRemove =
              _chatCache.keys.where((key) => key != _activeChat!.id).toList();

          if (keysToRemove.isNotEmpty) {
            _chatCache.remove(keysToRemove.first);
          }
        }

        notifyListeners();
      } else {
        throw Exception('Chat not found: $chatId');
      }
    } catch (e) {
      developer.log('Error loading chat content: $e');
      rethrow;
    }
  }

  // Update chat title
  Future<void> updateChatTitle(String chatId, String newTitle) async {
    // Update metadata
    final metadataIndex = _chatMetadata.indexWhere(
      (metadata) => metadata.id == chatId,
    );
    if (metadataIndex != -1) {
      final updatedMetadata = ChatMetadata(
        id: _chatMetadata[metadataIndex].id,
        title: newTitle,
        messageCount: _chatMetadata[metadataIndex].messageCount,
        provider: _chatMetadata[metadataIndex].provider,
        model: _chatMetadata[metadataIndex].model,
        createdAt: _chatMetadata[metadataIndex].createdAt,
        updatedAt: DateTime.now(),
        lastMessagePreview: _chatMetadata[metadataIndex].lastMessagePreview,
      );

      _chatMetadata[metadataIndex] = updatedMetadata;
      _sortChatMetadata(); // Sort to move this chat to the top
    }

    // Update active chat if needed
    if (_activeChat?.id == chatId) {
      final updatedChat = _activeChat!.copyWith(
        title: newTitle,
        updatedAt: DateTime.now(),
      );

      _activeChat = updatedChat;

      // Update cache
      _chatCache[chatId] = updatedChat;

      // Save chat data
      await _saveChatToPrefs(updatedChat);
    } else if (_chatCache.containsKey(chatId)) {
      // Update cached chat
      final cachedChat = _chatCache[chatId]!;
      final updatedChat = cachedChat.copyWith(
        title: newTitle,
        updatedAt: DateTime.now(),
      );

      _chatCache[chatId] = updatedChat;

      // Save chat data
      await _saveChatToPrefs(updatedChat);
    } else {
      // Load, update and save chat
      final prefs = await SharedPreferences.getInstance();
      final chatJson = prefs.getString('$_chatDataPrefix$chatId');

      if (chatJson != null) {
        final chat = Chat.fromJson(jsonDecode(chatJson));
        final updatedChat = chat.copyWith(
          title: newTitle,
          updatedAt: DateTime.now(),
        );

        await _saveChatToPrefs(updatedChat);
      }
    }

    notifyListeners();
    await _saveChatMetadataToPrefs();
  }

  // Send a message to the AI and get a streamed response
  Future<void> sendMessage(String content) async {
    if (_activeChat == null) return;

    // Create a user message
    final userMessage = Message(
      id: _uuid.v4(),
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );

    // Create a loading assistant message
    final assistantMessage = Message(
      id: _uuid.v4(),
      content: '',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      isLoading: true,
    );

    // Add messages to the active chat
    final updatedMessages = [
      ..._activeChat!.messages,
      userMessage,
      assistantMessage,
    ];

    // Update active chat
    final updatedChat = _activeChat!.copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );

    // Update state and cache
    _activeChat = updatedChat;
    _chatCache[updatedChat.id] = updatedChat;
    _isLoading = true;

    // Update metadata
    final metadataIndex = _chatMetadata.indexWhere(
      (metadata) => metadata.id == updatedChat.id,
    );
    if (metadataIndex != -1) {
      _chatMetadata[metadataIndex] = ChatMetadata.fromChat(updatedChat);
      _sortChatMetadata(); // Sort to ensure most recent is first
    }

    notifyListeners();

    // Save initial state but don't await to avoid blocking the stream
    _saveChatToPrefs(updatedChat);
    _saveChatMetadataToPrefs();

    // Get AI service based on provider
    final aiService = _getAIService(_activeChat!.provider);

    try {
      // Create a variable to accumulate the streamed response
      String responseContent = '';

      // Start the stream
      final stream = aiService.getCompletionStream(
        _activeChat!.messages
            .where((msg) => msg.id != assistantMessage.id)
            .toList(),
        _activeChat!.model,
      );

      // Listen to the stream and update the message content
      await for (String chunk in stream) {
        responseContent += chunk;

        // Update the assistant message with the accumulated content
        final updatedAssistantMessage = assistantMessage.copyWith(
          content: responseContent,
          isLoading: true,
        );

        // Get the current state of active chat
        final currentChat = _activeChat!;

        // Update messages, preserving all other messages
        final streamingMessages =
            currentChat.messages.map((msg) {
              if (msg.id == assistantMessage.id) {
                return updatedAssistantMessage;
              }
              return msg;
            }).toList();

        // Update active chat
        final streamingChat = currentChat.copyWith(
          messages: streamingMessages,
          updatedAt: DateTime.now(),
        );

        // Update state and cache
        _activeChat = streamingChat;
        _chatCache[streamingChat.id] = streamingChat;

        // Notify listeners immediately to update UI
        notifyListeners();

        // Small delay to allow UI to update (use microtask instead of actual delay to avoid blocking)
        await Future.microtask(() => {});
      }

      // Final update with completed state
      final finalAssistantMessage = assistantMessage.copyWith(
        content: responseContent,
        isLoading: false,
      );

      // Get the current state of active chat
      final finalCurrentChat = _activeChat!;

      // Update messages
      final finalMessages =
          finalCurrentChat.messages.map((msg) {
            if (msg.id == assistantMessage.id) {
              return finalAssistantMessage;
            }
            return msg;
          }).toList();

      // Update active chat
      final finalChat = finalCurrentChat.copyWith(
        messages: finalMessages,
        updatedAt: DateTime.now(),
      );

      // Update state and cache
      _activeChat = finalChat;
      _chatCache[finalChat.id] = finalChat;
      _isLoading = false;

      // Update metadata with new message preview
      final finalMetadataIndex = _chatMetadata.indexWhere(
        (metadata) => metadata.id == finalChat.id,
      );
      if (finalMetadataIndex != -1) {
        _chatMetadata[finalMetadataIndex] = ChatMetadata.fromChat(finalChat);
        _sortChatMetadata(); // Sort to ensure most recent is first
      }

      notifyListeners();

      // Save the final state
      await _saveChatToPrefs(finalChat);
      await _saveChatMetadataToPrefs();

      // If this is the first message exchange, generate a title
      if (finalMessages.length == 2) {
        await generateChatTitle();
      }
    } catch (e) {
      developer.log('Error during AI streaming: $e');

      // Create error message
      final errorMessage = assistantMessage.copyWith(
        content: 'Error: Failed to get response from AI: ${e.toString()}',
        isLoading: false,
        error: e.toString(),
      );

      // Get the current state of active chat
      final errorCurrentChat = _activeChat!;

      // Update messages
      final errorMessages =
          errorCurrentChat.messages.map((msg) {
            if (msg.id == assistantMessage.id) {
              return errorMessage;
            }
            return msg;
          }).toList();

      // Update active chat
      final errorChat = errorCurrentChat.copyWith(
        messages: errorMessages,
        updatedAt: DateTime.now(),
      );

      // Update state and cache
      _activeChat = errorChat;
      _chatCache[errorChat.id] = errorChat;
      _isLoading = false;

      // Update metadata
      final errorMetadataIndex = _chatMetadata.indexWhere(
        (metadata) => metadata.id == errorChat.id,
      );
      if (errorMetadataIndex != -1) {
        _chatMetadata[errorMetadataIndex] = ChatMetadata.fromChat(errorChat);
        _sortChatMetadata(); // Sort to ensure most recent is first
      }

      notifyListeners();

      // Save the error state
      await _saveChatToPrefs(errorChat);
      await _saveChatMetadataToPrefs();
    }
  }

  // Generate a title for the chat using the AI service
  Future<void> generateChatTitle() async {
    if (_activeChat == null) return;

    try {
      // Get AI service based on provider
      final aiService = _getAIService(_activeChat!.provider);

      // Create a title request message
      final titleRequestMessage = Message(
        id: _uuid.v4(),
        content:
            'What would be a short and relevant title for this chat? You must strictly answer with only the title, no other text is allowed. Do not include any quotation marks in your response.',
        role: MessageRole.user,
        timestamp: DateTime.now(),
      );

      // Use non-streaming version to get a single clean response
      final title = await aiService.getCompletion([
        ..._activeChat!.messages,
        titleRequestMessage,
      ], _activeChat!.model);

      // Clean any extra text that might have been included (should be just the title)
      // Also remove any quotes that might be in the response
      final cleanTitle = title.trim().replaceAll('"', '').replaceAll("'", '');

      // Update the chat title
      await updateChatTitle(_activeChat!.id, cleanTitle);

      developer.log('Generated chat title: $cleanTitle');
    } catch (e) {
      developer.log('Error generating chat title: $e');
      // Don't update the title if there's an error
    }
  }

  // Clear chat history
  Future<void> clearChatHistory() async {
    try {
      // Get all chat IDs to remove individually
      final chatIds = _chatMetadata.map((metadata) => metadata.id).toList();

      // Clear in-memory data
      _chatMetadata = [];
      _activeChat = null;
      _chatCache.clear();
      _isLoading = false;

      notifyListeners();

      // Clear storage
      final prefs = await SharedPreferences.getInstance();

      // Remove metadata
      await prefs.remove(_chatMetadataKey);
      await prefs.remove(_activeChatKey);

      // Remove individual chat data
      for (final chatId in chatIds) {
        await prefs.remove('$_chatDataPrefix$chatId');
      }

      developer.log('Chat history cleared successfully');
    } catch (e) {
      developer.log('Error clearing chat history: $e');
    }
  }

  // Export chat history as JSON string
  Future<String> exportChatHistory() async {
    try {
      // Load all chats before exporting
      final allChats = <Chat>[];

      for (final metadata in _chatMetadata) {
        if (_chatCache.containsKey(metadata.id)) {
          // Use cached version
          allChats.add(_chatCache[metadata.id]!);
        } else {
          // Load from storage
          final prefs = await SharedPreferences.getInstance();
          final chatJson = prefs.getString('$_chatDataPrefix${metadata.id}');

          if (chatJson != null) {
            allChats.add(Chat.fromJson(jsonDecode(chatJson)));
          }
        }
      }

      final exportData = {
        'chats': allChats.map((chat) => chat.toJson()).toList(),
        'activeChat': _activeChat?.id,
        'exportDate': DateTime.now().toIso8601String(),
      };

      return jsonEncode(exportData);
    } catch (e) {
      developer.log('Error exporting chat history: $e');
      return ''; // Return empty string on error
    }
  }

  // Import chat history from JSON string
  Future<bool> importChatHistory(String jsonData) async {
    try {
      final importData = jsonDecode(jsonData);

      final chats =
          (importData['chats'] as List)
              .map((chatJson) => Chat.fromJson(chatJson))
              .toList();

      final activeChatId = importData['activeChat'] as String?;

      // Clear existing data
      await clearChatHistory();

      // Create metadata for each chat
      _chatMetadata = chats.map((chat) => ChatMetadata.fromChat(chat)).toList();

      // Save each chat individually
      for (final chat in chats) {
        await _saveChatToPrefs(chat);
      }

      // Set active chat
      if (activeChatId != null &&
          chats.any((chat) => chat.id == activeChatId)) {
        final activeChat = chats.firstWhere((chat) => chat.id == activeChatId);
        _activeChat = activeChat;
        _chatCache[activeChat.id] = activeChat;
      } else if (chats.isNotEmpty) {
        _activeChat = chats[0];
        _chatCache[chats[0].id] = chats[0];
      } else {
        _activeChat = null;
      }

      // Save metadata
      await _saveChatMetadataToPrefs();

      // Save active chat id
      if (_activeChat != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_activeChatKey, _activeChat!.id);
      }

      notifyListeners();

      developer.log('Chat history imported successfully');
      return true;
    } catch (e) {
      developer.log('Error importing chat history: $e');
      return false;
    }
  }

  // Get AI service based on provider
  AIService _getAIService(AIProvider provider) {
    switch (provider) {
      case AIProvider.openai:
        return OpenAIService();
      case AIProvider.anthropic:
        return AnthropicService();
      case AIProvider.gemini:
        return GeminiService();
    }
  }

  // Update active chat provider and model
  Future<void> updateChatProvider(
    AIProvider newProvider,
    String newModel,
  ) async {
    if (_activeChat == null) return;

    // // Get the model display name
    // final modelName =
    //     newProvider == AIProvider.openai
    //         ? openAIModels[newModel] ?? newModel
    //         : newProvider == AIProvider.anthropic
    //         ? anthropicModels[newModel] ?? newModel
    //         : geminiModels[newModel] ?? newModel;

    // Update active chat with new provider and model
    final updatedChat = _activeChat!.copyWith(
      provider: newProvider,
      model: newModel,
      updatedAt: DateTime.now(),
    );

    // Update state and cache
    _activeChat = updatedChat;
    _chatCache[updatedChat.id] = updatedChat;

    // Update metadata
    final metadataIndex = _chatMetadata.indexWhere(
      (metadata) => metadata.id == updatedChat.id,
    );
    if (metadataIndex != -1) {
      _chatMetadata[metadataIndex] = ChatMetadata.fromChat(updatedChat);
      _sortChatMetadata(); // Sort to ensure most recent is first
    }

    notifyListeners();

    // Save to storage
    await _saveChatToPrefs(updatedChat);
    await _saveChatMetadataToPrefs();

    developer.log(
      'Updated chat provider to ${newProvider.name} with model $newModel',
    );
  }

  // Load chat metadata from SharedPreferences
  Future<void> _loadChatMetadataFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load metadata
      final metadataJson = prefs.getString(_chatMetadataKey);

      if (metadataJson != null) {
        final List<dynamic> metadataList = jsonDecode(metadataJson);
        _chatMetadata =
            metadataList.map((json) => ChatMetadata.fromJson(json)).toList();

        // Sort by most recent
        _sortChatMetadata();
      }

      // Load active chat ID
      final activeChatId = prefs.getString(_activeChatKey);

      if (activeChatId != null &&
          _chatMetadata.any((m) => m.id == activeChatId)) {
        // Load the active chat
        await loadChatContent(activeChatId);
      } else if (_chatMetadata.isNotEmpty) {
        // Load the first chat as active (which will be the most recent due to sorting)
        await loadChatContent(_chatMetadata[0].id);
      }

      notifyListeners();
      developer.log('Loaded ${_chatMetadata.length} chat metadata items');
    } catch (e) {
      developer.log('Error loading chat metadata: $e');
      _chatMetadata = [];
      _activeChat = null;
      notifyListeners();
    }
  }

  // Save chat metadata to SharedPreferences
  Future<void> _saveChatMetadataToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Limit number of chats
      if (_chatMetadata.length > _maxChatHistory) {
        _chatMetadata.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _chatMetadata = _chatMetadata.sublist(0, _maxChatHistory);
      }

      // Convert to JSON
      final metadataList = _chatMetadata.map((m) => m.toJson()).toList();
      final metadataJson = jsonEncode(metadataList);

      // Save to storage
      await prefs.setString(_chatMetadataKey, metadataJson);

      developer.log('Saved ${_chatMetadata.length} chat metadata items');
    } catch (e) {
      developer.log('Error saving chat metadata: $e');
    }
  }

  // Save individual chat to SharedPreferences
  Future<void> _saveChatToPrefs(Chat chat) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatJson = jsonEncode(chat.toJson());
      await prefs.setString('$_chatDataPrefix${chat.id}', chatJson);
    } catch (e) {
      developer.log('Error saving chat ${chat.id}: $e');
    }
  }
}
