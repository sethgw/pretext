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
  final images = <LayoutImage>[];
  final rules = <LayoutRule>[];
  double y = contentRect.top;
  var cursor = startCursor;

  while (y + config.lineHeight <= contentRect.bottom) {
    if (cursor.isAtEnd(document)) break;

    final block = document.blockAt(cursor);
    if (block == null) break;

    // --- ImageBlock: compute rect and add to images list ---
    if (block is ImageBlock) {
      final imgWidth = (block.width ?? contentRect.width)
          .clamp(0.0, contentRect.width);
      final imgHeight = block.height ?? (imgWidth * 0.75); // default 4:3

      if (y + imgHeight <= contentRect.bottom) {
        // Center the image horizontally.
        final imgX = contentRect.left + (contentRect.width - imgWidth) / 2;
        images.add(LayoutImage(
          src: block.src,
          rect: Rect.fromLTWH(imgX, y, imgWidth, imgHeight),
          alt: block.alt,
        ));
        y += imgHeight + config.blockSpacing;
      } else {
        // Image doesn't fit — stop this page.
        break;
      }
      cursor = cursor.nextBlock(document);
      continue;
    }

    // --- HorizontalRuleBlock: draw a rule line ---
    if (block is HorizontalRuleBlock) {
      rules.add(LayoutRule(
        x: contentRect.left,
        y: y + config.lineHeight / 2,
        width: contentRect.width,
      ));
      y += config.lineHeight;
      cursor = cursor.nextBlock(document);
      continue;
    }

    // --- Resolve spans for the current cursor position ---
    final resolved = _resolveBlockAtOffset(block, config, cursor.textOffset);
    if (resolved.spans == null) {
      cursor = cursor.nextBlock(document);
      continue;
    }

    // --- Compute available horizontal slots ---
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
      Interval(contentRect.left + resolved.leftIndent, contentRect.right),
      blocked,
      minWidth: config.minSlotWidth,
    );

    if (slots.isEmpty) {
      y += config.lineHeight;
      continue;
    }

    // --- Fill each available slot with text ---
    bool anyLineProduced = false;
    for (final slot in slots) {
      if (cursor.isAtBlockEnd(document)) break;

      // Re-resolve in case cursor advanced into a new sub-element.
      final current =
          _resolveBlockAtOffset(block, config, cursor.textOffset);
      if (current.spans == null) break;

      final line = lineBreaker.layoutNextLine(
        spans: current.spans!,
        textOffset: current.localOffset,
        maxWidth: slot.width,
        baseStyle: current.style,
        cursorBase: cursor,
      );

      if (line == null) break;

      lines.add(line.copyWith(x: slot.left, y: y));
      cursor = line.end;
      anyLineProduced = true;
    }

    if (!anyLineProduced) {
      y += config.lineHeight;
      continue;
    }

    y += config.lineHeight;

    // If the current block is exhausted, advance to the next block.
    if (cursor.isAtBlockEnd(document)) {
      cursor = cursor.nextBlock(document);
      y += config.blockSpacing;
    }
  }

  return LayoutPage(
    lines: lines,
    images: images,
    rules: rules,
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

// ---------------------------------------------------------------------------
// Block resolution
// ---------------------------------------------------------------------------

/// Resolved spans for a position within a block.
class _ResolvedBlock {
  final List<AttributedSpan>? spans;
  final TextStyle style;
  final int localOffset;
  final double leftIndent;

  const _ResolvedBlock({
    required this.spans,
    required this.style,
    required this.localOffset,
    this.leftIndent = 0,
  });
}

/// Resolve the spans, style, and local offset for a position within [block].
///
/// For compound blocks (ListBlock, BlockquoteBlock), this finds the right
/// sub-element based on [textOffset] and returns the correct local offset
/// for the line breaker.
_ResolvedBlock _resolveBlockAtOffset(
  Block block,
  LayoutConfig config,
  int textOffset,
) {
  return switch (block) {
    ParagraphBlock(:final spans) => _ResolvedBlock(
        spans: spans,
        style: config.baseTextStyle,
        localOffset: textOffset,
      ),
    HeadingBlock(:final level, :final spans) => _ResolvedBlock(
        spans: spans,
        style: config.headingStyle(level),
        localOffset: textOffset,
      ),
    ListBlock() => _resolveListItem(block, config, textOffset),
    BlockquoteBlock() => _resolveBlockquoteChild(block, config, textOffset),
    _ => _ResolvedBlock(
        spans: null,
        style: config.baseTextStyle,
        localOffset: textOffset,
      ),
  };
}

/// Find the current item within a [ListBlock] and return its spans.
_ResolvedBlock _resolveListItem(
  ListBlock block,
  LayoutConfig config,
  int textOffset,
) {
  int consumed = 0;
  for (int i = 0; i < block.items.length; i++) {
    final itemLen =
        block.items[i].fold(0, (sum, span) => sum + span.length);
    if (textOffset < consumed + itemLen) {
      return _ResolvedBlock(
        spans: block.items[i],
        style: config.baseTextStyle,
        localOffset: textOffset - consumed,
        leftIndent: config.listIndent,
      );
    }
    consumed += itemLen;
  }
  return _ResolvedBlock(
    spans: null,
    style: config.baseTextStyle,
    localOffset: 0,
  );
}

/// Find the current child block within a [BlockquoteBlock] and resolve it.
_ResolvedBlock _resolveBlockquoteChild(
  BlockquoteBlock block,
  LayoutConfig config,
  int textOffset,
) {
  int consumed = 0;
  for (int i = 0; i < block.children.length; i++) {
    final childLen = block.children[i].textLength;
    if (textOffset < consumed + childLen) {
      final child = block.children[i];
      final childResolved =
          _resolveBlockAtOffset(child, config, textOffset - consumed);
      return _ResolvedBlock(
        spans: childResolved.spans,
        style: childResolved.style,
        localOffset: childResolved.localOffset,
        leftIndent: childResolved.leftIndent + config.blockquoteIndent,
      );
    }
    consumed += childLen;
  }
  return _ResolvedBlock(
    spans: null,
    style: config.baseTextStyle,
    localOffset: 0,
  );
}
