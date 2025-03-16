# AI Chat App

A Flutter application that enables communication with various AI providers including OpenAI (ChatGPT), Anthropic (Claude), and Google (Gemini).

## Features

- Modern chat interface with familiar messaging UI
- Support for multiple AI providers:
  - OpenAI (GPT-3.5, GPT-4)
  - Anthropic (Claude)
  - Google (Gemini)
- Dark and light theme support
- Comprehensive chat history management
- Markdown rendering for AI responses
- Code syntax highlighting
- Token usage tracking and cost estimation
- Cross-platform support (Web, iOS, Android, macOS, Windows, Linux)
- Keyboard shortcuts for improved productivity

## Getting Started

### Prerequisites

- Flutter SDK installed (version 3.7.2 or higher)
- API keys for the AI providers you want to use

### Installation

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Create a `.env` file in the root directory or `assets/.env` with the following content:

```
# API Keys for different AI providers
OPENAI_API_KEY=your_openai_api_key_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here
GEMINI_API_KEY=your_gemini_api_key_here

# API Endpoints
OPENAI_API_ENDPOINT=https://api.openai.com/v1/chat/completions
ANTHROPIC_API_ENDPOINT=https://api.anthropic.com/v1/messages
# Gemini uses the official Google SDK - no endpoint needed
```

4. Replace the placeholder API keys with your actual keys
5. Run the app with `flutter run`

You can also enter API keys directly in the app's settings page.

### Keyboard Shortcuts

The app supports various keyboard shortcuts for improved productivity:

- Enter: Send message
- Cmd+B (or Ctrl+B on Windows/Linux): Toggle sidebar
- Cmd+I (or Ctrl+I on Windows/Linux): Focus on message input
- Shift+Enter: Insert new line in message
- Cmd+Shift+N (or Ctrl+Shift+N on Windows/Linux): Create a new chat

## Project Structure

```
lib/
├── models/           # Data models for chats, messages, token usage
├── providers/        # State management with Provider
├── screens/          # UI screens (home, chat history, settings)
├── services/         # AI provider integrations (OpenAI, Anthropic, Gemini)
├── utils/            # Utility functions
├── widgets/          # Reusable UI components
└── router/           # App navigation and routing
```

### Key Components

#### Models

- `chat.dart`: Defines chat data structures
- `message.dart`: Message model for chat conversations
- `token_usage.dart`: Token usage tracking and cost estimation

#### Services

- `openai_service.dart`: Integration with OpenAI APIs
- `anthropic_service.dart`: Integration with Anthropic APIs
- `gemini_service.dart`: Integration with Google Gemini APIs
- `logger_service.dart`: Logging functionality
- `message_renderer.dart`: Rendering chat messages

#### Providers

- `chat_provider.dart`: Manages chat state and interactions
- `theme_provider.dart`: Handles app theme (dark/light mode)

#### Screens

- `home_screen.dart`: Main chat interface
- `chat_history_screen.dart`: View and manage chat history
- `settings_screen.dart`: Configure app settings and API keys

## Usage

1. Open the app
2. Create a new chat by clicking the "+ New Chat" button
3. Select an AI provider and model
4. Type your message and hit send
5. View the AI's response with markdown and code highlighting support

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- [Flutter](https://flutter.dev/)
- [OpenAI API](https://platform.openai.com/)
- [Anthropic API](https://docs.anthropic.com/claude/reference/getting-started-with-the-api)
- [Google Gemini API](https://ai.google.dev/)
- [Provider package](https://pub.dev/packages/provider) for state management
- [Flutter Markdown](https://pub.dev/packages/flutter_markdown) for rendering markdown content
- [Flutter Chat UI](https://pub.dev/packages/flutter_chat_ui) for chat interface components
