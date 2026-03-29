import 'package:flutter/painting.dart';

import 'package:pretext/src/document/document.dart';
import 'package:pretext/src/document/document_cursor.dart';
import 'package:pretext/src/layout/layout_config.dart';
import 'package:pretext/src/layout/layout_result.dart';
import 'package:pretext/src/layout/page_layout.dart';
import 'package:pretext/src/obstacles/obstacle.dart';

/// Lay out a multi-column page with cursor handoff between columns.
///
/// This is a direct adaptation of Pretext's multi-column flow:
/// the left column consumes text until full, then hands its cursor
/// to the right column. The right column picks up exactly where
/// the left stopped — no duplication, no gap.
///
/// Obstacles are shifted relative to each column's origin so they
/// affect the correct columns.
LayoutPage layoutMultiColumnPage({
  required Document document,
  required DocumentCursor startCursor,
  required Size pageSize,
  required LayoutConfig config,
  int columnCount = 2,
  double columnGap = 32.0,
  List<Obstacle> obstacles = const [],
}) {
  final contentRect = config.contentRect(pageSize);
  final totalGap = (columnCount - 1) * columnGap;
  final columnWidth = (contentRect.width - totalGap) / columnCount;

  final allLines = <LayoutLine>[];
  final allImages = <LayoutImage>[];
  final allRules = <LayoutRule>[];
  final allDropCaps = <LayoutDropCap>[];
  var cursor = startCursor;

  for (int col = 0; col < columnCount; col++) {
    if (cursor.isAtEnd(document)) break;

    final colX = contentRect.left + col * (columnWidth + columnGap);

    // Shift obstacles into column-local coordinates
    final colObstacles = obstacles
        .map((o) => o.shifted(dx: -colX, dy: -contentRect.top))
        .toList();

    // Layout this column as a mini-page
    final colConfig = config.copyWith(
      margins: EdgeInsets.zero,
    );

    final colPage = layoutPage(
      document: document,
      startCursor: cursor,
      pageSize: Size(columnWidth, contentRect.height),
      config: colConfig,
      obstacles: colObstacles,
    );

    // Shift lines back to page coordinates
    for (final line in colPage.lines) {
      allLines.add(line.copyWith(
        x: line.x + colX,
        y: line.y + contentRect.top,
      ));
    }
    for (final image in colPage.images) {
      allImages.add(image.copyWith(
        rect: image.rect.shift(Offset(colX, contentRect.top)),
      ));
    }
    for (final rule in colPage.rules) {
      allRules.add(rule.copyWith(
        x: rule.x + colX,
        y: rule.y + contentRect.top,
      ));
    }
    for (final dropCap in colPage.dropCaps) {
      allDropCaps.add(LayoutDropCap(
        paragraph: dropCap.paragraph,
        x: dropCap.x + colX,
        y: dropCap.y + contentRect.top,
      ));
    }

    // Hand off cursor to next column
    cursor = colPage.endCursor;
  }

  return LayoutPage(
    lines: allLines,
    images: allImages,
    rules: allRules,
    dropCaps: allDropCaps,
    startCursor: startCursor,
    endCursor: cursor,
    size: pageSize,
  );
}
