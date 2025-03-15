# AI Chat App

A Flutter app that allows you to chat with various AI providers like OpenAI (ChatGPT), Anthropic (Claude), and Google (Gemini).

## Features

- Chat interface with familiar messaging UI
- Support for multiple AI providers:
  - OpenAI (GPT-3.5, GPT-4)
  - Anthropic (Claude)
  - Google (Gemini)
- Dark mode support
- Chat history management
- Markdown rendering for AI responses
- Code highlighting

## Getting Started

### Prerequisites

- Flutter SDK installed (version 3.7.2 or higher)
- API keys for the AI providers you want to use

### Installation

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Create a `.env` file in the root directory with the following content:

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

You can also enter API keys in the app's settings page.

### Folder Structure

```
lib/
├── models/           # Data models
├── providers/        # State management
├── screens/          # App screens
├── services/         # API services
├── utils/            # Utilities
└── widgets/          # Reusable UI components
```

## Usage

1. Open the app
2. Create a new chat by clicking the "+ New Chat" button
3. Select an AI provider and model
4. Type your message and hit send
5. View the AI's response

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- [Flutter](https://flutter.dev/)
- [OpenAI API](https://platform.openai.com/)
- [Anthropic API](https://docs.anthropic.com/claude/reference/getting-started-with-the-api)
- [Google Gemini API](https://ai.google.dev/)
