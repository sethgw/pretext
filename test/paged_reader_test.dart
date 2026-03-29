import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pretext/src/document/block.dart';
import 'package:pretext/src/document/document.dart';
import 'package:pretext/src/document/document_cursor.dart';
import 'package:pretext/src/layout/layout_config.dart';
import 'package:pretext/src/obstacles/obstacle.dart';
import 'package:pretext/src/widgets/paged_reader.dart';
import 'package:pretext/src/widgets/progress_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const config = LayoutConfig(
    baseTextStyle: TextStyle(fontSize: 14, height: 1.4),
    lineHeight: 20,
    blockSpacing: 10,
    margins: EdgeInsets.all(12),
  );

  final document = Document.singleChapter(
    List.generate(
      6,
      (index) => ParagraphBlock.plain(
        'Paragraph $index ${'word ' * 80}',
      ),
    ),
  );

  group('PagedReader cache invalidation', () {
    testWidgets('recomputes pages when initialCursor changes', (tester) async {
      final key = GlobalKey<PagedReaderState>();

      await tester.pumpWidget(
        _readerHarness(
          key: key,
          document: document,
          config: config,
          initialCursor: const DocumentCursor.zero(),
        ),
      );
      await tester.pumpAndSettle();

      final startProgress = key.currentState!.progress;

      await tester.pumpWidget(
        _readerHarness(
          key: key,
          document: document,
          config: config,
          initialCursor: const DocumentCursor(
            chapterIndex: 0,
            blockIndex: 2,
            textOffset: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(key.currentState!.currentPageIndex, 0);
      expect(key.currentState!.progress, greaterThan(startProgress));
    });

    testWidgets('recomputes pages when obstacleBuilder changes', (tester) async {
      final key = GlobalKey<PagedReaderState>();

      await tester.pumpWidget(
        _readerHarness(
          key: key,
          document: document,
          config: config,
        ),
      );
      await tester.pumpAndSettle();

      final unobstructedProgress = key.currentState!.progress;

      await tester.pumpWidget(
        _readerHarness(
          key: key,
          document: document,
          config: config,
          obstacleBuilder: (_, __) => const [
            RectangleObstacle(
              x: 0,
              y: 0,
              width: 100,
              height: 200,
              padding: 0,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(key.currentState!.progress, lessThan(unobstructedProgress));
    });
  });

  group('PagedReader progress restore', () {
    testWidgets('restores saved progress after startup', (tester) async {
      final key = GlobalKey<PagedReaderState>();
      final store = _MapProgressStore({
        'book-1': const DocumentCursor(
          chapterIndex: 0,
          blockIndex: 4,
          textOffset: 0,
        ),
      });

      await tester.pumpWidget(
        _readerHarness(
          key: key,
          document: document,
          config: config,
          progressStore: store,
          bookId: 'book-1',
        ),
      );
      await tester.pumpAndSettle();

      expect(key.currentState!.currentPageIndex, greaterThan(0));
    });

    testWidgets('ignores stale restore results when bookId changes',
        (tester) async {
      final key = GlobalKey<PagedReaderState>();
      final store = _DeferredProgressStore();

      await tester.pumpWidget(
        _readerHarness(
          key: key,
          document: document,
          config: config,
          progressStore: store,
          bookId: 'old-book',
        ),
      );

      await tester.pumpWidget(
        _readerHarness(
          key: key,
          document: document,
          config: config,
          progressStore: store,
          bookId: 'new-book',
        ),
      );

      store.complete(
        'new-book',
        const DocumentCursor.zero(),
      );
      await tester.pumpAndSettle();

      store.complete(
        'old-book',
        const DocumentCursor(
          chapterIndex: 0,
          blockIndex: 5,
          textOffset: 0,
        ),
      );
      await tester.pumpAndSettle();

      expect(key.currentState!.currentPageIndex, 0);
    });
  });
}

Widget _readerHarness({
  required GlobalKey<PagedReaderState> key,
  required Document document,
  required LayoutConfig config,
  DocumentCursor? initialCursor,
  List<Obstacle> Function(int pageIndex, Size pageSize)? obstacleBuilder,
  ProgressStore? progressStore,
  String? bookId,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 220,
        height: 180,
        child: PagedReader(
          key: key,
          document: document,
          config: config,
          initialCursor: initialCursor,
          obstacleBuilder: obstacleBuilder,
          progressStore: progressStore,
          bookId: bookId,
        ),
      ),
    ),
  );
}

class _MapProgressStore implements ProgressStore {
  final Map<String, DocumentCursor> stored;

  _MapProgressStore(this.stored);

  @override
  Future<void> clear(String bookId) async {
    stored.remove(bookId);
  }

  @override
  Future<DocumentCursor?> load(String bookId) async => stored[bookId];

  @override
  Future<void> save(String bookId, DocumentCursor cursor) async {
    stored[bookId] = cursor;
  }
}

class _DeferredProgressStore implements ProgressStore {
  final _loads = <String, Completer<DocumentCursor?>>{};

  @override
  Future<void> clear(String bookId) async {
    _loads.remove(bookId);
  }

  void complete(String bookId, DocumentCursor? cursor) {
    _loads.putIfAbsent(bookId, Completer.new).complete(cursor);
  }

  @override
  Future<DocumentCursor?> load(String bookId) {
    return _loads.putIfAbsent(bookId, Completer.new).future;
  }

  @override
  Future<void> save(String bookId, DocumentCursor cursor) async {}
}
