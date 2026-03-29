import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pretext/src/document/attributed_span.dart';
import 'package:pretext/src/document/block.dart';
import 'package:pretext/src/document/document.dart';
import 'package:pretext/src/document/document_cursor.dart';
import 'package:pretext/src/layout/layout_config.dart';
import 'package:pretext/src/layout/page_layout.dart';

void main() {
  // Common config for tests: small page, known line height.
  const baseStyle = TextStyle(fontSize: 16.0);
  const config = LayoutConfig(
    baseTextStyle: baseStyle,
    lineHeight: 20.0,
    blockSpacing: 8.0,
    margins: EdgeInsets.all(20.0),
    headingMaxLines: 0, // disable adaptive headlines by default
  );

  const pageSize = Size(400, 600);

  group('Drop Caps', () {
    test('produces a LayoutDropCap when enabled', () {
      final doc = Document.singleChapter([
        ParagraphBlock.plain(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
          'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
        ),
      ]);

      final dropCapConfig = config.copyWith(enableDropCaps: true);

      final page = layoutPage(
        document: doc,
        startCursor: const DocumentCursor.zero(),
        pageSize: pageSize,
        config: dropCapConfig,
      );

      expect(page.dropCaps, isNotEmpty,
          reason: 'Drop cap should be produced for the first paragraph');
      expect(page.dropCaps.length, 1);
      expect(page.dropCaps.first.x, config.contentRect(pageSize).left);
      expect(page.dropCaps.first.y, config.contentRect(pageSize).top);
    });

    test('drop cap obstacle indents early lines', () {
      final longText = 'A${'bcd ' * 200}';
      final doc = Document.singleChapter([
        ParagraphBlock.plain(longText),
      ]);

      // Layout WITHOUT drop caps.
      final pageNoDC = layoutPage(
        document: doc,
        startCursor: const DocumentCursor.zero(),
        pageSize: pageSize,
        config: config,
      );

      // Layout WITH drop caps.
      final dropCapConfig = config.copyWith(enableDropCaps: true);
      final pageDC = layoutPage(
        document: doc,
        startCursor: const DocumentCursor.zero(),
        pageSize: pageSize,
        config: dropCapConfig,
      );

      // The first few lines with drop cap should start further right
      // (the obstacle pushes text to the right).
      expect(pageDC.lines, isNotEmpty);
      expect(pageNoDC.lines, isNotEmpty);

      // First line's x should be greater with drop cap active (indented).
      final firstLineDC = pageDC.lines.first;
      final firstLineNoDC = pageNoDC.lines.first;
      expect(firstLineDC.x, greaterThan(firstLineNoDC.x),
          reason: 'Drop cap obstacle should indent the first lines');
    });

    test('drop cap only applies to the first paragraph (blockIndex 0)', () {
      final doc = Document.singleChapter([
        ParagraphBlock.plain('First paragraph with enough text to fill a line.'),
        ParagraphBlock.plain('Second paragraph should not have a drop cap.'),
      ]);

      final dropCapConfig = config.copyWith(enableDropCaps: true);

      final page = layoutPage(
        document: doc,
        startCursor: const DocumentCursor.zero(),
        pageSize: pageSize,
        config: dropCapConfig,
      );

      // Only one drop cap (for the first paragraph).
      expect(page.dropCaps.length, 1);
    });

    test('no drop cap when starting mid-paragraph', () {
      final doc = Document.singleChapter([
        ParagraphBlock.plain(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
          'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
        ),
      ]);

      final dropCapConfig = config.copyWith(enableDropCaps: true);

      // Start at textOffset 5 — not the beginning of the paragraph.
      const midCursor = DocumentCursor(
        chapterIndex: 0,
        blockIndex: 0,
        textOffset: 5,
      );
      final page = layoutPage(
        document: doc,
        startCursor: midCursor,
        pageSize: pageSize,
        config: dropCapConfig,
      );

      expect(page.dropCaps, isEmpty,
          reason: 'Drop cap should not appear when starting mid-paragraph');
    });

    test('no drop cap when enableDropCaps is false', () {
      final doc = Document.singleChapter([
        ParagraphBlock.plain(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        ),
      ]);

      final page = layoutPage(
        document: doc,
        startCursor: const DocumentCursor.zero(),
        pageSize: pageSize,
        config: config, // enableDropCaps defaults to false
      );

      expect(page.dropCaps, isEmpty);
    });

    test('drop cap does not apply to heading blocks', () {
      final doc = Document.singleChapter([
        const HeadingBlock(
          level: 1,
          spans: [AttributedSpan.plain('Chapter Title')],
        ),
        ParagraphBlock.plain('Body text after the heading.'),
      ]);

      const dropCapConfig2 = LayoutConfig(
        baseTextStyle: baseStyle,
        lineHeight: 20.0,
        blockSpacing: 8.0,
        margins: EdgeInsets.all(20.0),
        headingMaxLines: 0,
        enableDropCaps: true,
      );

      final page = layoutPage(
        document: doc,
        startCursor: const DocumentCursor.zero(),
        pageSize: pageSize,
        config: dropCapConfig2,
      );

      // Heading is blockIndex 0 but not a ParagraphBlock, so no drop cap.
      // The paragraph at blockIndex 1 is not blockIndex 0, so also no drop cap.
      expect(page.dropCaps, isEmpty,
          reason: 'Drop cap only applies to ParagraphBlock at blockIndex 0');
    });
  });

  group('Adaptive Headline Sizing', () {
    test('short heading is not scaled down', () {
      final doc = Document.singleChapter([
        const HeadingBlock(
          level: 1,
          spans: [AttributedSpan.plain('Short')],
        ),
        ParagraphBlock.plain('Body text.'),
      ]);

      final adaptiveConfig = config.copyWith(headingMaxLines: 3);

      final page = layoutPage(
        document: doc,
        startCursor: const DocumentCursor.zero(),
        pageSize: pageSize,
        config: adaptiveConfig,
      );

      // "Short" should fit on one line — the heading should be present.
      expect(page.lines, isNotEmpty);
    });

    test('long heading gets scaled down to fit', () {
      // With Ahem font at 16px base, H1 is 32px (2x scale).
      // Content width = 400 - 40 = 360px.
      // At 32px each char is 32px wide => 360/32 = 11 chars/line.
      // We need a heading that exceeds 3 lines at 32px but fits at a
      // smaller size. At 0.6 * 32 = 19.2px => 360/19.2 = 18 chars/line.
      // So a ~50-char heading: 50/11 = ~5 lines at 32px, 50/18 = ~3 at 19.2px.
      // Use a wider page to give more room for the scaling to work.
      const widePageSize = Size(800, 600);
      // Content width = 800 - 40 = 760px.
      // At 32px: 760/32 = 23 chars/line => 50 chars = 3 lines (ceil 50/23=3)
      // Need something that takes >3 lines at 32, <=3 at smaller.
      // At 32px: 100 chars => 100/23 = 5 lines.
      // At 0.6*32=19.2px: 760/19.2 = 39 chars/line => 100/39 = 3 lines.
      const longTitle =
          'A Long Heading Title That Should Wrap Over Several Lines '
          'At The Original Large Font Size';
      // ~89 chars. At 32px, 760/32=23 chars/line => 89/23 ~ 4 lines.
      // At 0.6*32=19.2px, 760/19.2=39 chars/line => 89/39 ~ 3 lines.

      final doc = Document.singleChapter([
        const HeadingBlock(
          level: 1,
          spans: [AttributedSpan.plain(longTitle)],
        ),
        ParagraphBlock.plain('Body text after the long heading.'),
      ]);

      // Layout with adaptive sizing disabled (headingMaxLines = 0).
      final noAdaptConfig = config.copyWith(headingMaxLines: 0);
      final pageNoAdapt = layoutPage(
        document: doc,
        startCursor: const DocumentCursor.zero(),
        pageSize: widePageSize,
        config: noAdaptConfig,
      );

      // Layout with adaptive sizing enabled (headingMaxLines = 3).
      final adaptiveConfig = config.copyWith(headingMaxLines: 3);
      final pageAdapt = layoutPage(
        document: doc,
        startCursor: const DocumentCursor.zero(),
        pageSize: widePageSize,
        config: adaptiveConfig,
      );

      // Both should produce lines.
      expect(pageNoAdapt.lines, isNotEmpty);
      expect(pageAdapt.lines, isNotEmpty);

      // With adaptive sizing, the heading should use fewer lines
      // (or at most headingMaxLines) because the font is shrunk.
      // Count heading lines: they appear before the body text cursor
      // reaches blockIndex 1.
      int countHeadingLines(page) {
        int count = 0;
        for (final line in page.lines) {
          if (line.start.blockIndex == 0) {
            count++;
          }
        }
        return count;
      }

      final headingLinesNoAdapt = countHeadingLines(pageNoAdapt);
      final headingLinesAdapt = countHeadingLines(pageAdapt);

      // The non-adaptive version should have more heading lines than 3.
      expect(headingLinesNoAdapt, greaterThan(3),
          reason:
              'Without adaptive sizing the long heading should exceed 3 lines');

      // The adaptive version should have at most headingMaxLines.
      expect(headingLinesAdapt, lessThanOrEqualTo(3),
          reason: 'Adaptive sizing should shrink heading to fit in 3 lines');
    });

    test('heading at minimum scale is not shrunk further', () {
      // A heading so long that even at minScale it might still be >3 lines.
      final veryLongTitle = 'Word ' * 100;

      final doc = Document.singleChapter([
        HeadingBlock(
          level: 1,
          spans: [AttributedSpan.plain(veryLongTitle.trim())],
        ),
      ]);

      // Very restrictive: max 1 line, min scale 0.9.
      final restrictiveConfig = config.copyWith(
        headingMaxLines: 1,
        headingMinScale: 0.9,
      );

      // Should not throw or infinite-loop — just do its best.
      final page = layoutPage(
        document: doc,
        startCursor: const DocumentCursor.zero(),
        pageSize: pageSize,
        config: restrictiveConfig,
      );

      expect(page.lines, isNotEmpty,
          reason: 'Layout should still produce lines even if heading '
              'cannot fit within maxLines at minScale');
    });

    test('adaptive sizing disabled when headingMaxLines is 0', () {
      const longTitle = 'This Is A Reasonably Long Heading That May Wrap';

      final doc = Document.singleChapter([
        const HeadingBlock(
          level: 1,
          spans: [AttributedSpan.plain(longTitle)],
        ),
      ]);

      // headingMaxLines = 0 disables adaptive sizing.
      final disabledConfig = config.copyWith(headingMaxLines: 0);

      final page = layoutPage(
        document: doc,
        startCursor: const DocumentCursor.zero(),
        pageSize: pageSize,
        config: disabledConfig,
      );

      // Should still lay out fine — just no shrinking.
      expect(page.lines, isNotEmpty);
    });
  });
}
