part of 'content.dart';

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
