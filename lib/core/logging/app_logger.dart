import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Mixin that provides logging capabilities to any class.
///
/// Usage:
/// ```dart
/// class MyClass with LoggerMixin {
///   void doSomething() {
///     log.i('Info message');
///     log.w('Warning message');
///     log.e('Error message');
///     log.d('Debug message'); // Only logged in debug mode
///   }
/// }
/// ```
mixin LoggerMixin {
  AppLogger get log => AppLogger(runtimeType.toString());
}

/// Logger wrapper that uses the logger package with PrettyPrinter.
/// Debug logs are automatically disabled in release mode.
class AppLogger {
  final String className;
  late final Logger _logger;

  AppLogger(this.className) {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0, // Don't include call stack in normal logs
        errorMethodCount: 8, // Include call stack for errors
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
    );
  }

  /// Log info message
  void i(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.i('[$className] $message', error: error, stackTrace: stackTrace);
  }

  /// Log warning message
  void w(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.w('[$className] $message', error: error, stackTrace: stackTrace);
  }

  /// Log error message
  void e(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e('[$className] $message', error: error, stackTrace: stackTrace);
  }

  /// Log debug message (only in debug mode)
  void d(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.d('[$className] $message', error: error, stackTrace: stackTrace);
    }
  }
}
