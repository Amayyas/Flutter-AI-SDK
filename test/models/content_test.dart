import 'dart:typed_data';

import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('Content', () {
    group('TextContent', () {
      test('creates with text', () {
        const content = TextContent('Hello world');
        expect(content.text, 'Hello world');
        expect(content.type, ContentType.text);
      });

      test('equality', () {
        const c1 = TextContent('Hello');
        const c2 = TextContent('Hello');
        const c3 = TextContent('World');

        expect(c1, equals(c2));
        expect(c1, isNot(equals(c3)));
      });

      test('toJson returns correct structure', () {
        const content = TextContent('Test text');
        final json = content.toJson();

        expect(json['type'], 'text');
        expect(json['text'], 'Test text');
      });

      test('toString returns readable representation', () {
        const content = TextContent('Hello');
        expect(content.toString(), contains('Hello'));
      });
    });

    group('ImageContent', () {
      test('creates from URL', () {
        const content = ImageContent.fromUrl(
          'https://example.com/image.jpg',
          detail: ImageDetail.high,
        );

        expect(content.url, 'https://example.com/image.jpg');
        expect(content.detail, ImageDetail.high);
        expect(content.type, ContentType.image);
        expect(content.data, isNull);
        expect(content.mimeType, isNull);
      });

      test('creates from base64', () {
        const content = ImageContent.fromBase64(
          'base64encodeddata',
          mimeType: 'image/png',
        );

        expect(content.data, 'base64encodeddata');
        expect(content.mimeType, 'image/png');
        expect(content.url, isNull);
      });

      test('fromBytes creates base64 encoded content', () {
        final bytes =
            Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]); // PNG header
        final content = ImageContent.fromBytes(
          bytes,
          mimeType: 'image/png',
        );

        expect(content.data, isNotNull);
        expect(content.mimeType, 'image/png');
      });

      test('isUrl returns true for URL-based images', () {
        const content = ImageContent.fromUrl('https://example.com/img.jpg');
        expect(content.isUrl, isTrue);
        expect(content.isData, isFalse);
      });

      test('isData returns true for base64-based images', () {
        const content = ImageContent.fromBase64('data', mimeType: 'image/png');
        expect(content.isData, isTrue);
        expect(content.isUrl, isFalse);
      });

      test('toJson for URL-based image', () {
        const content = ImageContent.fromUrl(
          'https://example.com/test.jpg',
          detail: ImageDetail.low,
        );
        final json = content.toJson();

        expect(json['type'], 'image_url');
        expect(json['image_url']['url'], 'https://example.com/test.jpg');
        expect(json['image_url']['detail'], 'low');
      });

      test('toJson for base64-based image', () {
        const content = ImageContent.fromBase64(
          'testdata',
          mimeType: 'image/jpeg',
        );
        final json = content.toJson();

        expect(json['type'], 'image_url');
        expect(json['image_url']['url'], contains('data:image/jpeg;base64,'));
      });

      test('default detail is auto', () {
        const content = ImageContent.fromUrl('https://example.com/img.jpg');
        expect(content.detail, ImageDetail.auto);
      });

      test('equality for URL-based images', () {
        const c1 = ImageContent.fromUrl('https://example.com/img.jpg');
        const c2 = ImageContent.fromUrl('https://example.com/img.jpg');
        const c3 = ImageContent.fromUrl('https://example.com/other.jpg');

        expect(c1, equals(c2));
        expect(c1, isNot(equals(c3)));
      });

      test('toString includes URL or data indicator', () {
        const urlContent = ImageContent.fromUrl('https://example.com/img.jpg');
        const dataContent =
            ImageContent.fromBase64('data', mimeType: 'image/png');

        expect(urlContent.toString(), contains('https://example.com/img.jpg'));
        expect(dataContent.toString(), contains('base64'));
      });
    });

    group('AudioContent', () {
      test('creates from URL', () {
        const content = AudioContent.fromUrl(
          'https://example.com/audio.mp3',
          mimeType: 'audio/mpeg',
        );

        expect(content.url, 'https://example.com/audio.mp3');
        expect(content.type, ContentType.audio);
        expect(content.mimeType, 'audio/mpeg');
      });

      test('creates from base64', () {
        const content = AudioContent.fromBase64(
          'audiobase64data',
          mimeType: 'audio/wav',
        );

        expect(content.data, 'audiobase64data');
        expect(content.mimeType, 'audio/wav');
        expect(content.url, isNull);
      });

      test('creates from bytes', () {
        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        final content = AudioContent.fromBytes(bytes, mimeType: 'audio/wav');

        expect(content.data, isNotNull);
        expect(content.mimeType, 'audio/wav');
      });

      test('toJson returns correct structure', () {
        const content = AudioContent.fromUrl(
          'https://example.com/test.mp3',
          mimeType: 'audio/mpeg',
        );
        final json = content.toJson();

        expect(json['type'], 'audio');
        expect(json['audio']['url'], 'https://example.com/test.mp3');
        expect(json['audio']['mime_type'], 'audio/mpeg');
      });

      test('equality', () {
        const c1 = AudioContent.fromUrl('https://example.com/a.mp3',
            mimeType: 'audio/mpeg');
        const c2 = AudioContent.fromUrl('https://example.com/a.mp3',
            mimeType: 'audio/mpeg');
        const c3 = AudioContent.fromUrl('https://example.com/b.mp3',
            mimeType: 'audio/mpeg');

        expect(c1, equals(c2));
        expect(c1, isNot(equals(c3)));
      });
    });

    group('DocumentContent', () {
      test('creates from URL', () {
        const content = DocumentContent.fromUrl(
          'https://example.com/doc.pdf',
          mimeType: 'application/pdf',
          name: 'document.pdf',
        );

        expect(content.url, 'https://example.com/doc.pdf');
        expect(content.mimeType, 'application/pdf');
        expect(content.name, 'document.pdf');
        expect(content.type, ContentType.document);
      });

      test('creates from base64', () {
        const content = DocumentContent.fromBase64(
          'base64pdfdata',
          mimeType: 'application/pdf',
          name: 'document.pdf',
        );

        expect(content.data, 'base64pdfdata');
        expect(content.mimeType, 'application/pdf');
        expect(content.name, 'document.pdf');
      });

      test('creates from bytes', () {
        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        final content = DocumentContent.fromBytes(
          bytes,
          mimeType: 'application/pdf',
        );

        expect(content.data, isNotNull);
        expect(content.mimeType, 'application/pdf');
      });

      test('toJson returns correct structure', () {
        const content = DocumentContent.fromBase64(
          'testdata',
          mimeType: 'application/pdf',
          name: 'test.pdf',
        );
        final json = content.toJson();

        expect(json['type'], 'document');
        expect(json['document']['data'], 'testdata');
        expect(json['document']['mime_type'], 'application/pdf');
        expect(json['document']['name'], 'test.pdf');
      });

      test('equality', () {
        const c1 =
            DocumentContent.fromBase64('data', mimeType: 'application/pdf');
        const c2 =
            DocumentContent.fromBase64('data', mimeType: 'application/pdf');
        const c3 =
            DocumentContent.fromBase64('other', mimeType: 'application/pdf');

        expect(c1, equals(c2));
        expect(c1, isNot(equals(c3)));
      });
    });

    group('ToolCallContent', () {
      test('creates with all properties', () {
        const content = ToolCallContent(
          id: 'call_123',
          name: 'get_weather',
          arguments: {'city': 'Paris'},
        );

        expect(content.id, 'call_123');
        expect(content.name, 'get_weather');
        expect(content.arguments, {'city': 'Paris'});
        expect(content.type, ContentType.toolCall);
      });

      test('toJson returns correct structure', () {
        const content = ToolCallContent(
          id: '1',
          name: 'test',
          arguments: {'key': 'value'},
        );
        final json = content.toJson();

        expect(json['type'], 'tool_call');
        expect(json['id'], '1');
        expect(json['name'], 'test');
        expect(json['arguments'], {'key': 'value'});
      });

      test('equality', () {
        const c1 = ToolCallContent(id: '1', name: 'test', arguments: {});
        const c2 = ToolCallContent(id: '1', name: 'test', arguments: {});
        const c3 = ToolCallContent(id: '2', name: 'test', arguments: {});

        expect(c1, equals(c2));
        expect(c1, isNot(equals(c3)));
      });

      test('toString includes name and arguments', () {
        const content = ToolCallContent(
          id: '1',
          name: 'get_weather',
          arguments: {'city': 'Paris'},
        );
        expect(content.toString(), contains('get_weather'));
        expect(content.toString(), contains('city'));
      });
    });

    group('ToolResultContent', () {
      test('creates with result', () {
        const content = ToolResultContent(
          toolCallId: 'call_123',
          name: 'get_weather',
          result: '{"temperature": 22}',
        );

        expect(content.toolCallId, 'call_123');
        expect(content.name, 'get_weather');
        expect(content.result, '{"temperature": 22}');
        expect(content.type, ContentType.toolResult);
        expect(content.isError, isFalse);
      });

      test('creates with error flag', () {
        const content = ToolResultContent(
          toolCallId: 'call_123',
          name: 'get_weather',
          result: 'API error',
          isError: true,
        );

        expect(content.isError, isTrue);
      });

      test('toJson returns correct structure', () {
        const content = ToolResultContent(
          toolCallId: 'test_id',
          name: 'test',
          result: 'test result',
        );
        final json = content.toJson();

        expect(json['type'], 'tool_result');
        expect(json['tool_call_id'], 'test_id');
        expect(json['name'], 'test');
        expect(json['result'], 'test result');
        expect(json['is_error'], isFalse);
      });

      test('equality', () {
        const c1 =
            ToolResultContent(toolCallId: '1', name: 'test', result: 'r');
        const c2 =
            ToolResultContent(toolCallId: '1', name: 'test', result: 'r');
        const c3 =
            ToolResultContent(toolCallId: '2', name: 'test', result: 'r');

        expect(c1, equals(c2));
        expect(c1, isNot(equals(c3)));
      });

      test('toString includes name and result', () {
        const content = ToolResultContent(
          toolCallId: '1',
          name: 'weather',
          result: {'temp': 22},
        );
        expect(content.toString(), contains('weather'));
      });
    });

    group('ContentType', () {
      test('has all expected values', () {
        expect(ContentType.values, contains(ContentType.text));
        expect(ContentType.values, contains(ContentType.image));
        expect(ContentType.values, contains(ContentType.audio));
        expect(ContentType.values, contains(ContentType.document));
        expect(ContentType.values, contains(ContentType.toolCall));
        expect(ContentType.values, contains(ContentType.toolResult));
      });
    });

    group('ImageDetail', () {
      test('has all expected values', () {
        expect(ImageDetail.values, contains(ImageDetail.auto));
        expect(ImageDetail.values, contains(ImageDetail.low));
        expect(ImageDetail.values, contains(ImageDetail.high));
      });
    });
  });
}
