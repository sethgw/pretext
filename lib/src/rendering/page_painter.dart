import 'dart:math' as math;
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
  static const _tableCellPadding = 8.0;

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
          ..strokeWidth = rule.thickness,
      );
    }

    // Paint images
    for (final image in page.images) {
      final resolved = imageResolver?.call(image.src);
      if (resolved != null) {
        final srcRect = Rect.fromLTWH(
          0,
          0,
          resolved.width.toDouble(),
          resolved.height.toDouble(),
        );
        canvas.drawImageRect(resolved, srcRect, image.rect, Paint());
      } else {
        _paintImagePlaceholder(canvas, image);
      }
    }

    // Paint tables
    for (final table in page.tables) {
      _paintTable(canvas, table);
    }

    // Paint each positioned text line
    for (final line in page.lines) {
      canvas.drawParagraph(line.paragraph, Offset(line.x, line.y));
    }

    // Paint drop cap letters
    for (final dropCap in page.dropCaps) {
      canvas.drawParagraph(dropCap.paragraph, Offset(dropCap.x, dropCap.y));
    }
  }

  void _paintImagePlaceholder(Canvas canvas, LayoutImage image) {
    final fillPaint = Paint()..color = const Color(0x12000000);
    final strokePaint = Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(image.rect, fillPaint);
    canvas.drawRect(image.rect, strokePaint);

    final label = (image.alt != null && image.alt!.trim().isNotEmpty)
        ? image.alt!.trim()
        : image.src;
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0x99000000),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '...',
    )..layout(maxWidth: math.max(1.0, image.rect.width - 16));

    final textOffset = Offset(
      image.rect.left + 8,
      image.rect.top + (image.rect.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, textOffset);
  }

  void _paintTable(Canvas canvas, LayoutTable table) {
    final headerFillPaint = Paint()..color = const Color(0x0F000000);
    final cellFillPaint = Paint()..color = const Color(0x05000000);
    final borderPaint = Paint()
      ..color = ruleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final captionRect = table.captionRect;
    final captionParagraph = table.captionParagraph;
    if (captionRect != null && captionParagraph != null) {
      canvas.drawParagraph(
        captionParagraph,
        Offset(captionRect.left, captionRect.top),
      );
    }

    for (final cell in table.cells) {
      canvas.drawRect(
        cell.rect,
        cell.isHeader ? headerFillPaint : cellFillPaint,
      );
      canvas.drawRect(cell.rect, borderPaint);

      final paragraph = cell.paragraph;
      if (paragraph != null) {
        canvas.drawParagraph(
          paragraph,
          Offset(
            cell.rect.left + _tableCellPadding,
            cell.rect.top + _tableCellPadding,
          ),
        );
      }
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
        debugObstacles != oldDelegate.debugObstacles ||
        ruleColor != oldDelegate.ruleColor ||
        imageResolver != oldDelegate.imageResolver ||
        !identical(obstacles, oldDelegate.obstacles);
  }
}
