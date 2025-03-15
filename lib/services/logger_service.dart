import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class LoggerService {
  LogLevel _level = LogLevel.info;

  LoggerService({LogLevel logLevel = LogLevel.info}) {
    _level = logLevel;
  }

  Future<void> init({LogLevel logLevel = LogLevel.info}) async {
    _level = logLevel;
    debug('Logger initialized with level: ${_level.toString()}');
    return Future.value();
  }

  bool _shouldLog(LogLevel messageLevel) {
    return messageLevel.index >= _level.index;
  }

  void debug(String message, {String? tag, Map<String, dynamic>? data}) {
    if (_shouldLog(LogLevel.debug)) {
      _log('DEBUG', message, tag: tag, data: data);
    }
  }

  void info(String message, {String? tag, Map<String, dynamic>? data}) {
    if (_shouldLog(LogLevel.info)) {
      _log('INFO', message, tag: tag, data: data);
    }
  }

  void warning(String message, {String? tag, Map<String, dynamic>? data}) {
    if (_shouldLog(LogLevel.warning)) {
      _log('WARNING', message, tag: tag, data: data);
    }
  }

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
    Map<String, dynamic>? data,
  }) {
    if (_shouldLog(LogLevel.error)) {
      _log('ERROR', message, tag: tag, data: data);
      if (error != null) {
        debugPrint('Error details: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  void _log(
    String level,
    String message, {
    String? tag,
    Map<String, dynamic>? data,
  }) {
    final now = DateTime.now();
    final formattedDate =
        '${now.year}-${_pad(now.month)}-${_pad(now.day)} ${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}.${now.millisecond}';

    final tagString = tag != null ? '[$tag]' : '';
    final dataString = data != null ? ' Data: $data' : '';
    debugPrint('$formattedDate [$level]$tagString: $message$dataString');
  }

  String _pad(int number) {
    return number.toString().padLeft(2, '0');
  }
}
