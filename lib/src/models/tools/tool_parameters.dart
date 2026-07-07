import 'package:equatable/equatable.dart';

import 'package:flutter_ai_sdk/src/models/tools/tool_property.dart';

/// Parameters schema for a tool.
///
/// Follows JSON Schema format for defining tool parameters.
class ToolParameters with Equatable {
  /// Creates [ToolParameters].
  const ToolParameters({
    required this.properties,
    this.required = const [],
    this.additionalProperties = false,
  });

  /// Property definitions.
  final Map<String, ToolProperty> properties;

  /// List of required property names.
  final List<String> required;

  /// Whether additional properties are allowed.
  final bool additionalProperties;

  /// Converts to a JSON Schema map.
  Map<String, dynamic> toJson() => {
        'type': 'object',
        'properties': properties.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'required': required,
        'additionalProperties': additionalProperties,
      };

  @override
  List<Object?> get props => [properties, required, additionalProperties];
}
