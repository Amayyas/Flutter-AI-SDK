import 'package:logger/logger.dart' as logger_lib;

/// Logger for the Flutter AI SDK.
///
/// Provides consistent logging throughout the SDK.
///
/// Example:
/// ```dart
/// final logger = AILogger();
/// logger.debug('Debug message');
/// logger.info('Info message');
/// logger.error('Error message', error, stackTrace);
/// ```
class AILogger {
  /// Creates an [AILogger] with the given settings.
  AILogger({
    this.enabled = true,
    this.level = AILogLevel.info,
  }) : _logger = logger_lib.Logger(
          printer: logger_lib.PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 5,
            lineLength: 80,
            colors: true,
            printEmojis: true,
            dateTimeFormat: logger_lib.DateTimeFormat.onlyTimeAndSinceStart,
          ),
        );

  /// Whether logging is enabled.
  final bool enabled;

  /// The minimum log level.
  final AILogLevel level;

  /// The underlying logger.
  final logger_lib.Logger _logger;

  /// Logs a debug message.
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (!enabled || level.index > AILogLevel.debug.index) return;
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Logs an info message.
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (!enabled || level.index > AILogLevel.info.index) return;
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Logs a warning message.
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (!enabled || level.index > AILogLevel.warning.index) return;
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Logs an error message.
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (!enabled || level.index > AILogLevel.error.index) return;
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Logs a message at a specific level.
  void logMessage(
    AILogLevel logLevel,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    switch (logLevel) {
      case AILogLevel.debug:
        debug(message, error, stackTrace);
      case AILogLevel.info:
        info(message, error, stackTrace);
      case AILogLevel.warning:
        warning(message, error, stackTrace);
      case AILogLevel.error:
        this.error(message, error, stackTrace);
      case AILogLevel.none:
        break;
    }
  }
}

/// Log levels for the AI SDK.
enum AILogLevel {
  /// Debug level (most verbose).
  debug,

  /// Info level.
  info,

  /// Warning level.
  warning,

  /// Error level.
  error,

  /// No logging.
  none,
}

/// Global logger instance.
///
/// Can be replaced for custom logging.
AILogger aiLogger = AILogger();
