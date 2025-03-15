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
  List<Chat> _chats = [];
  Chat? _activeChat;
  bool _isLoading = false;
  final _uuid = const Uuid();
  static const String _chatsKey = 'chats';
  static const String _activeChatKey = 'activeChat';
  static const String _chatIndexKey = 'chat_index';
  static const int _maxChatHistory = 50; // Maximum number of chats to keep in history
  
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
    _loadChatsFromPrefs();
  }

  // Getters
  List<Chat> get chats => _chats;
  Chat? get activeChat => _activeChat;
  bool get isLoading => _isLoading;

  // Create a new chat
  Future<void> createChat(AIProvider provider, String model) async {
    final modelName = provider == AIProvider.openai 
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

    _chats.add(newChat);
    _activeChat = newChat;
    notifyListeners();
    await _saveChatsToPrefs();
  }

  // Delete a chat
  Future<void> deleteChat(String chatId) async {
    _chats.removeWhere((chat) => chat.id == chatId);
    
    if (_activeChat != null && _activeChat!.id == chatId) {
      _activeChat = _chats.isNotEmpty ? _chats[0] : null;
    }
    
    notifyListeners();
    await _saveChatsToPrefs();
  }

  // Set active chat
  Future<void> setActiveChat(String chatId) async {
    try {
      final chat = _chats.firstWhere((c) => c.id == chatId);
      _activeChat = chat;
      notifyListeners();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeChatKey, chatId);
    } catch (e) {
      developer.log('Error setting active chat: $e');
      if (_chats.isNotEmpty) {
        _activeChat = _chats[0];
        notifyListeners();
      }
    }
  }

  // Update chat title
  Future<void> updateChatTitle(String chatId, String newTitle) async {
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index != -1) {
      final updatedChat = _chats[index].copyWith(
        title: newTitle,
        updatedAt: DateTime.now(),
      );
      _chats[index] = updatedChat;
      
      if (_activeChat?.id == chatId) {
        _activeChat = updatedChat;
      }
      
      notifyListeners();
      await _saveChatsToPrefs();
    }
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

    // Update state
    final chatIndex = _chats.indexWhere((chat) => chat.id == _activeChat!.id);
    _chats[chatIndex] = updatedChat;
    _activeChat = updatedChat;
    _isLoading = true;
    notifyListeners();
    
    // Save initial state but don't await to avoid blocking the stream
    _saveChatsToPrefs();

    // Get AI service based on provider
    final aiService = _getAIService(_activeChat!.provider);

    try {
      // Create a variable to accumulate the streamed response
      String responseContent = '';
      
      // Start the stream
      final stream = aiService.getCompletionStream(
        _activeChat!.messages.where((msg) => msg.id != assistantMessage.id).toList(),
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
        
        // Find the latest state of active chat to avoid stale updates
        final currentChatIndex = _chats.indexWhere((chat) => chat.id == _activeChat!.id);
        final currentChat = _chats[currentChatIndex];
        
        // Update messages, preserving all other messages
        final streamingMessages = currentChat.messages.map((msg) {
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
        
        // Update state
        _chats[currentChatIndex] = streamingChat;
        _activeChat = streamingChat;
        
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
      
      // Find the latest state again
      final finalChatIndex = _chats.indexWhere((chat) => chat.id == _activeChat!.id);
      final finalCurrentChat = _chats[finalChatIndex];
      
      // Update messages
      final finalMessages = finalCurrentChat.messages.map((msg) {
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
      
      // Update state
      _chats[finalChatIndex] = finalChat;
      _activeChat = finalChat;
      _isLoading = false;
      notifyListeners();
      
      // Save the final state
      await _saveChatsToPrefs();
      
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

      // Find the latest state
      final errorChatIndex = _chats.indexWhere((chat) => chat.id == _activeChat!.id);
      final errorCurrentChat = _chats[errorChatIndex];
      
      // Update messages
      final errorMessages = errorCurrentChat.messages.map((msg) {
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

      // Update state
      _chats[errorChatIndex] = errorChat;
      _activeChat = errorChat;
      _isLoading = false;
      notifyListeners();
      
      // Save the error state
      await _saveChatsToPrefs();
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
        content: 'What would be a short and relevant title for this chat? You must strictly answer with only the title, no other text is allowed. Do not include any quotation marks in your response.',
        role: MessageRole.user,
        timestamp: DateTime.now(),
      );
      
      // Use non-streaming version to get a single clean response
      final title = await aiService.getCompletion(
        [..._activeChat!.messages, titleRequestMessage],
        _activeChat!.model,
      );
      
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
      _chats = [];
      _activeChat = null;
      _isLoading = false;
      notifyListeners();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chatsKey);
      await prefs.remove(_activeChatKey);
      await prefs.remove(_chatIndexKey);
      
      developer.log('Chat history cleared successfully');
    } catch (e) {
      developer.log('Error clearing chat history: $e');
    }
  }

  // Export chat history as JSON string
  String exportChatHistory() {
    try {
      final exportData = {
        'chats': _chats.map((chat) => chat.toJson()).toList(),
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
      
      final chatsList = (importData['chats'] as List)
          .map((chatJson) => Chat.fromJson(chatJson))
          .toList();
          
      final activeChatId = importData['activeChat'] as String?;
      
      _chats = chatsList;
      
      if (activeChatId != null && _chats.any((chat) => chat.id == activeChatId)) {
        _activeChat = _chats.firstWhere((chat) => chat.id == activeChatId);
      } else if (_chats.isNotEmpty) {
        _activeChat = _chats[0];
      } else {
        _activeChat = null;
      }
      
      notifyListeners();
      await _saveChatsToPrefs();
      
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

  // Load chats from SharedPreferences with chunking for large histories
  Future<void> _loadChatsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // First check if we have chat data stored in individual chunks
      final chatCount = prefs.getInt(_chatIndexKey) ?? 0;
      
      if (chatCount > 0) {
        // Load chats from individual chunks
        _chats = [];
        for (int i = 0; i < chatCount; i++) {
          final chatJson = prefs.getString('${_chatsKey}_$i');
          if (chatJson != null) {
            try {
              final chat = Chat.fromJson(jsonDecode(chatJson));
              _chats.add(chat);
            } catch (e) {
              developer.log('Error parsing chat ${i + 1}: $e');
              // Continue loading other chats even if one fails
            }
          }
        }
        
        // Sort chats by most recent update
        _chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      } else {
        // Try loading from legacy storage (all chats in one list)
        final chatsJson = prefs.getStringList(_chatsKey);
        if (chatsJson != null && chatsJson.isNotEmpty) {
          _chats = [];
          for (final json in chatsJson) {
            try {
              final chat = Chat.fromJson(jsonDecode(json));
              _chats.add(chat);
            } catch (e) {
              developer.log('Error parsing chat: $e');
              // Continue loading other chats
            }
          }
          
          // Migrate to new chunked storage format
          await _saveChatsToPrefs();
        }
      }
      
      // Load active chat
      final activeChatId = prefs.getString(_activeChatKey);
      if (activeChatId != null && _chats.isNotEmpty) {
        try {
          _activeChat = _chats.firstWhere(
            (chat) => chat.id == activeChatId,
            orElse: () => _chats[0],
          );
        } catch (e) {
          developer.log('Error finding active chat: $e');
          if (_chats.isNotEmpty) {
            _activeChat = _chats[0];
          }
        }
      } else if (_chats.isNotEmpty) {
        _activeChat = _chats[0];
      }
      
      developer.log('Loaded ${_chats.length} chats from storage');
      notifyListeners();
    } catch (e) {
      developer.log('Error loading chats: $e');
      // Initialize with empty state if loading fails
      _chats = [];
      _activeChat = null;
    }
  }

  // Create a default chat if none exists
  Chat _createDefaultChat() {
    final defaultModel = openAIModels.keys.first;
    final modelName = openAIModels[defaultModel] ?? defaultModel;
    
    return Chat(
      id: _uuid.v4(),
      title: 'Chat with $modelName',
      messages: [],
      provider: AIProvider.openai,
      model: defaultModel,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Save chats to SharedPreferences using chunking for better performance
  Future<void> _saveChatsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Limit number of chats to prevent storage issues
      if (_chats.length > _maxChatHistory) {
        // Keep most recently updated chats
        _chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _chats = _chats.sublist(0, _maxChatHistory);
      }
      
      // Clear previous chat data
      final previousCount = prefs.getInt(_chatIndexKey) ?? 0;
      for (int i = 0; i < previousCount; i++) {
        await prefs.remove('${_chatsKey}_$i');
      }
      
      // Store each chat as a separate item to avoid size limits
      for (int i = 0; i < _chats.length; i++) {
        final chatJson = jsonEncode(_chats[i].toJson());
        await prefs.setString('${_chatsKey}_$i', chatJson);
      }
      
      // Save the count of chats
      await prefs.setInt(_chatIndexKey, _chats.length);
      
      // Save active chat ID
      if (_activeChat != null) {
        await prefs.setString(_activeChatKey, _activeChat!.id);
      } else {
        await prefs.remove(_activeChatKey);
      }
      
      developer.log('Saved ${_chats.length} chats to storage');
    } catch (e) {
      developer.log('Error saving chats: $e');
    }
  }
} 