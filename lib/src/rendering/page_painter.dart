import 'dart:ui' as ui;

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

  /// Optional callback to resolve image src paths to decoded images.
  /// If null, images are not painted.
  final ui.Image? Function(String src)? imageResolver;

  /// Color for horizontal rules. Defaults to 20% opacity black.
  final Color ruleColor;

  const PagePainter({
    required this.page,
    this.backgroundColor,
    this.debugObstacles = false,
    this.obstacles = const [],
    this.imageResolver,
    this.ruleColor = const Color(0x33000000),
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

    // Paint horizontal rules
    for (final rule in page.rules) {
      canvas.drawLine(
        Offset(rule.x, rule.y),
        Offset(rule.x + rule.width, rule.y),
        Paint()
          ..color = ruleColor
          ..strokeWidth = 1.0,
      );
    }

    // Paint images
    if (imageResolver != null) {
      for (final image in page.images) {
        final resolved = imageResolver!(image.src);
        if (resolved != null) {
          final srcRect = Rect.fromLTWH(
            0,
            0,
            resolved.width.toDouble(),
            resolved.height.toDouble(),
          );
          canvas.drawImageRect(resolved, srcRect, image.rect, Paint());
        }
      }
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
