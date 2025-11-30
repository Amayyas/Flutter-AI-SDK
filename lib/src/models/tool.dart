import 'package:equatable/equatable.dart';

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
class Tool with EquatableMixin {
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

/// Parameters schema for a tool.
///
/// Follows JSON Schema format for defining tool parameters.
class ToolParameters with EquatableMixin {
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

/// A property in a tool's parameter schema.
///
/// Represents a single parameter that a tool accepts.
sealed class ToolProperty with EquatableMixin {
  /// Creates a [ToolProperty].
  const ToolProperty({
    required this.type,
    this.description,
  });

  /// Creates a string property.
  factory ToolProperty.string({String? description}) =>
      StringToolProperty(description: description);

  /// Creates an integer property.
  factory ToolProperty.integer({String? description}) =>
      IntegerToolProperty(description: description);

  /// Creates a number (float) property.
  factory ToolProperty.number({String? description}) =>
      NumberToolProperty(description: description);

  /// Creates a boolean property.
  factory ToolProperty.boolean({String? description}) =>
      BooleanToolProperty(description: description);

  /// Creates an array property.
  factory ToolProperty.array({
    required ToolProperty items,
    String? description,
  }) =>
      ArrayToolProperty(items: items, description: description);

  /// Creates an object property.
  factory ToolProperty.object({
    required Map<String, ToolProperty> properties,
    List<String> required = const [],
    String? description,
  }) =>
      ObjectToolProperty(
        properties: properties,
        required: required,
        description: description,
      );

  /// Creates an enum property.
  factory ToolProperty.enumeration({
    required List<String> values,
    String? description,
  }) =>
      EnumToolProperty(values: values, description: description);

  /// The JSON Schema type.
  final String type;

  /// Description of the property.
  final String? description;

  /// Converts to a JSON Schema map.
  Map<String, dynamic> toJson();

  @override
  List<Object?> get props => [type, description];
}

/// String property.
final class StringToolProperty extends ToolProperty {
  /// Creates a [StringToolProperty].
  const StringToolProperty({super.description}) : super(type: 'string');

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        if (description != null) 'description': description,
      };
}

/// Integer property.
final class IntegerToolProperty extends ToolProperty {
  /// Creates an [IntegerToolProperty].
  const IntegerToolProperty({super.description}) : super(type: 'integer');

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        if (description != null) 'description': description,
      };
}

/// Number (float) property.
final class NumberToolProperty extends ToolProperty {
  /// Creates a [NumberToolProperty].
  const NumberToolProperty({super.description}) : super(type: 'number');

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        if (description != null) 'description': description,
      };
}

/// Boolean property.
final class BooleanToolProperty extends ToolProperty {
  /// Creates a [BooleanToolProperty].
  const BooleanToolProperty({super.description}) : super(type: 'boolean');

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        if (description != null) 'description': description,
      };
}

/// Array property.
final class ArrayToolProperty extends ToolProperty {
  /// Creates an [ArrayToolProperty].
  const ArrayToolProperty({
    required this.items,
    super.description,
  }) : super(type: 'array');

  /// The type of items in the array.
  final ToolProperty items;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'items': items.toJson(),
        if (description != null) 'description': description,
      };

  @override
  List<Object?> get props => [...super.props, items];
}

/// Object property.
final class ObjectToolProperty extends ToolProperty {
  /// Creates an [ObjectToolProperty].
  const ObjectToolProperty({
    required this.properties,
    this.required = const [],
    super.description,
  }) : super(type: 'object');

  /// Property definitions.
  final Map<String, ToolProperty> properties;

  /// Required properties.
  final List<String> required;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'properties': properties.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'required': required,
        if (description != null) 'description': description,
      };

  @override
  List<Object?> get props => [...super.props, properties, required];
}

/// Enum property.
final class EnumToolProperty extends ToolProperty {
  /// Creates an [EnumToolProperty].
  const EnumToolProperty({
    required this.values,
    super.description,
  }) : super(type: 'string');

  /// Allowed values.
  final List<String> values;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'enum': values,
        if (description != null) 'description': description,
      };

  @override
  List<Object?> get props => [...super.props, values];
}

/// Configuration for tool choice behavior.
///
/// Controls how the model uses tools.
sealed class ToolChoice with EquatableMixin {
  /// Creates a [ToolChoice].
  const ToolChoice();

  /// Let the model decide whether to use tools.
  const factory ToolChoice.auto() = AutoToolChoice;

  /// Model must not use any tools.
  const factory ToolChoice.none() = NoneToolChoice;

  /// Model must use a specific tool.
  const factory ToolChoice.tool(String name) = SpecificToolChoice;

  /// Model must use any tool.
  const factory ToolChoice.required() = RequiredToolChoice;

  /// Converts to provider-specific format.
  dynamic toProviderFormat(AIProviderType provider);
}

/// Enum for provider types (internal use).
enum AIProviderType { openai, anthropic, googleAI }

/// Auto tool choice.
final class AutoToolChoice extends ToolChoice {
  /// Creates an [AutoToolChoice].
  const AutoToolChoice();

  @override
  dynamic toProviderFormat(AIProviderType provider) => switch (provider) {
        AIProviderType.openai => 'auto',
        AIProviderType.anthropic => {'type': 'auto'},
        AIProviderType.googleAI => 'AUTO',
      };

  @override
  List<Object?> get props => [];
}

/// None tool choice.
final class NoneToolChoice extends ToolChoice {
  /// Creates a [NoneToolChoice].
  const NoneToolChoice();

  @override
  dynamic toProviderFormat(AIProviderType provider) => switch (provider) {
        AIProviderType.openai => 'none',
        AIProviderType.anthropic => {'type': 'none'},
        AIProviderType.googleAI => 'NONE',
      };

  @override
  List<Object?> get props => [];
}

/// Required tool choice.
final class RequiredToolChoice extends ToolChoice {
  /// Creates a [RequiredToolChoice].
  const RequiredToolChoice();

  @override
  dynamic toProviderFormat(AIProviderType provider) => switch (provider) {
        AIProviderType.openai => 'required',
        AIProviderType.anthropic => {'type': 'any'},
        AIProviderType.googleAI => 'ANY',
      };

  @override
  List<Object?> get props => [];
}

/// Specific tool choice.
final class SpecificToolChoice extends ToolChoice {
  /// Creates a [SpecificToolChoice].
  const SpecificToolChoice(this.name);

  /// The tool name.
  final String name;

  @override
  dynamic toProviderFormat(AIProviderType provider) => switch (provider) {
        AIProviderType.openai => {
            'type': 'function',
            'function': {'name': name},
          },
        AIProviderType.anthropic => {'type': 'tool', 'name': name},
        AIProviderType.googleAI => name,
      };

  @override
  List<Object?> get props => [name];
}
