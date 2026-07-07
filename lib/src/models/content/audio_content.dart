part of 'content.dart';

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
