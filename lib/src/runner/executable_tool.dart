import 'dart:async';

import 'package:flutter_ai_sdk/src/models/models.dart';

/// Signature for a function that executes a tool call.
///
/// Receives the arguments produced by the model and returns the tool
/// result (any JSON-serializable value). May be synchronous or async.
typedef ToolExecutor = FutureOr<dynamic> Function(
  Map<String, dynamic> arguments,
);

/// A tool definition paired with the code that executes it.
///
/// Used by `ToolRunner` to run the full agentic loop automatically.
///
/// Example:
/// ```dart
/// final weather = ExecutableTool(
///   definition: Tool(
///     name: 'get_weather',
///     description: 'Get the current weather for a city',
///     parameters: ToolParameters(
///       properties: {'city': ToolProperty.string(description: 'City name')},
///       required: ['city'],
///     ),
///   ),
///   executor: (args) async => fetchWeather(args['city'] as String),
/// );
/// ```
class ExecutableTool {
  /// Creates an [ExecutableTool].
  const ExecutableTool({
    required this.definition,
    required this.executor,
  });

  /// The tool definition sent to the model.
  final Tool definition;

  /// The function invoked when the model calls this tool.
  final ToolExecutor executor;

  /// The tool name (from the definition).
  String get name => definition.name;
}
