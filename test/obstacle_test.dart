import 'package:flutter_test/flutter_test.dart';
import 'package:pretext/src/obstacles/obstacle.dart';

void main() {
  group('RectangleObstacle', () {
    const rect = RectangleObstacle(
      x: 100,
      y: 200,
      width: 150,
      height: 100,
      padding: 10,
    );

    test('returns null for bands above', () {
      expect(rect.horizontalBlockAt(0, 50), isNull);
      expect(rect.horizontalBlockAt(180, 189), isNull);
    });

    test('returns null for bands below', () {
      expect(rect.horizontalBlockAt(311, 350), isNull);
      expect(rect.horizontalBlockAt(400, 450), isNull);
    });

    test('returns interval for overlapping band', () {
      final interval = rect.horizontalBlockAt(220, 250);
      expect(interval, isNotNull);
      expect(interval!.left, 90); // x - padding
      expect(interval.right, 260); // x + width + padding
    });

    test('returns interval for band at top edge', () {
      // Band overlaps the padded top (200 - 10 = 190)
      final interval = rect.horizontalBlockAt(185, 195);
      expect(interval, isNotNull);
    });

    test('shifted moves position', () {
      final shifted = rect.shifted(dx: 50, dy: -100);
      expect(shifted.x, 150);
      expect(shifted.y, 100);
      expect(shifted.width, 150);
      expect(shifted.height, 100);
    });
  });

  group('CircleObstacle', () {
    const circle = CircleObstacle(
      cx: 200,
      cy: 200,
      r: 50,
      horizontalPadding: 0,
      verticalPadding: 0,
    );

    test('returns null for bands outside circle', () {
      expect(circle.horizontalBlockAt(0, 100), isNull);
      expect(circle.horizontalBlockAt(260, 300), isNull);
    });

    test('widest at center', () {
      final interval = circle.horizontalBlockAt(199, 201);
      expect(interval, isNotNull);
      // At center, full diameter
      expect(interval!.left, closeTo(150, 1));
      expect(interval.right, closeTo(250, 1));
      expect(interval.width, closeTo(100, 2));
    });

    test('narrower near edges', () {
      final interval = circle.horizontalBlockAt(155, 160);
      expect(interval, isNotNull);
      // Near top edge, should be narrower
      expect(interval!.width, lessThan(100));
    });

    test('respects padding', () {
      const padded = CircleObstacle(
        cx: 200,
        cy: 200,
        r: 50,
        horizontalPadding: 10,
        verticalPadding: 5,
      );
      final interval = padded.horizontalBlockAt(199, 201);
      expect(interval, isNotNull);
      // Should be wider by 2 * hPad
      expect(interval!.width, closeTo(120, 2));
    });

    test('shifted moves center', () {
      final shifted = circle.shifted(dx: 100, dy: -50);
      expect(shifted.cx, 300);
      expect(shifted.cy, 150);
      expect(shifted.r, 50);
    });
  });

  group('PolygonObstacle', () {
    // A simple square polygon
    const square = PolygonObstacle(
      points: [
        (x: 100.0, y: 100.0),
        (x: 200.0, y: 100.0),
        (x: 200.0, y: 200.0),
        (x: 100.0, y: 200.0),
      ],
      horizontalPadding: 0,
      verticalPadding: 0,
    );

    test('returns null for bands outside', () {
      expect(square.horizontalBlockAt(0, 50), isNull);
      expect(square.horizontalBlockAt(250, 300), isNull);
    });

    test('returns correct interval for band through middle', () {
      final interval = square.horizontalBlockAt(140, 160);
      expect(interval, isNotNull);
      expect(interval!.left, closeTo(100, 2));
      expect(interval.right, closeTo(200, 2));
    });

    // A triangle
    test('triangle narrows toward apex', () {
      const triangle = PolygonObstacle(
        points: [
          (x: 150.0, y: 100.0), // apex
          (x: 200.0, y: 200.0), // bottom right
          (x: 100.0, y: 200.0), // bottom left
        ],
        horizontalPadding: 0,
        verticalPadding: 0,
      );

      final nearBase = triangle.horizontalBlockAt(190, 195);
      final nearApex = triangle.horizontalBlockAt(110, 115);
      expect(nearBase, isNotNull);
      expect(nearApex, isNotNull);
      expect(nearBase!.width, greaterThan(nearApex!.width));
    });

    test('shifted moves all points', () {
      final shifted = square.shifted(dx: 50, dy: 25);
      expect(shifted.points[0].x, 150);
      expect(shifted.points[0].y, 125);
    });
  });
}
