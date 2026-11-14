import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ai_book_reader/features/studio/services/artifact_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('artifact_export_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ArtifactExportService utilities', () {
    test('markdownToPlainText cleanly strips markdown formatting', () {
      const markdown = '''
# Heading 1
## Heading 2

Here is **bold** text and *italic* text with `inline code`.

Check out [OpenAI](https://openai.com) for details.

> A wise quote from a book.

- First key item
- Second key item

```dart
void main() => print("Hello");
```
''';

      final plain = ArtifactExportService.markdownToPlainText(markdown);

      expect(plain.contains('# Heading'), isFalse);
      expect(plain.contains('Heading 1'), isTrue);
      expect(plain.contains('Heading 2'), isTrue);
      expect(plain.contains('**bold**'), isFalse);
      expect(plain.contains('bold text and italic text'), isTrue);
      expect(plain.contains('`inline code`'), isFalse);
      expect(plain.contains('inline code'), isTrue);
      expect(plain.contains('[OpenAI]'), isFalse);
      expect(plain.contains('OpenAI'), isTrue);
      expect(plain.contains('> A wise quote'), isFalse);
      expect(plain.contains('A wise quote'), isTrue);
      expect(plain.contains('• First key item'), isTrue);
      expect(plain.contains('• Second key item'), isTrue);
      expect(plain.contains('```'), isFalse);
      expect(plain.contains('void main() => print("Hello");'), isTrue);
    });

    test('sanitizeFilename removes illegal characters and handles extensions', () {
      expect(
        ArtifactExportService.sanitizeFilename(
          'Book Summary: Chapter 1/Introduction & Ideas',
          'md',
        ),
        equals('Book_Summary__Chapter_1_Introduction_&_Ideas.md'),
      );

      expect(
        ArtifactExportService.sanitizeFilename('  Trim Me  ', '.txt'),
        equals('Trim_Me.txt'),
      );

      expect(
        ArtifactExportService.sanitizeFilename('', 'md'),
        equals('study_artifact.md'),
      );
    });

    test('saveToFile writes content to file inside target directory', () async {
      final service = ArtifactExportService(
        getDirectory: () async => tempDir,
      );

      final file = await service.saveToFile(
        filename: 'notes.md',
        content: '# Test Content',
      );

      expect(file.existsSync(), isTrue);
      expect(await file.readAsString(), equals('# Test Content'));
      expect(file.path.endsWith('notes.md'), isTrue);
    });
  });

  group('ArtifactExportService widget & share integration', () {
    testWidgets('copyToClipboard copies data and displays SnackBar', (
      tester,
    ) async {
      final service = ArtifactExportService();
      String? copiedData;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedData = (methodCall.arguments as Map)['text']?.toString();
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => service.copyToClipboard(
                  context,
                  'Sample Text',
                  message: 'Successfully copied!',
                ),
                child: const Text('Copy'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(copiedData, equals('Sample Text'));
      expect(find.text('Successfully copied!'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });

    test('exportAndShare saves file and invokes shareFiles', () async {
      List<XFile>? sharedFiles;
      String? sharedSubject;

      final service = ArtifactExportService(
        getDirectory: () async => tempDir,
        shareFiles: (files, {subject, text}) async {
          sharedFiles = files;
          sharedSubject = subject;
        },
      );

      final file = await service.exportAndShare(
        title: 'Meditations Summary',
        content: '# Meditations by Marcus Aurelius',
        extension: 'md',
      );

      expect(file.existsSync(), isTrue);
      expect(await file.readAsString(), equals('# Meditations by Marcus Aurelius'));
      expect(sharedFiles, isNotNull);
      expect(sharedFiles!.length, equals(1));
      expect(sharedFiles!.first.path.endsWith('Meditations_Summary.md'), isTrue);
      expect(sharedSubject, equals('Meditations Summary'));
    });
  });
}
