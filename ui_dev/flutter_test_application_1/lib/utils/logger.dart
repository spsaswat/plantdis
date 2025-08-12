import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

// This is our global logger instance
final logger = Logger(
  // The printer determines the format of the log output.
  printer: PrettyPrinter(
    methodCount: 1, // Number of method calls to be displayed.
    errorMethodCount: 8, // Number of method calls if stacktrace is provided.
    lineLength: 120, // Width of the log print.
    colors: true, // Use colors for different log levels.
    printEmojis: true, // Print an emoji for each log message.
    dateTimeFormat:
        DateTimeFormat.onlyTime, // Should each log print contain a timestamp.
  ),
  // The filter decides which logs should be sent to the output.
  filter: ProductionFilter(),
  // The output sends the log to a destination (e.g., console, file, network).
  output: kDebugMode ? ConsoleOutput() : ProductionLogOutput(),
);

// Custom filter to control log levels for different build modes.
class ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // In debug mode, we want to see all logs.
    if (kDebugMode) {
      return true;
    }
    // In release mode, we only want to see logs of warning level or higher.
    // This helps to reduce noise and performance impact on user devices.
    return event.level.index >= Level.warning.index;
  }
}

// Custom output to handle logs in a production environment.
class ProductionLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // In a real production app, this is where you would send logs
    // to a remote logging service like Sentry, Firebase Crashlytics, or Datadog.
    // This allows you to monitor and debug issues from real users.

    // TODO: Integrate with remote logging service.
    // Example for Sentry:
    // if (event.level.index >= Level.error.index) {
    //   Sentry.captureException(
    //     event.origin.error,
    //     stackTrace: event.origin.stackTrace,
    //   );
    // }

    // For now, we can just print them, but ideally, we'd send them remotely.
    for (var line in event.lines) {
      print(line);
    }
  }
}

// A simple setup function to be called in main.dart
void setupLogging() {
  logger.i("Logger initialized for Plant Disease Doctor App.");
  logger.d("App running in ${kDebugMode ? 'DEBUG' : 'RELEASE'} mode.");
}
