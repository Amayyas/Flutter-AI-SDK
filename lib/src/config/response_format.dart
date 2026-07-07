import 'package:equatable/equatable.dart';

/// Response format configuration.
///
/// Controls the format of the model's output.
sealed class ResponseFormat with Equatable {
  /// Creates a [ResponseFormat].
  const ResponseFormat();

  /// Text response format (default).
  const factory ResponseFormat.text() = TextResponseFormat;

  /// JSON response format.
  const factory ResponseFormat.json({Map<String, dynamic>? schema}) =
      JsonResponseFormat;

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson();
}

/// Text response format.
final class TextResponseFormat extends ResponseFormat {
  /// Creates a [TextResponseFormat].
  const TextResponseFormat();

  @override
  Map<String, dynamic> toJson() => {'type': 'text'};

  @override
  List<Object?> get props => [];
}

/// JSON response format.
final class JsonResponseFormat extends ResponseFormat {
  /// Creates a [JsonResponseFormat].
  const JsonResponseFormat({this.schema});

  /// Optional JSON schema for structured output.
  final Map<String, dynamic>? schema;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'json_object',
        if (schema != null) 'schema': schema,
      };

  @override
  List<Object?> get props => [schema];
}
