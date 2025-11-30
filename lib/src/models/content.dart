import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:flutter_ai_sdk/src/models/enums.dart';

/// Base class for content in messages.
///
/// Content can be text, images, audio, documents, or tool calls.
/// This provides a type-safe way to handle multimodal content.
///
/// Example:
/// ```dart
/// final content = TextContent('Hello, world!');
/// final image = ImageContent.fromUrl('https://example.com/image.png');
/// ```
sealed class Content with EquatableMixin {
  /// Creates a [Content] with the given [type].
  const Content({required this.type});

  /// The type of this content.
  final ContentType type;

  /// Converts this content to a JSON-serializable map.
  Map<String, dynamic> toJson();

  @override
  List<Object?> get props => [type];
}

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

/// Image content.
///
/// Supports images from URLs, base64 data, or file bytes.
///
/// Example:
/// ```dart
/// // From URL
/// final image = ImageContent.fromUrl(
///   'https://example.com/image.png',
///   detail: ImageDetail.high,
/// );
///
/// // From bytes
/// final imageBytes = await File('image.png').readAsBytes();
/// final image = ImageContent.fromBytes(imageBytes, mimeType: 'image/png');
/// ```
final class ImageContent extends Content {
  /// Creates an [ImageContent] from a URL.
  const ImageContent.fromUrl(
    this.url, {
    this.detail = ImageDetail.auto,
  })  : data = null,
        mimeType = null,
        super(type: ContentType.image);

  /// Creates an [ImageContent] from base64 data.
  const ImageContent.fromBase64(
    String base64Data, {
    required String this.mimeType,
    this.detail = ImageDetail.auto,
  })  : url = null,
        data = base64Data,
        super(type: ContentType.image);

  /// Creates an [ImageContent] from bytes.
  ImageContent.fromBytes(
    Uint8List bytes, {
    required String this.mimeType,
    this.detail = ImageDetail.auto,
  })  : url = null,
        data = base64Encode(bytes),
        super(type: ContentType.image);

  /// The URL of the image (if from URL).
  final String? url;

  /// The base64-encoded image data (if from bytes).
  final String? data;

  /// The MIME type of the image (e.g., 'image/png').
  final String? mimeType;

  /// The detail level for analysis.
  final ImageDetail detail;

  /// Whether this image is from a URL.
  bool get isUrl => url != null;

  /// Whether this image is from data.
  bool get isData => data != null;

  @override
  Map<String, dynamic> toJson() {
    if (url != null) {
      return {
        'type': 'image_url',
        'image_url': {
          'url': url,
          'detail': detail.name,
        },
      };
    }
    return {
      'type': 'image_url',
      'image_url': {
        'url': 'data:$mimeType;base64,$data',
        'detail': detail.name,
      },
    };
  }

  @override
  List<Object?> get props => [type, url, data, mimeType, detail];

  @override
  String toString() => 'ImageContent(${url ?? "base64 data"}, detail: $detail)';
}

/// Audio content.
///
/// Supports audio from URLs or base64 data.
///
/// Example:
/// ```dart
/// final audio = AudioContent.fromUrl(
///   'https://example.com/audio.mp3',
///   mimeType: 'audio/mp3',
/// );
/// ```
final class AudioContent extends Content {
  /// Creates an [AudioContent] from a URL.
  const AudioContent.fromUrl(
    this.url, {
    required this.mimeType,
  })  : data = null,
        super(type: ContentType.audio);

  /// Creates an [AudioContent] from base64 data.
  const AudioContent.fromBase64(
    String base64Data, {
    required this.mimeType,
  })  : url = null,
        data = base64Data,
        super(type: ContentType.audio);

  /// Creates an [AudioContent] from bytes.
  AudioContent.fromBytes(
    Uint8List bytes, {
    required this.mimeType,
  })  : url = null,
        data = base64Encode(bytes),
        super(type: ContentType.audio);

  /// The URL of the audio (if from URL).
  final String? url;

  /// The base64-encoded audio data (if from bytes).
  final String? data;

  /// The MIME type of the audio (e.g., 'audio/mp3').
  final String mimeType;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'audio',
        'audio': {
          if (url != null) 'url': url,
          if (data != null) 'data': data,
          'mime_type': mimeType,
        },
      };

  @override
  List<Object?> get props => [type, url, data, mimeType];
}

/// Document content.
///
/// Supports documents (PDFs, etc.) from URLs or bytes.
///
/// Example:
/// ```dart
/// final doc = DocumentContent.fromUrl(
///   'https://example.com/document.pdf',
///   mimeType: 'application/pdf',
/// );
/// ```
final class DocumentContent extends Content {
  /// Creates a [DocumentContent] from a URL.
  const DocumentContent.fromUrl(
    this.url, {
    required this.mimeType,
    this.name,
  })  : data = null,
        super(type: ContentType.document);

  /// Creates a [DocumentContent] from base64 data.
  const DocumentContent.fromBase64(
    String base64Data, {
    required this.mimeType,
    this.name,
  })  : url = null,
        data = base64Data,
        super(type: ContentType.document);

  /// Creates a [DocumentContent] from bytes.
  DocumentContent.fromBytes(
    Uint8List bytes, {
    required this.mimeType,
    this.name,
  })  : url = null,
        data = base64Encode(bytes),
        super(type: ContentType.document);

  /// The URL of the document (if from URL).
  final String? url;

  /// The base64-encoded document data (if from bytes).
  final String? data;

  /// The MIME type of the document.
  final String mimeType;

  /// Optional name/filename for the document.
  final String? name;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'document',
        'document': {
          if (url != null) 'url': url,
          if (data != null) 'data': data,
          'mime_type': mimeType,
          if (name != null) 'name': name,
        },
      };

  @override
  List<Object?> get props => [type, url, data, mimeType, name];
}

/// Tool call content.
///
/// Represents a request from the model to call a tool/function.
///
/// Example:
/// ```dart
/// final toolCall = ToolCallContent(
///   id: 'call_abc123',
///   name: 'get_weather',
///   arguments: {'location': 'Paris', 'unit': 'celsius'},
/// );
/// ```
final class ToolCallContent extends Content {
  /// Creates a [ToolCallContent].
  const ToolCallContent({
    required this.id,
    required this.name,
    required this.arguments,
  }) : super(type: ContentType.toolCall);

  /// Unique identifier for this tool call.
  final String id;

  /// Name of the tool/function to call.
  final String name;

  /// Arguments to pass to the tool.
  final Map<String, dynamic> arguments;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'tool_call',
        'id': id,
        'name': name,
        'arguments': arguments,
      };

  @override
  List<Object?> get props => [type, id, name, arguments];

  @override
  String toString() => 'ToolCallContent($name, args: $arguments)';
}

/// Tool result content.
///
/// Contains the result of a tool/function call.
///
/// Example:
/// ```dart
/// final result = ToolResultContent(
///   toolCallId: 'call_abc123',
///   name: 'get_weather',
///   result: {'temperature': 22, 'condition': 'sunny'},
/// );
/// ```
final class ToolResultContent extends Content {
  /// Creates a [ToolResultContent].
  const ToolResultContent({
    required this.toolCallId,
    required this.name,
    required this.result,
    this.isError = false,
  }) : super(type: ContentType.toolResult);

  /// The ID of the tool call this is responding to.
  final String toolCallId;

  /// Name of the tool/function.
  final String name;

  /// The result of the tool call (can be any JSON-serializable value).
  final dynamic result;

  /// Whether this result represents an error.
  final bool isError;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'tool_result',
        'tool_call_id': toolCallId,
        'name': name,
        'result': result,
        'is_error': isError,
      };

  @override
  List<Object?> get props => [type, toolCallId, name, result, isError];

  @override
  String toString() => 'ToolResultContent($name: $result)';
}
