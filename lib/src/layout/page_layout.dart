import 'package:flutter/painting.dart';

import 'package:pretext/src/document/attributed_span.dart';
import 'package:pretext/src/document/block.dart';
import 'package:pretext/src/document/document.dart';
import 'package:pretext/src/document/document_cursor.dart';
import 'package:pretext/src/layout/layout_config.dart';
import 'package:pretext/src/layout/layout_result.dart';
import 'package:pretext/src/layout/line_breaker.dart';
import 'package:pretext/src/obstacles/interval_solver.dart';
import 'package:pretext/src/obstacles/obstacle.dart';

/// Lay out a single page of content from a [Document].
///
/// Starts at [startCursor] and fills the page rectangle defined by
/// [pageSize] and [config.margins]. Text flows around [obstacles],
/// which can be rectangles, circles, or arbitrary polygons.
///
/// Returns a [LayoutPage] containing all positioned lines and the
/// cursor where the next page should start.
///
/// This is the primary layout entry point — it composes the
/// [LineBreaker] with obstacle interval math to implement
/// Pretext-style variable-width line layout.
LayoutPage layoutPage({
  required Document document,
  required DocumentCursor startCursor,
  required Size pageSize,
  required LayoutConfig config,
  List<Obstacle> obstacles = const [],
}) {
  final contentRect = config.contentRect(pageSize);
  final lineBreaker = LineBreaker(
    textDirection: config.textDirection,
    lookaheadChars: config.lookaheadChars,
  );

  final lines = <LayoutLine>[];
  double y = contentRect.top;
  var cursor = startCursor;

  while (y + config.lineHeight <= contentRect.bottom) {
    // Check if we've reached the end of the document
    if (cursor.isAtEnd(document)) break;

    final block = document.blockAt(cursor);
    if (block == null) break;

    // Skip non-text blocks for now (images, rules)
    if (block is ImageBlock || block is HorizontalRuleBlock) {
      if (block is HorizontalRuleBlock) {
        y += config.blockSpacing;
      }
      cursor = cursor.nextBlock(document);
      continue;
    }

    // Resolve the spans and base style for this block
    final (spans, baseStyle) = _resolveBlock(block, config);
    if (spans == null) {
      cursor = cursor.nextBlock(document);
      continue;
    }

    // Compute available horizontal slots for this line band
    final bandTop = y;
    final bandBottom = y + config.lineHeight;
    final blocked = <Interval>[];
    for (final obstacle in obstacles) {
      final interval = obstacle.horizontalBlockAt(bandTop, bandBottom);
      if (interval != null) {
        blocked.add(interval);
      }
    }

    final slots = carveSlots(
      Interval(contentRect.left, contentRect.right),
      blocked,
      minWidth: config.minSlotWidth,
    );

    if (slots.isEmpty) {
      // Entire line band is blocked by obstacles — skip down
      y += config.lineHeight;
      continue;
    }

    // Fill each available slot with text
    bool anyLineProduced = false;
    for (final slot in slots) {
      if (cursor.isAtBlockEnd(document)) break;

      final line = lineBreaker.layoutNextLine(
        spans: spans,
        textOffset: cursor.textOffset,
        maxWidth: slot.width,
        baseStyle: baseStyle,
        cursorBase: cursor,
      );

      if (line == null) break;

      lines.add(line.copyWith(x: slot.left, y: y));
      cursor = line.end;
      anyLineProduced = true;
    }

    if (!anyLineProduced) {
      // No text could be placed — skip this band
      y += config.lineHeight;
      continue;
    }

    y += config.lineHeight;

    // If the current block is exhausted, advance to the next block
    if (cursor.isAtBlockEnd(document)) {
      cursor = cursor.nextBlock(document);
      y += config.blockSpacing;
    }
  }

  return LayoutPage(
    lines: lines,
    startCursor: startCursor,
    endCursor: cursor,
    size: pageSize,
  );
}

/// Lay out all pages for an entire [Document].
///
/// Returns a list of [LayoutPage]s. Pages are computed eagerly —
/// for large documents, prefer using [layoutPage] lazily via
/// [PagedReader] which computes pages on demand.
List<LayoutPage> layoutDocument({
  required Document document,
  required Size pageSize,
  required LayoutConfig config,
  List<Obstacle> Function(int pageIndex, Size pageSize)? obstacleBuilder,
}) {
  final pages = <LayoutPage>[];
  var cursor = document.startCursor;

  while (!cursor.isAtEnd(document)) {
    final pageIndex = pages.length;
    final obstacles = obstacleBuilder?.call(pageIndex, pageSize) ?? const [];

    final page = layoutPage(
      document: document,
      startCursor: cursor,
      pageSize: pageSize,
      config: config,
      obstacles: obstacles,
    );

    if (page.isEmpty) break; // safety: avoid infinite loop
    pages.add(page);
    cursor = page.endCursor;
  }

  return pages;
}

/// Resolve a block's spans and base text style.
(List<AttributedSpan>?, TextStyle) _resolveBlock(
  Block block,
  LayoutConfig config,
) {
  return switch (block) {
    ParagraphBlock(:final spans) => (spans, config.baseTextStyle),
    HeadingBlock(:final level, :final spans) => (
        spans,
        config.headingStyle(level)
      ),
    BlockquoteBlock(:final children) => _resolveBlock(
        children.firstOrNull ?? const ParagraphBlock([]),
        config,
      ),
    ListBlock(:final items) when items.isNotEmpty => (
        items.first,
        config.baseTextStyle
      ),
    _ => (null, config.baseTextStyle),
  };
}
