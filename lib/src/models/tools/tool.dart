import 'package:equatable/equatable.dart';

import 'package:flutter_ai_sdk/src/models/tools/tool_parameters.dart';

/// Definition of a tool/function that can be called by the AI.
///
/// Tools allow the AI to interact with external systems or
/// perform specific actions.
///
/// Example:
/// ```dart
/// final weatherTool = Tool(
///   name: 'get_weather',
///   description: 'Get the current weather for a location',
///   parameters: ToolParameters(
///     properties: {
///       'location': ToolProperty.string(
///         description: 'The city and country, e.g., "Paris, France"',
///       ),
///       'unit': ToolProperty.enumeration(
///         description: 'Temperature unit',
///         values: ['celsius', 'fahrenheit'],
///       ),
///     },
///     required: ['location'],
///   ),
/// );
/// ```
class Tool with Equatable {
  /// Creates a [Tool] definition.
  const Tool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  /// The name of the tool (used in function calls).
  final String name;

  /// Description of what the tool does.
  final String description;

  /// The parameters accepted by this tool.
  final ToolParameters parameters;

  /// Converts to OpenAI function format.
  Map<String, dynamic> toOpenAIFormat() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters.toJson(),
        },
      };

  /// Converts to Anthropic tool format.
  Map<String, dynamic> toAnthropicFormat() => {
        'name': name,
        'description': description,
        'input_schema': parameters.toJson(),
      };

  /// Converts to Google AI function format.
  Map<String, dynamic> toGoogleAIFormat() => {
        'name': name,
        'description': description,
        'parameters': parameters.toJson(),
      };

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'parameters': parameters.toJson(),
      };

  @override
  List<Object?> get props => [name, description, parameters];

  @override
  String toString() => 'Tool($name)';
}
