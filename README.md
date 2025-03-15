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

# Keyboard Manager for Web Applications

A lightweight, flexible keyboard management system for web applications. This module allows you to easily manage keyboard shortcuts, key combinations, and keyboard event handling throughout your application.

## Features

- Register and handle keyboard shortcuts with callbacks
- Support for modifier keys (Ctrl, Alt, Shift, Meta/Command)
- Enable/disable specific bindings or all bindings at once
- Focus-aware: Configure shortcuts to work only when specific elements are or aren't focused
- TypeScript support with full type definitions
- Smart context detection for input fields

## Installation

For now, simply copy the `keyboardManager.ts` file into your project. In the future, this could be packaged as an npm module.

### TypeScript Compilation

If you're using TypeScript, make sure to compile the module to JavaScript:

```bash
tsc keyboardManager.ts
```

## Basic Usage

```typescript
import keyboardManager from "./keyboardManager";

// Register a simple key shortcut
keyboardManager.register({
  key: "Escape",
  description: "Close modal",
  callback: () => {
    closeModal();
  },
});

// Register a key combination with modifiers
keyboardManager.register({
  key: "s",
  ctrl: true,
  description: "Save document (Ctrl+S)",
  callback: (event) => {
    saveDocument();
  },
});

// Clean up when your component is destroyed
function cleanup() {
  keyboardManager.destroy();
}
```

## Advanced Usage Examples

### Enter to Send Message in Input Fields

```typescript
// Register Enter key to send messages from input fields
keyboardManager.register({
  key: "Enter",
  description: "Send message when typing in input field",
  allowInInput: true, // Important: allow this shortcut to work in input fields
  callback: (event) => {
    // Get the active input element
    const activeElement = document.activeElement;

    // Only proceed if it's an input field and has text
    if (
      activeElement &&
      (activeElement instanceof HTMLInputElement ||
        activeElement instanceof HTMLTextAreaElement) &&
      (activeElement as HTMLInputElement | HTMLTextAreaElement).value.trim() !==
        ""
    ) {
      // Get the message from the input field
      const message = (activeElement as HTMLInputElement | HTMLTextAreaElement)
        .value;

      // Send the message (your implementation here)
      sendMessage(message);

      // Clear the input field
      (activeElement as HTMLInputElement | HTMLTextAreaElement).value = "";

      // Prevent the default Enter behavior (adding a new line in textarea)
      event.preventDefault();
    }
  },
});
```

### Toggle Sidebar with Cmd+B

```typescript
// Register Cmd+B to toggle sidebar
keyboardManager.register({
  key: "b",
  meta: true, // Command key on Mac, Windows/Super key on Windows/Linux
  description: "Toggle sidebar (Cmd+B)",
  callback: (event) => {
    const sidebar = document.getElementById("sidebar");
    if (sidebar) {
      sidebar.style.display =
        sidebar.style.display === "none" ? "block" : "none";
    }
  },
});
```

## API Reference

### KeyBinding Options

| Property         | Type       | Description                                               | Default        |
| ---------------- | ---------- | --------------------------------------------------------- | -------------- |
| `key`            | `string`   | The key value (e.g., 'a', 'Enter', 'ArrowUp')             | (required)     |
| `callback`       | `Function` | Function to call when key is pressed                      | (required)     |
| `description`    | `string`   | Description for this binding                              | `undefined`    |
| `ctrl`           | `boolean`  | Whether Ctrl key should be pressed                        | `false`        |
| `alt`            | `boolean`  | Whether Alt key should be pressed                         | `false`        |
| `shift`          | `boolean`  | Whether Shift key should be pressed                       | `false`        |
| `meta`           | `boolean`  | Whether Meta/Command key should be pressed                | `false`        |
| `preventDefault` | `boolean`  | Whether to prevent default browser behavior               | `true`         |
| `enabled`        | `boolean`  | Whether this binding is currently enabled                 | `true`         |
| `allowInInput`   | `boolean`  | Whether to trigger even when an input/textarea is focused | `false`        |
| `id`             | `string`   | Optional identifier for this binding                      | Auto-generated |

### Methods

#### `register(binding: KeyBinding): string`

Registers a new key binding and returns its ID.

#### `unregister(id: string): boolean`

Unregisters a key binding by its ID. Returns `true` if successful.

#### `setBindingEnabled(id: string, enabled: boolean): boolean`

Enables or disables a specific binding. Returns `true` if successful.

#### `setEnabled(enabled: boolean): void`

Enables or disables all keyboard bindings.

#### `getBindings(): KeyBinding[]`

Returns all registered keyboard bindings.

#### `destroy(): void`

Cleans up event listeners. Call this when you no longer need the keyboard manager.

## Demo

Open the `index.html` file in a browser to see a demonstration of the keyboard manager in action. The demo includes examples of:

- Basic keyboard shortcuts (Escape, Ctrl+S, Ctrl+Z)
- Special shortcuts that work in input fields (F1, Enter to send)
- Modifier key combinations (Cmd+B to toggle sidebar)
- Enabling/disabling shortcuts

## Browser Support

This module should work in all modern browsers that support ES6 features.

## License

MIT
