import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pretext/src/document/block.dart';
import 'package:pretext/src/document/document.dart';
import 'package:pretext/src/layout/layout_config.dart';
import 'package:pretext/src/layout/layout_result.dart';
import 'package:pretext/src/layout/page_layout.dart';
import 'package:pretext/src/obstacles/obstacle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const config = LayoutConfig(
    baseTextStyle: TextStyle(fontSize: 14, height: 1.35),
    lineHeight: 20,
    blockSpacing: 12,
    margins: EdgeInsets.zero,
    minSlotWidth: 80,
  );

  final document = Document.singleChapter([
    ParagraphBlock.plain('Dragon story ${'flame and smoke ' * 180}'),
  ]);

  group('dragon demo', () {
    test('text wraps around a dragon-shaped obstacle on a page', () {
      const pageSize = Size(280, 280);
      final dragon = _dragonObstacle(dx: 28);

      final page = layoutPage(
        document: document,
        startCursor: document.startCursor,
        pageSize: pageSize,
        config: config,
        obstacles: [dragon],
      );

      final affectedLines = _linesInDragonBand(page, dragon);
      final lowerLines = page.lines
          .where((line) => line.y >= _dragonBottom(dragon) + 8)
          .toList();

      expect(affectedLines, isNotEmpty);
      expect(
        affectedLines.any((line) => line.x > 120),
        isTrue,
        reason: 'The dragon should push some lines well to the right.',
      );
      expect(lowerLines, isNotEmpty);
      expect(
        lowerLines.any((line) => line.x < 5),
        isTrue,
        reason: 'Once the dragon is gone, text should return to the left edge.',
      );

      _disposePage(page);
    });

    test('a moving dragon changes the text flow from page to page', () {
      const pageSize = Size(280, 220);

      final pages = layoutDocument(
        document: document,
        pageSize: pageSize,
        config: config,
        obstacleBuilder: (pageIndex, _) => [
          _dragonObstacle(dx: 18 + pageIndex * 55),
        ],
      );

      expect(pages.length, greaterThanOrEqualTo(3));

      final page0Dragon = _dragonObstacle(dx: 18);
      final page1Dragon = _dragonObstacle(dx: 73);
      final page2Dragon = _dragonObstacle(dx: 128);

      final page0Lead = _leadingXInDragonBand(pages[0], page0Dragon);
      final page1Lead = _leadingXInDragonBand(pages[1], page1Dragon);
      final page2Lead = _leadingXInDragonBand(pages[2], page2Dragon);

      expect(page0Lead, greaterThan(120));
      expect(page1Lead, lessThan(page0Lead));
      expect(page2Lead, lessThan(10));

      for (final page in pages) {
        _disposePage(page);
      }
    });
  });
}

PolygonObstacle _dragonObstacle({required double dx}) {
  return PolygonObstacle(
    points: [
      (x: dx + 20, y: 26.0),
      (x: dx + 70, y: 8.0),
      (x: dx + 120, y: 34.0),
      (x: dx + 104, y: 82.0),
      (x: dx + 132, y: 118.0),
      (x: dx + 92, y: 148.0),
      (x: dx + 62, y: 128.0),
      (x: dx + 38, y: 164.0),
      (x: dx + 8, y: 126.0),
      (x: dx + 2, y: 82.0),
    ],
    horizontalPadding: 8,
    verticalPadding: 4,
  );
}

List<LayoutLine> _linesInDragonBand(LayoutPage page, PolygonObstacle dragon) {
  final top = _dragonTop(dragon);
  final bottom = _dragonBottom(dragon);
  return page.lines
      .where((line) => line.y < bottom && line.y + line.height > top)
      .toList();
}

double _leadingXInDragonBand(LayoutPage page, PolygonObstacle dragon) {
  final lines = _linesInDragonBand(page, dragon);
  expect(lines, isNotEmpty);
  return lines.first.x;
}

double _dragonTop(PolygonObstacle dragon) {
  return dragon.points
      .map((point) => point.y)
      .reduce((value, element) => value < element ? value : element);
}

double _dragonBottom(PolygonObstacle dragon) {
  return dragon.points
      .map((point) => point.y)
      .reduce((value, element) => value > element ? value : element);
}

void _disposePage(LayoutPage page) {
  page.dispose();
}
