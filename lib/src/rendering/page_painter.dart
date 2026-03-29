import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:pretext/src/layout/layout_result.dart';
import 'package:pretext/src/obstacles/obstacle.dart';

/// A [CustomPainter] that renders a [LayoutPage].
///
/// Iterates over all positioned [LayoutLine]s and paints each one
/// via [Canvas.drawParagraph]. This is the final rendering step —
/// all layout computation (line breaking, obstacle avoidance, positioning)
/// has already been done by the layout engine.
class PagePainter extends CustomPainter {
  final LayoutPage page;
  final Color? backgroundColor;
  final bool debugObstacles;
  final List<Obstacle> obstacles;

  const PagePainter({
    required this.page,
    this.backgroundColor,
    this.debugObstacles = false,
    this.obstacles = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    if (backgroundColor != null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = backgroundColor!,
      );
    }

    // Debug: paint obstacle shapes
    if (debugObstacles) {
      _paintObstacles(canvas, size);
    }

    // Paint each positioned text line
    for (final line in page.lines) {
      canvas.drawParagraph(line.paragraph, Offset(line.x, line.y));
    }
  }

  void _paintObstacles(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x20FF0000)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0x60FF0000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final obstacle in obstacles) {
      switch (obstacle) {
        case RectangleObstacle(:final x, :final y, :final width, :final height):
          final rect = Rect.fromLTWH(x, y, width, height);
          canvas.drawRect(rect, paint);
          canvas.drawRect(rect, strokePaint);
        case CircleObstacle(:final cx, :final cy, :final r):
          canvas.drawCircle(Offset(cx, cy), r, paint);
          canvas.drawCircle(Offset(cx, cy), r, strokePaint);
        case PolygonObstacle(:final points):
          if (points.length >= 3) {
            final path = Path()
              ..moveTo(points.first.x, points.first.y);
            for (int i = 1; i < points.length; i++) {
              path.lineTo(points[i].x, points[i].y);
            }
            path.close();
            canvas.drawPath(path, paint);
            canvas.drawPath(path, strokePaint);
          }
      }
    }
  }

  @override
  bool shouldRepaint(PagePainter oldDelegate) {
    return !identical(page, oldDelegate.page) ||
        backgroundColor != oldDelegate.backgroundColor ||
        debugObstacles != oldDelegate.debugObstacles;
  }
}
