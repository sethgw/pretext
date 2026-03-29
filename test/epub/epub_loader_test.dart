import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pretext/src/document/block.dart';
import 'package:pretext/src/document/document_cursor.dart';
import 'package:pretext/src/epub/epub_loader.dart';

void main() {
  group('loadEpub', () {
    test('resolves TOC hrefs and anchor targets into document cursors', () {
      final bytes = _buildTestEpub();
      final result = loadEpub(bytes);

      expect(result.document.chapters, hasLength(2));
      expect(result.tableOfContents, hasLength(2));
      expect(result.tableOfContents[0].href, 'OEBPS/chapter1.xhtml');
      expect(result.tableOfContents[1].href, 'OEBPS/chapter2.xhtml#deep');

      expect(
        result.resolveHref('OEBPS/chapter1.xhtml'),
        const DocumentCursor(chapterIndex: 0, blockIndex: 0, textOffset: 0),
      );
      expect(
        result.resolveHref(result.tableOfContents[1].href),
        const DocumentCursor(chapterIndex: 1, blockIndex: 1, textOffset: 0),
      );

      final chapter1 = result.document.chapters.first;
      final linkedParagraph = chapter1.blocks.first as ParagraphBlock;
      final image = chapter1.blocks[1] as ImageBlock;

      expect(
        linkedParagraph.spans.first.style.href,
        'OEBPS/chapter2.xhtml#deep',
      );
      expect(image.src, 'OEBPS/images/dragon.png');
    });
  });
}

Uint8List _buildTestEpub() {
  final archive = Archive();

  void addTextFile(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  addTextFile(
    'META-INF/container.xml',
    '''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''',
  );

  addTextFile(
    'OEBPS/content.opf',
    '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Test EPUB</dc:title>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="chapter2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>
    <item id="dragon" href="images/dragon.png" media-type="image/png"/>
  </manifest>
  <spine>
    <itemref idref="chapter1"/>
    <itemref idref="chapter2"/>
  </spine>
</package>
''',
  );

  addTextFile(
    'OEBPS/nav.xhtml',
    '''
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="toc">
      <ol>
        <li><a href="chapter1.xhtml">Chapter 1</a></li>
        <li><a href="chapter2.xhtml#deep">Chapter 2</a></li>
      </ol>
    </nav>
  </body>
</html>
''',
  );

  addTextFile(
    'OEBPS/chapter1.xhtml',
    '''
<html xmlns="http://www.w3.org/1999/xhtml">
  <body>
    <p id="start"><a href="chapter2.xhtml#deep">Smoke drifted over the valley.</a></p>
    <img src="images/dragon.png" alt="dragon"/>
  </body>
</html>
''',
  );

  addTextFile(
    'OEBPS/chapter2.xhtml',
    '''
<html xmlns="http://www.w3.org/1999/xhtml">
  <body>
    <h1>Chapter 2</h1>
    <p id="deep">The dragon folded its wings and descended.</p>
  </body>
</html>
''',
  );

  archive.addFile(
    ArchiveFile(
      'OEBPS/images/dragon.png',
      _tinyPng.length,
      _tinyPng,
    ),
  );

  final encoded = ZipEncoder().encode(archive);
  expect(encoded, isNotNull);
  return Uint8List.fromList(encoded);
}

final _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO2pQ2kAAAAASUVORK5CYII=',
);
