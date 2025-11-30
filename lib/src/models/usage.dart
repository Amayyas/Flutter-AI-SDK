import 'package:equatable/equatable.dart';

/// Token usage statistics for an AI request.
///
/// Contains information about the number of tokens used in
/// the prompt and completion, useful for cost estimation.
///
/// Example:
/// ```dart
/// final response = await ai.chat('Hello');
/// print('Prompt tokens: ${response.usage?.promptTokens}');
/// print('Completion tokens: ${response.usage?.completionTokens}');
/// print('Total: ${response.usage?.totalTokens}');
/// ```
class Usage with EquatableMixin {
  /// Creates a [Usage] instance.
  const Usage({
    required this.promptTokens,
    required this.completionTokens,
    this.cachedTokens,
  });

  /// Number of tokens in the prompt.
  final int promptTokens;

  /// Number of tokens in the completion.
  final int completionTokens;

  /// Number of tokens served from cache (if applicable).
  final int? cachedTokens;

  /// Total number of tokens (prompt + completion).
  int get totalTokens => promptTokens + completionTokens;

  /// Creates a [Usage] from a JSON map.
  factory Usage.fromJson(Map<String, dynamic> json) => Usage(
        promptTokens: json['prompt_tokens'] as int? ?? 0,
        completionTokens: json['completion_tokens'] as int? ?? 0,
        cachedTokens: json['cached_tokens'] as int?,
      );

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': totalTokens,
        if (cachedTokens != null) 'cached_tokens': cachedTokens,
      };

  /// Creates a copy with updated fields.
  Usage copyWith({
    int? promptTokens,
    int? completionTokens,
    int? cachedTokens,
  }) =>
      Usage(
        promptTokens: promptTokens ?? this.promptTokens,
        completionTokens: completionTokens ?? this.completionTokens,
        cachedTokens: cachedTokens ?? this.cachedTokens,
      );

  /// Adds another usage to this one.
  Usage operator +(Usage other) => Usage(
        promptTokens: promptTokens + other.promptTokens,
        completionTokens: completionTokens + other.completionTokens,
        cachedTokens: (cachedTokens ?? 0) + (other.cachedTokens ?? 0),
      );

  @override
  List<Object?> get props => [promptTokens, completionTokens, cachedTokens];

  @override
  String toString() =>
      'Usage(prompt: $promptTokens, completion: $completionTokens, total: $totalTokens)';
}

/// Detailed cost information for an AI request.
///
/// Provides estimated costs based on token usage and model pricing.
class CostInfo with EquatableMixin {
  /// Creates a [CostInfo] instance.
  const CostInfo({
    required this.promptCost,
    required this.completionCost,
    this.currency = 'USD',
  });

  /// Cost for prompt tokens.
  final double promptCost;

  /// Cost for completion tokens.
  final double completionCost;

  /// Currency code (default: USD).
  final String currency;

  /// Total cost.
  double get totalCost => promptCost + completionCost;

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
        'prompt_cost': promptCost,
        'completion_cost': completionCost,
        'total_cost': totalCost,
        'currency': currency,
      };

  @override
  List<Object?> get props => [promptCost, completionCost, currency];

  @override
  String toString() => 'CostInfo(\$$totalCost $currency)';
}
