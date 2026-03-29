import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pretext/src/document/attributed_span.dart';
import 'package:pretext/src/document/block.dart';
import 'package:pretext/src/document/document.dart';
import 'package:pretext/src/document/document_cursor.dart';
import 'package:pretext/src/layout/layout_config.dart';
import 'package:pretext/src/layout/layout_result.dart';
import 'package:pretext/src/layout/line_breaker.dart';
import 'package:pretext/src/layout/page_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('layoutPage', () {
    test('advances by measured heading height instead of fixed lineHeight', () {
      final config = LayoutConfig(
        baseTextStyle: const TextStyle(fontSize: 12, height: 1.0),
        lineHeight: 12,
        blockSpacing: 6,
        margins: EdgeInsets.zero,
        headingStyleResolver: (_) =>
            const TextStyle(fontSize: 40, height: 1.2, fontWeight: FontWeight.bold),
      );
      final document = Document.singleChapter([
        const HeadingBlock(
          level: 1,
          spans: [AttributedSpan.plain('Measured heading')],
        ),
        ParagraphBlock.plain('Body copy that should move to the next page.'),
      ]);

      const lineBreaker = LineBreaker();
      final measuredHeading = lineBreaker.layoutNextLine(
        spans: (document.chapters.first.blocks.first as HeadingBlock).spans,
        textOffset: 0,
        maxWidth: 240,
        baseStyle: config.headingStyle(1),
        cursorBase: const DocumentCursor.zero(),
      )!;

      final page = layoutPage(
        document: document,
        startCursor: document.startCursor,
        pageSize: Size(240, measuredHeading.height + 2),
        config: config,
      );

      expect(page.lines, hasLength(1));
      expect(page.lines.first.height, greaterThan(config.lineHeight));
      expect(page.endCursor.blockIndex, 0);
      expect(page.endCursor.textOffset, greaterThan(0));

      measuredHeading.paragraph.dispose();
      _disposePage(page);
    });

    test('renders image and horizontal rule blocks instead of skipping them', () {
      const config = LayoutConfig(
        baseTextStyle: TextStyle(fontSize: 12, height: 1.2),
        lineHeight: 16,
        blockSpacing: 8,
        margins: EdgeInsets.zero,
      );
      final document = Document.singleChapter([
        const ImageBlock(
          src: 'cover.jpg',
          width: 80,
          height: 60,
          alt: 'Cover art',
        ),
        const HorizontalRuleBlock(),
        ParagraphBlock.plain('Tail paragraph'),
      ]);

      final page = layoutPage(
        document: document,
        startCursor: document.startCursor,
        pageSize: const Size(240, 240),
        config: config,
      );

      expect(page.images, hasLength(1));
      expect(page.images.first.alt, 'Cover art');
      expect(page.rules, hasLength(1));
      expect(page.lines, isNotEmpty);
      expect(
        page.endCursor.compareTo(
          const DocumentCursor(chapterIndex: 0, blockIndex: 2, textOffset: 0),
        ),
        greaterThanOrEqualTo(0),
      );

      _disposePage(page);
    });

    test('adds zero-width marker lines for list items without consuming cursor text', () {
      const config = LayoutConfig(
        baseTextStyle: TextStyle(fontSize: 12, height: 1.2),
        lineHeight: 16,
        blockSpacing: 8,
        margins: EdgeInsets.zero,
      );
      final document = Document.singleChapter([
        const ListBlock(
          ordered: false,
          items: [
            [AttributedSpan.plain('First item')],
            [AttributedSpan.plain('Second item')],
          ],
        ),
      ]);

      final page = layoutPage(
        document: document,
        startCursor: document.startCursor,
        pageSize: const Size(240, 240),
        config: config,
      );

      final markerLines =
          page.lines.where((line) => line.start == line.end).toList();
      expect(markerLines, hasLength(2));
      expect(page.endCursor.isAtEnd(document), isTrue);

      _disposePage(page);
    });

    test('keeps blockquote child blocks indented and separated', () {
      const config = LayoutConfig(
        baseTextStyle: TextStyle(fontSize: 12, height: 1.2),
        lineHeight: 16,
        blockSpacing: 10,
        margins: EdgeInsets.zero,
        blockquoteIndent: 24,
      );
      final document = Document.singleChapter([
        BlockquoteBlock([
          ParagraphBlock.plain('Alpha'),
          ParagraphBlock.plain('Beta'),
        ]),
      ]);

      final page = layoutPage(
        document: document,
        startCursor: document.startCursor,
        pageSize: const Size(240, 240),
        config: config,
      );

      final textLines =
          page.lines.where((line) => line.start != line.end).toList();
      expect(textLines, hasLength(2));
      expect(textLines.first.x, greaterThan(0));
      expect(
        textLines[1].y,
        greaterThanOrEqualTo(
          textLines.first.y + textLines.first.height + config.blockSpacing - 0.1,
        ),
      );

      _disposePage(page);
    });

    test('lays out table blocks as grid cells and paginates cleanly', () {
      const config = LayoutConfig(
        baseTextStyle: TextStyle(fontSize: 12, height: 1.2),
        lineHeight: 16,
        blockSpacing: 8,
        margins: EdgeInsets.zero,
      );
      final document = Document.singleChapter([
        const TableBlock(
          caption: [AttributedSpan.plain('Statistics')],
          rows: [
            TableRowData([
              TableCellData(
                spans: [AttributedSpan.plain('Label')],
                isHeader: true,
              ),
              TableCellData(
                spans: [AttributedSpan.plain('Value')],
                isHeader: true,
              ),
            ]),
            TableRowData([
              TableCellData(spans: [AttributedSpan.plain('Alpha')]),
              TableCellData(spans: [AttributedSpan.plain('42')]),
            ]),
            TableRowData([
              TableCellData(spans: [AttributedSpan.plain('Beta')]),
              TableCellData(spans: [AttributedSpan.plain('99')]),
            ]),
          ],
        ),
      ]);

      final firstPage = layoutPage(
        document: document,
        startCursor: document.startCursor,
        pageSize: const Size(240, 70),
        config: config,
      );

      expect(firstPage.tables, hasLength(1));
      expect(firstPage.tables.first.captionParagraph, isNotNull);
      expect(firstPage.tables.first.cells, hasLength(2));
      expect(firstPage.endCursor.blockIndex, 0);
      expect(firstPage.endCursor.textOffset, greaterThan(0));
      expect(firstPage.endCursor.isAtBlockEnd(document), isFalse);

      final secondPage = layoutPage(
        document: document,
        startCursor: firstPage.endCursor,
        pageSize: const Size(240, 140),
        config: config,
      );

      expect(secondPage.tables, hasLength(1));
      expect(secondPage.tables.first.captionParagraph, isNull);
      expect(secondPage.tables.first.cells, hasLength(4));
      expect(secondPage.endCursor.isAtEnd(document), isTrue);

      _disposePage(firstPage);
      _disposePage(secondPage);
    });

    test('sizes table columns from content instead of splitting evenly', () {
      const config = LayoutConfig(
        baseTextStyle: TextStyle(fontSize: 12, height: 1.2),
        lineHeight: 16,
        blockSpacing: 8,
        margins: EdgeInsets.zero,
      );
      final document = Document.singleChapter([
        const TableBlock(
          rows: [
            TableRowData([
              TableCellData(
                spans: [AttributedSpan.plain('Very wide column content')],
                isHeader: true,
              ),
              TableCellData(
                spans: [AttributedSpan.plain('Narrow')],
                isHeader: true,
              ),
            ]),
          ],
        ),
      ]);

      final page = layoutPage(
        document: document,
        startCursor: document.startCursor,
        pageSize: const Size(240, 120),
        config: config,
      );

      expect(page.tables, hasLength(1));
      final cells = page.tables.first.cells;
      expect(cells, hasLength(2));
      expect(cells[0].rect.width, greaterThan(cells[1].rect.width));

      _disposePage(page);
    });

    test('continues a single table row across pages with block resume state', () {
      const config = LayoutConfig(
        baseTextStyle: TextStyle(fontSize: 12, height: 1.2),
        lineHeight: 16,
        blockSpacing: 8,
        margins: EdgeInsets.zero,
      );
      final document = Document.singleChapter([
        TableBlock(
          rows: [
            TableRowData([
              TableCellData(
                spans: [AttributedSpan.plain('Alpha ' * 32)],
              ),
              TableCellData(
                spans: [AttributedSpan.plain('Beta ' * 32)],
              ),
            ]),
          ],
        ),
      ]);

      final firstPage = layoutPage(
        document: document,
        startCursor: document.startCursor,
        pageSize: const Size(240, 34),
        config: config,
      );

      expect(firstPage.tables, hasLength(1));
      expect(firstPage.tables.first.cells, hasLength(2));
      expect(firstPage.endCursor.blockData, isNotNull);
      expect(firstPage.endCursor.isAtEnd(document), isFalse);

      final secondPage = layoutPage(
        document: document,
        startCursor: firstPage.endCursor,
        pageSize: const Size(240, 240),
        config: config,
      );

      expect(secondPage.tables, hasLength(1));
      expect(secondPage.tables.first.cells, hasLength(2));
      expect(secondPage.endCursor.compareTo(firstPage.endCursor), greaterThan(0));
      expect(
        secondPage.tables.first.cells[0].rect.width,
        closeTo(firstPage.tables.first.cells[0].rect.width, 0.01),
      );
      expect(
        secondPage.tables.first.cells[1].rect.width,
        closeTo(firstPage.tables.first.cells[1].rect.width, 0.01),
      );

      var cursor = secondPage.endCursor;
      for (int i = 0; i < 5 && !cursor.isAtEnd(document); i++) {
        final page = layoutPage(
          document: document,
          startCursor: cursor,
          pageSize: const Size(240, 240),
          config: config,
        );
        expect(page.tables, hasLength(1));
        expect(page.endCursor.compareTo(cursor), greaterThan(0));
        cursor = page.endCursor;
        _disposePage(page);
      }
      expect(cursor.isAtEnd(document), isTrue);

      _disposePage(firstPage);
      _disposePage(secondPage);
    });
  });
}

void _disposePage(LayoutPage page) {
  page.dispose();
}
