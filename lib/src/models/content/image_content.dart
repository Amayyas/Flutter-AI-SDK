part of 'content.dart';

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
