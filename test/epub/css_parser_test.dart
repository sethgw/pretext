import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pretext/src/document/span_style.dart';
import 'package:pretext/src/epub/css_parser.dart';

void main() {
  // -----------------------------------------------------------------------
  // parseInlineStyle
  // -----------------------------------------------------------------------

  group('parseInlineStyle', () {
    test('parses font-weight bold', () {
      final style = parseInlineStyle('font-weight: bold');
      expect(style.bold, isTrue);
      expect(style.fontWeight, FontWeight.w700);
    });

    test('parses numeric font-weight 600', () {
      final style = parseInlineStyle('font-weight: 600');
      expect(style.fontWeight, FontWeight.w600);
      expect(style.bold, isFalse);
    });

    test('parses numeric font-weight 700 sets bold', () {
      final style = parseInlineStyle('font-weight: 700');
      expect(style.fontWeight, FontWeight.w700);
      expect(style.bold, isTrue);
    });

    test('parses multiple properties', () {
      final style = parseInlineStyle(
        'font-weight: bold; font-style: italic; font-size: 14px; '
        'letter-spacing: 2px; line-height: 1.6',
      );
      expect(style.bold, isTrue);
      expect(style.italic, isTrue);
      expect(style.fontSize, 14.0);
      expect(style.letterSpacing, 2.0);
      expect(style.height, 1.6);
    });

    test('parses color in #RRGGBB hex format', () {
      final style = parseInlineStyle('color: #333333');
      expect(style.color, const Color(0xFF333333));
    });

    test('parses color in #RGB shorthand hex format', () {
      final style = parseInlineStyle('color: #f00');
      expect(style.color, const Color(0xFFFF0000));
    });

    test('parses color in rgb() format', () {
      final style = parseInlineStyle('color: rgb(255, 128, 0)');
      expect(style.color, const Color(0xFFFF8000));
    });

    test('parses font-family (strips quotes, takes first)', () {
      final style = parseInlineStyle('font-family: "Georgia", serif');
      expect(style.fontFamily, 'Georgia');
    });

    test('parses text-decoration underline', () {
      final style = parseInlineStyle('text-decoration: underline');
      expect(style.decoration, TextDecoration.underline);
    });

    test('parses text-decoration line-through', () {
      final style = parseInlineStyle('text-decoration: line-through');
      expect(style.decoration, TextDecoration.lineThrough);
    });

    test('returns SpanStyle.normal for empty input', () {
      expect(parseInlineStyle(''), same(SpanStyle.normal));
      expect(parseInlineStyle('   '), same(SpanStyle.normal));
    });

    test('returns SpanStyle.normal for malformed input', () {
      expect(parseInlineStyle('not-a-property'), same(SpanStyle.normal));
      expect(parseInlineStyle(';;;'), same(SpanStyle.normal));
      expect(parseInlineStyle(': value'), same(SpanStyle.normal));
    });

    test('parses font-size with em units', () {
      final style = parseInlineStyle('font-size: 1.2em');
      expect(style.fontSize, isNull);
      expect(style.fontSizeScale, 1.2);
    });

    test('parses font-size with percent units', () {
      final style = parseInlineStyle('font-size: 120%');
      expect(style.fontSize, isNull);
      expect(style.fontSizeScale, 1.2);
    });

    test('resolves relative font-size against the base text style', () {
      final style = parseInlineStyle('font-size: 120%');
      final resolved = style.toTextStyle(const TextStyle(fontSize: 20));
      expect(resolved.fontSize, 24);
    });

    test('parses pixel line-height as an absolute line box height', () {
      final style = parseInlineStyle('line-height: 24px');
      expect(style.height, isNull);
      expect(style.lineHeightPx, 24);

      final resolved = style.toTextStyle(const TextStyle(fontSize: 16));
      expect(resolved.height, 1.5);
    });

    test('parses em letter-spacing relative to font size', () {
      final style = parseInlineStyle('letter-spacing: 0.1em');
      expect(style.letterSpacing, isNull);
      expect(style.letterSpacingScale, 0.1);

      final resolved = style.toTextStyle(const TextStyle(fontSize: 20));
      expect(resolved.letterSpacing, 2.0);
    });
  });

  // -----------------------------------------------------------------------
  // parseStylesheet
  // -----------------------------------------------------------------------

  group('parseStylesheet', () {
    test('parses element selectors', () {
      final map = parseStylesheet('p { font-size: 16px; } h1 { font-weight: bold; }');
      expect(map['p']?.fontSize, 16.0);
      expect(map['h1']?.bold, isTrue);
    });

    test('parses class selectors', () {
      final map = parseStylesheet('.italic { font-style: italic; }');
      expect(map['.italic']?.italic, isTrue);
    });

    test('parses id selectors', () {
      final map = parseStylesheet('#title { font-size: 24px; color: #000000; }');
      expect(map['#title']?.fontSize, 24.0);
      expect(map['#title']?.color, const Color(0xFF000000));
    });

    test('parses element.class selectors', () {
      final map = parseStylesheet('p.intro { font-style: italic; font-size: 18px; }');
      expect(map['p.intro']?.italic, isTrue);
      expect(map['p.intro']?.fontSize, 18.0);
    });

    test('parses comma-separated selectors', () {
      final map = parseStylesheet('h1, h2, h3 { font-weight: bold; }');
      expect(map['h1']?.bold, isTrue);
      expect(map['h2']?.bold, isTrue);
      expect(map['h3']?.bold, isTrue);
    });

    test('strips comments', () {
      final map = parseStylesheet(
        '/* heading styles */ h1 { font-weight: bold; } '
        '/* paragraph */ p { font-size: 14px; }',
      );
      expect(map['h1']?.bold, isTrue);
      expect(map['p']?.fontSize, 14.0);
    });

    test('handles multiline comments', () {
      final map = parseStylesheet('''
        /*
         * Multi-line
         * comment
         */
        p { font-size: 12px; }
      ''');
      expect(map['p']?.fontSize, 12.0);
    });

    test('returns empty map for empty input', () {
      expect(parseStylesheet(''), isEmpty);
      expect(parseStylesheet('/* just a comment */'), isEmpty);
    });
  });

  // -----------------------------------------------------------------------
  // resolveElementStyle
  // -----------------------------------------------------------------------

  group('resolveElementStyle', () {
    test('merges in correct order (element < class < element.class < id)', () {
      final stylesheet = parseStylesheet('''
        p { font-size: 14px; color: #000000; }
        .highlight { color: #FF0000; }
        p.highlight { font-style: italic; }
        #special { font-weight: bold; }
      ''');

      final style = resolveElementStyle(
        stylesheet,
        'p',
        ['highlight'],
        'special',
      );

      // font-size from p
      expect(style.fontSize, 14.0);
      // color from .highlight overrides p
      expect(style.color, const Color(0xFFFF0000));
      // italic from p.highlight
      expect(style.italic, isTrue);
      // bold from #special
      expect(style.bold, isTrue);
    });

    test('returns SpanStyle.normal when nothing matches', () {
      final stylesheet = parseStylesheet('h1 { font-weight: bold; }');
      final style = resolveElementStyle(stylesheet, 'p', [], null);
      expect(style, SpanStyle.normal);
    });

    test('handles multiple classes', () {
      final stylesheet = parseStylesheet('''
        .bold { font-weight: bold; }
        .italic { font-style: italic; }
      ''');

      final style = resolveElementStyle(stylesheet, 'span', ['bold', 'italic'], null);
      expect(style.bold, isTrue);
      expect(style.italic, isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // parseColor
  // -----------------------------------------------------------------------

  group('parseColor', () {
    test('parses #RGB shorthand', () {
      expect(parseColor('#f00'), const Color(0xFFFF0000));
      expect(parseColor('#0f0'), const Color(0xFF00FF00));
      expect(parseColor('#00f'), const Color(0xFF0000FF));
    });

    test('parses #RRGGBB', () {
      expect(parseColor('#ff8800'), const Color(0xFFFF8800));
      expect(parseColor('#000000'), const Color(0xFF000000));
      expect(parseColor('#FFFFFF'), const Color(0xFFFFFFFF));
    });

    test('parses rgb() function', () {
      expect(parseColor('rgb(255, 0, 0)'), const Color(0xFFFF0000));
      expect(parseColor('rgb(0,128,255)'), const Color(0xFF0080FF));
    });

    test('clamps rgb values to 0-255', () {
      expect(parseColor('rgb(999, -1, 128)'), const Color(0xFFFF0080));
    });

    test('parses named colors', () {
      expect(parseColor('black'), const Color(0xFF000000));
      expect(parseColor('white'), const Color(0xFFFFFFFF));
      expect(parseColor('red'), const Color(0xFFFF0000));
      expect(parseColor('blue'), const Color(0xFF0000FF));
      expect(parseColor('green'), const Color(0xFF008000));
      expect(parseColor('gray'), const Color(0xFF808080));
      expect(parseColor('grey'), const Color(0xFF808080));
    });

    test('is case-insensitive', () {
      expect(parseColor('RED'), const Color(0xFFFF0000));
      expect(parseColor('#FF0000'), const Color(0xFFFF0000));
    });

    test('returns null for unrecognized values', () {
      expect(parseColor('transparent'), isNull);
      expect(parseColor('not-a-color'), isNull);
      expect(parseColor('#GGG'), isNull);
      expect(parseColor(''), isNull);
    });
  });
}
