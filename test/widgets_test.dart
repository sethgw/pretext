import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pretext/src/document/document_cursor.dart';
import 'package:pretext/src/epub/epub_result.dart';
import 'package:pretext/src/widgets/progress_store.dart';
import 'package:pretext/src/widgets/reader_theme.dart';
import 'package:pretext/src/widgets/toc_drawer.dart';

void main() {
  group('ReaderTheme', () {
    test('light theme produces a valid LayoutConfig', () {
      final config = ReaderTheme.light.toLayoutConfig();
      expect(config.baseTextStyle.color, const Color(0xFF1A1A1A));
      expect(config.baseTextStyle.fontSize, 17);
      expect(config.baseTextStyle.fontFamily, 'Georgia');
      expect(config.lineHeight, 17 * 1.6);
      expect(config.margins, const EdgeInsets.symmetric(horizontal: 28, vertical: 32));
    });

    test('sepia theme produces a valid LayoutConfig', () {
      final config = ReaderTheme.sepia.toLayoutConfig();
      expect(config.baseTextStyle.color, const Color(0xFF5B4636));
      expect(config.baseTextStyle.fontSize, 17);
      expect(config.baseTextStyle.fontFamily, 'Georgia');
      expect(config.lineHeight, 17 * 1.6);
    });

    test('dark theme produces a valid LayoutConfig', () {
      final config = ReaderTheme.dark.toLayoutConfig();
      expect(config.baseTextStyle.color, const Color(0xFFCCCCCC));
      expect(config.baseTextStyle.fontSize, 17);
      expect(config.lineHeight, 17 * 1.6);
    });

    test('built-in themes have correct brightness', () {
      expect(ReaderTheme.light.brightness, Brightness.light);
      expect(ReaderTheme.sepia.brightness, Brightness.light);
      expect(ReaderTheme.dark.brightness, Brightness.dark);
    });

    test('copyWith overrides specified fields', () {
      final custom = ReaderTheme.light.copyWith(
        name: 'Custom',
        fontSize: 20,
        fontFamily: 'Helvetica',
        backgroundColor: const Color(0xFF112233),
      );

      expect(custom.name, 'Custom');
      expect(custom.fontSize, 20);
      expect(custom.fontFamily, 'Helvetica');
      expect(custom.backgroundColor, const Color(0xFF112233));
      // Unchanged fields should be preserved
      expect(custom.textColor, ReaderTheme.light.textColor);
      expect(custom.ruleColor, ReaderTheme.light.ruleColor);
      expect(custom.lineHeightMultiplier, ReaderTheme.light.lineHeightMultiplier);
      expect(custom.margins, ReaderTheme.light.margins);
      expect(custom.brightness, ReaderTheme.light.brightness);
    });

    test('copyWith with no arguments returns equivalent theme', () {
      final copy = ReaderTheme.dark.copyWith();
      expect(copy.name, ReaderTheme.dark.name);
      expect(copy.backgroundColor, ReaderTheme.dark.backgroundColor);
      expect(copy.textColor, ReaderTheme.dark.textColor);
      expect(copy.fontSize, ReaderTheme.dark.fontSize);
    });

    test('copyWith fontSize affects LayoutConfig lineHeight', () {
      final big = ReaderTheme.light.copyWith(fontSize: 24);
      final config = big.toLayoutConfig();
      expect(config.lineHeight, 24 * 1.6);
      expect(config.baseTextStyle.fontSize, 24);
    });
  });

  group('CallbackProgressStore', () {
    test('load returns null when no saved data', () async {
      final store = CallbackProgressStore(
        onLoad: (_) async => null,
        onSave: (_, __) async {},
        onClear: (_) async {},
      );

      final cursor = await store.load('book-1');
      expect(cursor, isNull);
    });

    test('save and load round-trip correctly', () async {
      final storage = <String, String>{};

      final store = CallbackProgressStore(
        onLoad: (bookId) async => storage[bookId],
        onSave: (bookId, serialized) async {
          storage[bookId] = serialized;
        },
        onClear: (bookId) async {
          storage.remove(bookId);
        },
      );

      const cursor = DocumentCursor(
        chapterIndex: 2,
        blockIndex: 5,
        textOffset: 42,
      );

      await store.save('book-1', cursor);
      final loaded = await store.load('book-1');

      expect(loaded, isNotNull);
      expect(loaded!.chapterIndex, 2);
      expect(loaded.blockIndex, 5);
      expect(loaded.textOffset, 42);
      expect(loaded, cursor);
    });

    test('clear removes saved data', () async {
      final storage = <String, String>{};

      final store = CallbackProgressStore(
        onLoad: (bookId) async => storage[bookId],
        onSave: (bookId, serialized) async {
          storage[bookId] = serialized;
        },
        onClear: (bookId) async {
          storage.remove(bookId);
        },
      );

      const cursor = DocumentCursor(
        chapterIndex: 1,
        blockIndex: 0,
        textOffset: 10,
      );

      await store.save('book-1', cursor);
      expect(await store.load('book-1'), isNotNull);

      await store.clear('book-1');
      expect(await store.load('book-1'), isNull);
    });

    test('multiple books are stored independently', () async {
      final storage = <String, String>{};

      final store = CallbackProgressStore(
        onLoad: (bookId) async => storage[bookId],
        onSave: (bookId, serialized) async {
          storage[bookId] = serialized;
        },
        onClear: (bookId) async {
          storage.remove(bookId);
        },
      );

      const cursorA = DocumentCursor(
        chapterIndex: 0,
        blockIndex: 0,
        textOffset: 5,
      );
      const cursorB = DocumentCursor(
        chapterIndex: 3,
        blockIndex: 2,
        textOffset: 100,
      );

      await store.save('book-a', cursorA);
      await store.save('book-b', cursorB);

      final loadedA = await store.load('book-a');
      final loadedB = await store.load('book-b');

      expect(loadedA, cursorA);
      expect(loadedB, cursorB);
    });
  });

  group('TocDrawer', () {
    test('can be constructed with entries', () {
      const entries = [
        TocEntry(title: 'Chapter 1', href: 'ch1.xhtml'),
        TocEntry(
          title: 'Chapter 2',
          href: 'ch2.xhtml',
          children: [
            TocEntry(title: 'Section 2.1', href: 'ch2.xhtml#s1'),
          ],
        ),
      ];

      const drawer = TocDrawer(
        entries: entries,
        title: 'My Book',
      );

      expect(drawer.entries, entries);
      expect(drawer.title, 'My Book');
      expect(drawer.onEntryTapped, isNull);
    });

    testWidgets('renders title and entries', (tester) async {
      const entries = [
        TocEntry(title: 'Chapter 1', href: 'ch1.xhtml'),
        TocEntry(
          title: 'Chapter 2',
          href: 'ch2.xhtml',
          children: [
            TocEntry(title: 'Section 2.1', href: 'ch2.xhtml#s1'),
          ],
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            drawer: TocDrawer(
              entries: entries,
              title: 'Test Book',
            ),
          ),
        ),
      );

      // Open the drawer
      final scaffoldState =
          tester.firstState<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Test Book'), findsOneWidget);
      expect(find.text('Chapter 1'), findsOneWidget);
      expect(find.text('Chapter 2'), findsOneWidget);
      expect(find.text('Section 2.1'), findsOneWidget);
    });

    testWidgets('onEntryTapped fires when entry is tapped', (tester) async {
      TocEntry? tapped;
      const entries = [
        TocEntry(title: 'Chapter 1', href: 'ch1.xhtml'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: TocDrawer(
              entries: entries,
              onEntryTapped: (entry) => tapped = entry,
            ),
          ),
        ),
      );

      final scaffoldState =
          tester.firstState<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chapter 1'));
      await tester.pumpAndSettle();

      expect(tapped, isNotNull);
      expect(tapped!.title, 'Chapter 1');
      expect(tapped!.href, 'ch1.xhtml');
    });
  });
}
