# Logger Service Documentation

This document explains how to use the standardized logging service in your application.

## Overview

The `LoggerService` provides a consistent way to log messages across your application. It supports:

- Multiple log levels (debug, info, warning, error)
- Configurable output destinations (console, file)
- Tagged logs for better categorization
- Additional contextual data in logs
- Error and stack trace logging

## Setup

The logger service is initialized in the `main.dart` file, but you can also initialize it in other parts of your application if needed.

### Basic Initialization

```dart
final logger = LoggerService();
await logger.init(
  logLevel: LogLevel.debug, // Set minimum log level
  logToConsole: true,       // Enable console logging
  logToFile: false,         // Enable/disable file logging
  logDirectory: 'logs',     // Directory for log files if file logging is enabled
);
```

## Usage Examples

### Basic Logging

```dart
// Get the logger instance (singleton)
final logger = LoggerService();

// Log messages at different levels
logger.debug('This is a debug message');
logger.info('This is an info message');
logger.warning('This is a warning message');
logger.error('This is an error message');
```

### Tagged Logging

Tags help categorize logs and make filtering easier:

```dart
logger.info('User logged in', tag: 'AUTH');
logger.error('Failed to load data', tag: 'API');
```

### Including Additional Data

You can include structured data with your logs:

```dart
logger.info(
  'User profile updated',
  tag: 'PROFILE',
  data: {'userId': '12345', 'updatedFields': ['name', 'email']},
);
```

### Logging Errors with Stack Traces

```dart
try {
  // Some code that might throw an error
  final result = someRiskyOperation();
} catch (e, stackTrace) {
  logger.error(
    'An error occurred during operation',
    tag: 'OPERATION',
    error: e,
    stackTrace: stackTrace,
  );
}
```

### Changing Log Level at Runtime

You can adjust the log level at runtime to control verbosity:

```dart
// Set to warning level - debug and info logs will be suppressed
logger.setLogLevel(LogLevel.warning);

// These will not be logged
logger.debug('Debug message');
logger.info('Info message');

// These will be logged
logger.warning('Warning message');
logger.error('Error message');
```

### File Logging

You can enable or disable file logging at runtime:

```dart
// Enable file logging
await logger.setFileLogging(true, directory: 'app_logs');

// Disable file logging
await logger.setFileLogging(false);
```

## Best Practices

1. **Use appropriate log levels**:

   - `debug`: Detailed information for debugging
   - `info`: General information about application flow
   - `warning`: Potential issues that don't prevent the app from working
   - `error`: Errors that affect functionality

2. **Use tags consistently** to categorize logs (e.g., 'AUTH', 'API', 'DB', 'UI')

3. **Include contextual data** to make logs more useful for debugging

4. **Log exceptions with stack traces** to help diagnose issues

5. **Don't log sensitive information** like passwords or tokens

## Log Format

Logs are formatted as follows:

```
YYYY-MM-DD HH:MM:SS.SSS [LEVEL][TAG]: Message - {Additional Data}
```

Example:

```
2023-03-15 14:30:45.123 [INFO][AUTH]: User logged in - {userId: 12345}
```
