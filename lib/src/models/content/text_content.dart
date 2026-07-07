part of 'content.dart';

/// Text content.
///
/// Simple text content for messages.
///
/// Example:
/// ```dart
/// final text = TextContent('Hello, how are you?');
/// ```
final class TextContent extends Content {
  /// Creates a [TextContent] with the given [text].
  const TextContent(this.text) : super(type: ContentType.text);

  /// The text content.
  final String text;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'text',
        'text': text,
      };

  @override
  List<Object?> get props => [type, text];

  @override
  String toString() => 'TextContent($text)';
}
