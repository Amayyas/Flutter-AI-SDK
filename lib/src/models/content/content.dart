import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:flutter_ai_sdk/src/models/enums.dart';

part 'audio_content.dart';
part 'document_content.dart';
part 'image_content.dart';
part 'text_content.dart';
part 'tool_call_content.dart';
part 'tool_result_content.dart';

/// Base class for content in messages.
///
/// Content can be text, images, audio, documents, or tool calls.
/// This provides a type-safe way to handle multimodal content.
///
/// The concrete content types live in this library's part files —
/// one file per content type — because a sealed hierarchy must be
/// declared within a single library.
///
/// Example:
/// ```dart
/// final content = TextContent('Hello, world!');
/// final image = ImageContent.fromUrl('https://example.com/image.png');
/// ```
sealed class Content with Equatable {
  /// Creates a [Content] with the given [type].
  const Content({required this.type});

  /// The type of this content.
  final ContentType type;

  /// Converts this content to a JSON-serializable map.
  Map<String, dynamic> toJson();

  @override
  List<Object?> get props => [type];
}
