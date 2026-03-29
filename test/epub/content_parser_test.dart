import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pretext/src/document/block.dart';
import 'package:pretext/src/document/span_style.dart';
import 'package:pretext/src/epub/content_parser.dart';

void main() {
  group('parseContentDocument', () {
    test('simple <p> text becomes ParagraphBlock', () {
      final result = parseContentDocument(
        '<html><body><p>Hello world</p></body></html>',
      );

      expect(result.chapter.blocks, hasLength(1));
      final block = result.chapter.blocks[0] as ParagraphBlock;
      expect(block.plainText, 'Hello world');
    });

    test('sets chapter title from parameter', () {
      final result = parseContentDocument(
        '<html><body><p>Text</p></body></html>',
        title: 'Chapter One',
      );

      expect(result.chapter.title, 'Chapter One');
    });

    test('<h1> through <h6> become HeadingBlock with correct level', () {
      for (var level = 1; level <= 6; level++) {
        final result = parseContentDocument(
          '<html><body><h$level>Heading $level</h$level></body></html>',
        );

        expect(result.chapter.blocks, hasLength(1),
            reason: 'h$level should produce one block');
        final block = result.chapter.blocks[0] as HeadingBlock;
        expect(block.level, level);
        expect(block.plainText, 'Heading $level');
      }
    });

    test('<strong> and <b> produce bold spans', () {
      final result = parseContentDocument(
        '<html><body><p><strong>bold text</strong></p></body></html>',
      );

      final block = result.chapter.blocks[0] as ParagraphBlock;
      expect(block.spans, hasLength(1));
      expect(block.spans[0].style.bold, isTrue);
      expect(block.spans[0].text, 'bold text');

      final result2 = parseContentDocument(
        '<html><body><p><b>also bold</b></p></body></html>',
      );

      final block2 = result2.chapter.blocks[0] as ParagraphBlock;
      expect(block2.spans[0].style.bold, isTrue);
    });

    test('<em> and <i> produce italic spans', () {
      final result = parseContentDocument(
        '<html><body><p><em>italic text</em></p></body></html>',
      );

      final block = result.chapter.blocks[0] as ParagraphBlock;
      expect(block.spans, hasLength(1));
      expect(block.spans[0].style.italic, isTrue);

      final result2 = parseContentDocument(
        '<html><body><p><i>also italic</i></p></body></html>',
      );

      final block2 = result2.chapter.blocks[0] as ParagraphBlock;
      expect(block2.spans[0].style.italic, isTrue);
    });

    test('<a href="..."> produces span with href', () {
      final result = parseContentDocument(
        '<html><body><p><a href="http://example.com">link</a></p></body></html>',
      );

      final block = result.chapter.blocks[0] as ParagraphBlock;
      expect(block.spans, hasLength(1));
      expect(block.spans[0].style.href, 'http://example.com');
      expect(block.spans[0].text, 'link');
    });

    test('nested inline styles merge correctly', () {
      final result = parseContentDocument(
        '<html><body><p><strong><em>bold italic</em></strong></p></body></html>',
      );

      final block = result.chapter.blocks[0] as ParagraphBlock;
      expect(block.spans, hasLength(1));
      expect(block.spans[0].style.bold, isTrue);
      expect(block.spans[0].style.italic, isTrue);
      expect(block.spans[0].text, 'bold italic');
    });

    test('<code> produces monospace span', () {
      final result = parseContentDocument(
        '<html><body><p><code>var x = 1</code></p></body></html>',
      );

      final block = result.chapter.blocks[0] as ParagraphBlock;
      expect(block.spans[0].style.fontFamily, 'monospace');
    });

    test('<u> produces underline decoration', () {
      final result = parseContentDocument(
        '<html><body><p><u>underlined</u></p></body></html>',
      );

      final block = result.chapter.blocks[0] as ParagraphBlock;
      expect(block.spans[0].style.decoration, TextDecoration.underline);
    });

    test('<s> and <del> produce lineThrough decoration', () {
      final result = parseContentDocument(
        '<html><body><p><s>struck</s></p></body></html>',
      );

      final block = result.chapter.blocks[0] as ParagraphBlock;
      expect(block.spans[0].style.decoration, TextDecoration.lineThrough);

      final result2 = parseContentDocument(
        '<html><body><p><del>deleted</del></p></body></html>',
      );

      final block2 = result2.chapter.blocks[0] as ParagraphBlock;
      expect(block2.spans[0].style.decoration, TextDecoration.lineThrough);
    });

    test('<sup> and <sub> produce reduced fontSize', () {
      final result = parseContentDocument(
        '<html><body><p><sup>super</sup></p></body></html>',
      );

      final block = result.chapter.blocks[0] as ParagraphBlock;
      expect(block.spans[0].style.fontSizeScale, 0.8);
      expect(
        block.spans[0].style.toTextStyle(const TextStyle(fontSize: 20)).fontSize,
        16,
      );

      final result2 = parseContentDocument(
        '<html><body><p><sub>sub</sub></p></body></html>',
      );

      final block2 = result2.chapter.blocks[0] as ParagraphBlock;
      expect(block2.spans[0].style.fontSizeScale, 0.8);
    });

    test('<blockquote> produces BlockquoteBlock with children', () {
      final result = parseContentDocument(
        '<html><body><blockquote><p>Quoted text</p></blockquote></body></html>',
      );

      expect(result.chapter.blocks, hasLength(1));
      final block = result.chapter.blocks[0] as BlockquoteBlock;
      expect(block.children, hasLength(1));
      final inner = block.children[0] as ParagraphBlock;
      expect(inner.plainText, 'Quoted text');
    });

    test('<ul> produces ListBlock with ordered=false', () {
      final result = parseContentDocument(
        '<html><body><ul><li>Item 1</li><li>Item 2</li></ul></body></html>',
      );

      expect(result.chapter.blocks, hasLength(1));
      final block = result.chapter.blocks[0] as ListBlock;
      expect(block.ordered, isFalse);
      expect(block.items, hasLength(2));
      expect(block.items[0].first.text, 'Item 1');
      expect(block.items[1].first.text, 'Item 2');
    });

    test('<ol> produces ListBlock with ordered=true', () {
      final result = parseContentDocument(
        '<html><body><ol><li>First</li><li>Second</li></ol></body></html>',
      );

      expect(result.chapter.blocks, hasLength(1));
      final block = result.chapter.blocks[0] as ListBlock;
      expect(block.ordered, isTrue);
      expect(block.items, hasLength(2));
    });

    test('<hr> produces HorizontalRuleBlock', () {
      final result = parseContentDocument(
        '<html><body><hr></body></html>',
      );

      expect(result.chapter.blocks, hasLength(1));
      expect(result.chapter.blocks[0], isA<HorizontalRuleBlock>());
    });

    test('<img> produces ImageBlock with src and alt', () {
      final result = parseContentDocument(
        '<html><body><img src="image.png" alt="A photo" width="200" height="100"></body></html>',
      );

      expect(result.chapter.blocks, hasLength(1));
      final block = result.chapter.blocks[0] as ImageBlock;
      expect(block.src, 'image.png');
      expect(block.alt, 'A photo');
      expect(block.width, 200.0);
      expect(block.height, 100.0);
    });

    test('<figure> with <img> and <figcaption>', () {
      final result = parseContentDocument(
        '<html><body>'
        '<figure>'
        '<img src="pic.jpg" alt="Original alt">'
        '<figcaption>Caption text</figcaption>'
        '</figure>'
        '</body></html>',
      );

      expect(result.chapter.blocks, hasLength(1));
      final block = result.chapter.blocks[0] as ImageBlock;
      expect(block.src, 'pic.jpg');
      expect(block.alt, 'Caption text');
    });

    test('whitespace is normalized (collapsed, trimmed)', () {
      final result = parseContentDocument(
        '<html><body><p>  Hello   \n  world  </p></body></html>',
      );

      final block = result.chapter.blocks[0] as ParagraphBlock;
      expect(block.plainText, 'Hello world');
    });

    test('empty elements produce no blocks', () {
      final result = parseContentDocument(
        '<html><body><p>  </p><p></p><div></div></body></html>',
      );

      expect(result.chapter.blocks, isEmpty);
    });

    test('mixed block/inline content is handled', () {
      final result = parseContentDocument(
        '<html><body>'
        'Some orphan text'
        '<p>A paragraph</p>'
        'More orphan text'
        '</body></html>',
      );

      // Orphan text before <p> becomes its own ParagraphBlock.
      // <p> becomes a ParagraphBlock.
      // Orphan text after <p> becomes another ParagraphBlock.
      expect(result.chapter.blocks, hasLength(3));
      final block0 = result.chapter.blocks[0] as ParagraphBlock;
      expect(block0.plainText, 'Some orphan text');
      final block1 = result.chapter.blocks[1] as ParagraphBlock;
      expect(block1.plainText, 'A paragraph');
      final block2 = result.chapter.blocks[2] as ParagraphBlock;
      expect(block2.plainText, 'More orphan text');
    });

    test('CSS class styling is applied when stylesheet provided', () {
      final stylesheet = {
        '.italic': const SpanStyle(italic: true),
        '.bold': const SpanStyle(bold: true),
      };

      final result = parseContentDocument(
        '<html><body><p><span class="italic bold">styled</span></p></body></html>',
        stylesheet: stylesheet,
      );

      final block = result.chapter.blocks[0] as ParagraphBlock;
      expect(block.spans[0].style.italic, isTrue);
      expect(block.spans[0].style.bold, isTrue);
    });

    test('inline style attribute is parsed', () {
      final result = parseContentDocument(
        '<html><body><p><span style="font-weight: bold; color: red">styled</span></p></body></html>',
      );

      final block = result.chapter.blocks[0] as ParagraphBlock;
      expect(block.spans[0].style.bold, isTrue);
      expect(block.spans[0].style.color, const Color(0xFFFF0000));
    });

    test('anchor IDs are recorded', () {
      final result = parseContentDocument(
        '<html><body>'
        '<h1 id="chapter-1">Chapter 1</h1>'
        '<p id="intro">Introduction</p>'
        '<p>Body text</p>'
        '</body></html>',
      );

      expect(result.anchors, containsPair('chapter-1', 0));
      expect(result.anchors, containsPair('intro', 1));
    });

    test('<br> inserts newline in span text', () {
      final result = parseContentDocument(
        '<html><body><p>Line 1<br>Line 2</p></body></html>',
      );

      final block = result.chapter.blocks[0] as ParagraphBlock;
      final combined = block.spans.map((s) => s.text).join();
      expect(combined, contains('\n'));
    });

    test('<pre> preserves whitespace', () {
      final result = parseContentDocument(
        '<html><body><pre>  indented\n    more</pre></body></html>',
      );

      final block = result.chapter.blocks[0] as ParagraphBlock;
      final text = block.spans.map((s) => s.text).join();
      expect(text, contains('  indented'));
      expect(text, contains('\n'));
      expect(text, contains('    more'));
    });

    test('transparent wrapper elements are recursed into', () {
      final result = parseContentDocument(
        '<html><body>'
        '<div><section><p>Deeply nested</p></section></div>'
        '</body></html>',
      );

      expect(result.chapter.blocks, hasLength(1));
      final block = result.chapter.blocks[0] as ParagraphBlock;
      expect(block.plainText, 'Deeply nested');
    });

    test('multiple paragraphs produce multiple blocks', () {
      final result = parseContentDocument(
        '<html><body>'
        '<p>First</p>'
        '<p>Second</p>'
        '<p>Third</p>'
        '</body></html>',
      );

      expect(result.chapter.blocks, hasLength(3));
      expect((result.chapter.blocks[0] as ParagraphBlock).plainText, 'First');
      expect((result.chapter.blocks[1] as ParagraphBlock).plainText, 'Second');
      expect((result.chapter.blocks[2] as ParagraphBlock).plainText, 'Third');
    });

    test('empty input produces empty chapter', () {
      final result = parseContentDocument('');

      expect(result.chapter.blocks, isEmpty);
      expect(result.anchors, isEmpty);
    });

    test('mixed inline and block content within paragraph', () {
      final result = parseContentDocument(
        '<html><body><p>Normal <strong>bold</strong> normal again</p></body></html>',
      );

      final block = result.chapter.blocks[0] as ParagraphBlock;
      expect(block.spans.length, greaterThanOrEqualTo(3));
      expect(block.spans[0].text, 'Normal ');
      expect(block.spans[0].style.bold, isFalse);
      expect(block.spans[1].text, 'bold');
      expect(block.spans[1].style.bold, isTrue);
      expect(block.spans[2].text, ' normal again');
      expect(block.spans[2].style.bold, isFalse);
    });

    test('element selector in stylesheet applies to matching elements', () {
      final stylesheet = {
        'p': const SpanStyle(italic: true),
      };

      final result = parseContentDocument(
        '<html><body><p>styled paragraph</p></body></html>',
        stylesheet: stylesheet,
      );

      final block = result.chapter.blocks[0] as ParagraphBlock;
      expect(block.spans[0].style.italic, isTrue);
    });

    test('table elements become TableBlock rows and cells', () {
      final result = parseContentDocument(
        '<html><body>'
        '<p>Before</p>'
        '<table>'
        '<tr><td>Left</td><td>Right</td></tr>'
        '<tr><td>Bottom</td><td>Row</td></tr>'
        '</table>'
        '<p>After</p>'
        '</body></html>',
      );

      expect(result.chapter.blocks, hasLength(3));
      expect((result.chapter.blocks[0] as ParagraphBlock).plainText, 'Before');
      final table = result.chapter.blocks[1] as TableBlock;
      expect(table.rows, hasLength(2));
      expect(table.rows[0].cells, hasLength(2));
      expect(table.rows[0].cells[0].plainText, 'Left');
      expect(table.rows[0].cells[1].plainText, 'Right');
      expect(table.rows[1].cells[0].plainText, 'Bottom');
      expect(table.rows[1].cells[1].plainText, 'Row');
      expect((result.chapter.blocks[2] as ParagraphBlock).plainText, 'After');
    });

    test('table captions and header cells are preserved structurally', () {
      final result = parseContentDocument(
        '<html><body>'
        '<table>'
        '<caption>Statistics</caption>'
        '<thead><tr><th>Label</th><th>Value</th></tr></thead>'
        '<tbody><tr><td><p>Alpha</p><p>Beta</p></td><td>42</td></tr></tbody>'
        '</table>'
        '</body></html>',
      );

      expect(result.chapter.blocks, hasLength(1));
      final table = result.chapter.blocks[0] as TableBlock;
      expect(table.captionText, 'Statistics');
      expect(table.rows, hasLength(2));
      expect(table.rows[0].cells[0].isHeader, isTrue);
      expect(table.rows[0].cells[0].plainText, 'Label');
      expect(table.rows[0].cells[0].spans.first.style.bold, isTrue);
      expect(table.rows[0].cells[1].plainText, 'Value');
      expect(table.rows[1].cells[0].plainText, 'Alpha / Beta');
      expect(table.rows[1].cells[1].plainText, '42');
    });

    test('<img> without src produces no block', () {
      final result = parseContentDocument(
        '<html><body><img alt="no source"></body></html>',
      );

      expect(result.chapter.blocks, isEmpty);
    });
  });
}
