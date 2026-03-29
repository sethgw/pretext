import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:pretext/src/document/attributed_span.dart';
import 'package:pretext/src/document/block.dart';
import 'package:pretext/src/document/document.dart';
import 'package:pretext/src/document/document_cursor.dart';
import 'package:pretext/src/layout/layout_config.dart';
import 'package:pretext/src/layout/layout_result.dart';
import 'package:pretext/src/layout/line_breaker.dart';
import 'package:pretext/src/layout/rich_paragraph.dart';
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
  final dropCaps = <LayoutDropCap>[];
  final tables = <LayoutTable>[];
  double y = contentRect.top;
  var cursor = startCursor;

  // Mutable list of obstacles — drop caps add temporary obstacles.
  final activeObstacles = List<Obstacle>.of(obstacles);

  // Adaptive heading: track the heading style override for the current
  // block so it persists across all lines of the same heading.
  TextStyle? headingStyleOverride;
  int? headingOverrideBlockIndex;
  int? headingOverrideChapterIndex;

  while (y < contentRect.bottom) {
    if (cursor.isAtEnd(document)) break;

    final block = document.blockAt(cursor);
    if (block == null) break;

    // --- ImageBlock: compute rect and add to images list ---
    if (block is ImageBlock) {
      final imgWidth = (block.width ?? contentRect.width)
          .clamp(0.0, contentRect.width)
          .toDouble();
      final imgHeight = (block.height ?? (imgWidth * 0.75)).toDouble();

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
      final ruleHeight = math.max(8.0, config.blockSpacing);
      if (y + ruleHeight > contentRect.bottom) break;

      rules.add(LayoutRule(
        x: contentRect.left,
        y: y + ruleHeight / 2,
        width: contentRect.width,
      ));
      y += ruleHeight;
      cursor = cursor.nextBlock(document);
      continue;
    }

    // --- TableBlock: lay out caption and rows as a real grid ---
    if (block is TableBlock) {
      final tableLayout = _layoutTableBlock(
        block: block,
        cursor: cursor,
        y: y,
        contentRect: contentRect,
        config: config,
        lineBreaker: lineBreaker,
      );
      if (tableLayout == null) break;

      tables.add(tableLayout.table);
      cursor = tableLayout.endCursor;
      y += tableLayout.height;
      if (cursor.isAtBlockEnd(document)) {
        cursor = cursor.nextBlock(document);
        y += config.blockSpacing;
      }
      continue;
    }

    // --- Drop cap detection ---
    // Drop caps apply when: enabled, first block, first character,
    // and the block is a ParagraphBlock with text.
    if (config.enableDropCaps &&
        block is ParagraphBlock &&
        cursor.blockIndex == 0 &&
        cursor.textOffset == 0 &&
        block.plainText.isNotEmpty) {
      final dcResult = _buildDropCap(
        block: block,
        config: config,
        contentRect: contentRect,
        y: y,
        lineBreaker: lineBreaker,
      );
      if (dcResult != null) {
        dropCaps.add(dcResult.layoutDropCap);
        activeObstacles.add(dcResult.obstacle);
        // Advance cursor past the drop cap character(s).
        cursor = cursor.advanceBy(dcResult.charCount);
      }
    }

    // --- Adaptive headline sizing ---
    // Compute the override once at the start of a heading block,
    // then reuse it for all subsequent lines of the same block.
    if (block is HeadingBlock &&
        config.headingMaxLines > 0 &&
        (headingOverrideBlockIndex != cursor.blockIndex ||
            headingOverrideChapterIndex != cursor.chapterIndex)) {
      headingStyleOverride = _adaptHeadingStyle(
        spans: block.spans,
        baseHeadingStyle: config.headingStyle(block.level),
        maxWidth: contentRect.width,
        config: config,
        lineBreaker: lineBreaker,
      );
      headingOverrideBlockIndex = cursor.blockIndex;
      headingOverrideChapterIndex = cursor.chapterIndex;
    } else if (block is! HeadingBlock) {
      // Clear the override when we move past the heading block.
      if (headingStyleOverride != null) {
        headingStyleOverride = null;
        headingOverrideBlockIndex = null;
        headingOverrideChapterIndex = null;
      }
    }

    // --- Resolve spans for the current cursor position ---
    final resolved = _resolveBlockAtOffset(
      block,
      config,
      cursor.textOffset,
      headingStyleOverride: headingStyleOverride,
    );
    if (resolved.spans == null) {
      cursor = cursor.nextBlock(document);
      continue;
    }

    final estimatedBandHeight = _estimatedBandHeight(
      resolved.style,
      config.lineHeight,
    );

    if (y + estimatedBandHeight > contentRect.bottom) break;

    var bandLayout = _layoutTextBand(
      block: block,
      cursor: cursor,
      y: y,
      contentRect: contentRect,
      config: config,
      lineBreaker: lineBreaker,
      obstacles: activeObstacles,
      bandHeight: estimatedBandHeight,
      headingStyleOverride: headingStyleOverride,
    );

    if (!bandLayout.producedContent) {
      y += estimatedBandHeight;
      continue;
    }

    final measuredBandHeight = math.max(
      estimatedBandHeight,
      bandLayout.bandHeight,
    );

    if ((measuredBandHeight - estimatedBandHeight).abs() > 0.5) {
      if (y + measuredBandHeight > contentRect.bottom) break;

      final rerun = _layoutTextBand(
        block: block,
        cursor: cursor,
        y: y,
        contentRect: contentRect,
        config: config,
        lineBreaker: lineBreaker,
        obstacles: activeObstacles,
        bandHeight: measuredBandHeight,
        headingStyleOverride: headingStyleOverride,
      );
      if (rerun.producedContent) {
        bandLayout = rerun;
      }
    }

    if (y + bandLayout.bandHeight > contentRect.bottom) break;

    lines.addAll(bandLayout.lines);
    cursor = cursor.advanceBy(bandLayout.consumedChars);
    y += bandLayout.bandHeight;
    if (!cursor.isAtBlockEnd(document) && bandLayout.trailingSpacing > 0) {
      y += bandLayout.trailingSpacing;
    }

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
    dropCaps: dropCaps,
    tables: tables,
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
  final int segmentLength;
  final double leftIndent;
  final String? markerText;
  final double spacingAfterSegment;
  final bool completesCurrentBlockWhenSegmentEnds;

  const _ResolvedBlock({
    required this.spans,
    required this.style,
    required this.localOffset,
    required this.segmentLength,
    this.leftIndent = 0,
    this.markerText,
    this.spacingAfterSegment = 0,
    this.completesCurrentBlockWhenSegmentEnds = true,
  });
}

class _BandLayout {
  final List<LayoutLine> lines;
  final int consumedChars;
  final double bandHeight;
  final double trailingSpacing;

  const _BandLayout({
    required this.lines,
    required this.consumedChars,
    required this.bandHeight,
    this.trailingSpacing = 0,
  });

  bool get producedContent => lines.isNotEmpty;
}

const _tableCellPadding = 8.0;
const _tableCaptionSpacing = 6.0;
const _tableMinimumColumnWidth = 48.0;

class _TableBlockLayout {
  final LayoutTable table;
  final double height;
  final DocumentCursor endCursor;

  const _TableBlockLayout({
    required this.table,
    required this.height,
    required this.endCursor,
  });
}

class _TableStartState {
  final bool includeCaption;
  final int rowIndex;
  final List<int> cellOffsets;

  const _TableStartState({
    required this.includeCaption,
    required this.rowIndex,
    required this.cellOffsets,
  });
}

class _TableRowFragment {
  final List<LayoutTableCell> cells;
  final double height;
  final List<int> consumedByCell;
  final bool isCompleteRow;

  const _TableRowFragment({
    required this.cells,
    required this.height,
    required this.consumedByCell,
    required this.isCompleteRow,
  });
}

class _MeasuredCellLine {
  final int charsConsumed;
  final double height;

  const _MeasuredCellLine({
    required this.charsConsumed,
    required this.height,
  });
}

class _TableCursorState {
  final int rowIndex;
  final List<int> cellOffsets;

  const _TableCursorState({
    required this.rowIndex,
    required this.cellOffsets,
  });

  String encode() => 'table:$rowIndex:${cellOffsets.join(',')}';

  static _TableCursorState? decode(String? value) {
    if (value == null || !value.startsWith('table:')) return null;
    final parts = value.split(':');
    if (parts.length != 3) return null;

    final rowIndex = int.tryParse(parts[1]);
    if (rowIndex == null) return null;

    final offsets = parts[2].isEmpty
        ? const <int>[]
        : parts[2].split(',').map(int.tryParse).toList();
    if (offsets.any((offset) => offset == null)) return null;

    return _TableCursorState(
      rowIndex: rowIndex,
      cellOffsets: offsets.cast<int>(),
    );
  }
}

/// Resolve the spans, style, and local offset for a position within [block].
///
/// For compound blocks (ListBlock, BlockquoteBlock), this finds the right
/// sub-element based on [textOffset] and returns the correct local offset
/// for the line breaker.
///
/// If [headingStyleOverride] is provided it is used instead of the
/// config-resolved heading style (used by adaptive headline sizing).
_ResolvedBlock _resolveBlockAtOffset(
  Block block,
  LayoutConfig config,
  int textOffset, {
  TextStyle? headingStyleOverride,
}) {
  return switch (block) {
    ParagraphBlock(:final spans) => _ResolvedBlock(
        spans: spans,
        style: config.baseTextStyle,
        localOffset: textOffset,
        segmentLength: spans.fold(0, (sum, span) => sum + span.length),
      ),
    HeadingBlock(:final level, :final spans) => _ResolvedBlock(
        spans: spans,
        style: headingStyleOverride ?? config.headingStyle(level),
        localOffset: textOffset,
        segmentLength: spans.fold(0, (sum, span) => sum + span.length),
      ),
    ListBlock() => _resolveListItem(block, config, textOffset),
    BlockquoteBlock() => _resolveBlockquoteChild(block, config, textOffset),
    _ => _ResolvedBlock(
        spans: null,
        style: config.baseTextStyle,
        localOffset: textOffset,
        segmentLength: 0,
      ),
  };
}

/// Find the current item within a [ListBlock] and return its spans.
_ResolvedBlock _resolveListItem(
  ListBlock block,
  LayoutConfig config,
  int textOffset,
) {
  final nonEmptyItems = <({int index, List<AttributedSpan> spans, int length})>[];
  for (int i = 0; i < block.items.length; i++) {
    final itemLength =
        block.items[i].fold(0, (sum, span) => sum + span.length);
    if (itemLength > 0) {
      nonEmptyItems.add((index: i, spans: block.items[i], length: itemLength));
    }
  }

  int consumed = 0;
  for (int itemIndex = 0; itemIndex < nonEmptyItems.length; itemIndex++) {
    final item = nonEmptyItems[itemIndex];
    if (textOffset < consumed + item.length) {
      final markerText = block.ordered ? '${item.index + 1}.' : '\u2022';
      final isLastItem = itemIndex == nonEmptyItems.length - 1;
      return _ResolvedBlock(
        spans: item.spans,
        style: config.baseTextStyle,
        localOffset: textOffset - consumed,
        segmentLength: item.length,
        leftIndent: config.listIndent,
        markerText: markerText,
        spacingAfterSegment: isLastItem ? 0 : config.blockSpacing,
        completesCurrentBlockWhenSegmentEnds: isLastItem,
      );
    }
    consumed += item.length;
  }

  return _ResolvedBlock(
    spans: null,
    style: config.baseTextStyle,
    localOffset: 0,
    segmentLength: 0,
  );
}

/// Find the current child block within a [BlockquoteBlock] and resolve it.
_ResolvedBlock _resolveBlockquoteChild(
  BlockquoteBlock block,
  LayoutConfig config,
  int textOffset,
) {
  final textChildren = <({int index, Block block, int length})>[];
  for (int i = 0; i < block.children.length; i++) {
    final childLength = block.children[i].textLength;
    if (childLength > 0) {
      textChildren.add((index: i, block: block.children[i], length: childLength));
    }
  }

  int consumed = 0;
  for (int childIndex = 0; childIndex < textChildren.length; childIndex++) {
    final childEntry = textChildren[childIndex];
    if (textOffset < consumed + childEntry.length) {
      final child = childEntry.block;
      final childResolved =
          _resolveBlockAtOffset(child, config, textOffset - consumed);
      final isLastChild = childIndex == textChildren.length - 1;
      final spacingAfterSegment =
          childResolved.spacingAfterSegment +
          (childResolved.completesCurrentBlockWhenSegmentEnds && !isLastChild
              ? config.blockSpacing
              : 0);
      return _ResolvedBlock(
        spans: childResolved.spans,
        style: childResolved.style,
        localOffset: childResolved.localOffset,
        segmentLength: childResolved.segmentLength,
        leftIndent: childResolved.leftIndent + config.blockquoteIndent,
        markerText: childResolved.markerText,
        spacingAfterSegment: spacingAfterSegment,
        completesCurrentBlockWhenSegmentEnds:
            childResolved.completesCurrentBlockWhenSegmentEnds && isLastChild,
      );
    }
    consumed += childEntry.length;
  }
  return _ResolvedBlock(
    spans: null,
    style: config.baseTextStyle,
    localOffset: 0,
    segmentLength: 0,
  );
}

double _estimatedBandHeight(TextStyle style, double fallbackLineHeight) {
  final fontSize = style.fontSize ?? fallbackLineHeight;
  final lineHeight = style.height ?? 1.0;
  final estimated = fontSize * lineHeight;
  return math.max(fallbackLineHeight, estimated);
}

_TableBlockLayout? _layoutTableBlock({
  required TableBlock block,
  required DocumentCursor cursor,
  required double y,
  required Rect contentRect,
  required LayoutConfig config,
  required LineBreaker lineBreaker,
}) {
  if (block.captionTextLength == 0 && block.rows.isEmpty) {
    return null;
  }

  final start = _resolveTableStart(block, cursor);
  final tableWidth = contentRect.width;
  final columnWidths = _computeTableColumnWidths(
    block: block,
    tableWidth: tableWidth,
    config: config,
  );
  final cells = <LayoutTableCell>[];
  Rect? captionRect;
  ui.Paragraph? captionParagraph;
  double currentY = y;
  int consumedChars = 0;
  var rowSpacingPending = false;

  if (start.includeCaption && block.caption != null && block.caption!.isNotEmpty) {
    final captionStyle = config.baseTextStyle.copyWith(
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w600,
    );
    final paragraph = layoutRichParagraph(
      spans: block.caption!,
      baseStyle: captionStyle,
      textDirection: config.textDirection,
      width: tableWidth,
    );
    final captionHeight = math.max(paragraph.height, config.lineHeight);
    final fitsCaption =
        currentY + captionHeight <= contentRect.bottom ||
        (currentY == y && y == contentRect.top);
    if (!fitsCaption) {
      paragraph.dispose();
      return null;
    }

    captionParagraph = paragraph;
    captionRect = Rect.fromLTWH(
      contentRect.left,
      currentY,
      tableWidth,
      captionHeight,
    );
    currentY += captionHeight;
    consumedChars += block.captionTextLength;
    if (start.rowIndex < block.rows.length) {
      rowSpacingPending = true;
    }
  }

  DocumentCursor? partialEndCursor;
  for (int rowIndex = start.rowIndex; rowIndex < block.rows.length; rowIndex++) {
    final rowTop = currentY + (rowSpacingPending ? _tableCaptionSpacing : 0);
    final rowOffsets = rowIndex == start.rowIndex
        ? List<int>.of(start.cellOffsets)
        : List<int>.filled(block.rows[rowIndex].cells.length, 0);
    final rowLayout = _buildTableRowFragment(
      row: block.rows[rowIndex],
      cellOffsets: rowOffsets,
      top: rowTop,
      left: contentRect.left,
      columnWidths: columnWidths,
      config: config,
      lineBreaker: lineBreaker,
      availableHeight: contentRect.bottom - rowTop,
      allowOversizeFirstBand:
          captionParagraph == null && cells.isEmpty && rowTop == contentRect.top,
    );
    if (rowLayout == null) {
      break;
    }

    if (rowSpacingPending) {
      currentY += _tableCaptionSpacing;
      rowSpacingPending = false;
    }
    cells.addAll(rowLayout.cells);
    currentY += rowLayout.height;
    consumedChars += rowLayout.consumedByCell.fold(0, (sum, chars) => sum + chars);

    if (!rowLayout.isCompleteRow) {
      partialEndCursor = DocumentCursor(
        chapterIndex: cursor.chapterIndex,
        blockIndex: cursor.blockIndex,
        textOffset: cursor.textOffset + consumedChars,
        blockData: _TableCursorState(
          rowIndex: rowIndex,
          cellOffsets: [
            for (int i = 0; i < block.rows[rowIndex].cells.length; i++)
              rowOffsets[i] + rowLayout.consumedByCell[i],
          ],
        ).encode(),
      );
      break;
    }
  }

  if (captionParagraph == null && cells.isEmpty) {
    return null;
  }

  final endCursor = partialEndCursor ??
      DocumentCursor(
        chapterIndex: cursor.chapterIndex,
        blockIndex: cursor.blockIndex,
        textOffset: cursor.textOffset + consumedChars,
      );

  return _TableBlockLayout(
    table: LayoutTable(
      rect: Rect.fromLTWH(contentRect.left, y, tableWidth, currentY - y),
      captionRect: captionRect,
      captionParagraph: captionParagraph,
      cells: cells,
    ),
    height: currentY - y,
    endCursor: endCursor,
  );
}

_TableStartState _resolveTableStart(
  TableBlock block,
  DocumentCursor cursor,
) {
  final partialState = _TableCursorState.decode(cursor.blockData);
  if (partialState != null &&
      partialState.rowIndex >= 0 &&
      partialState.rowIndex < block.rows.length) {
    final row = block.rows[partialState.rowIndex];
    final normalizedOffsets = <int>[
      for (int i = 0; i < row.cells.length; i++)
        i < partialState.cellOffsets.length
            ? partialState.cellOffsets[i].clamp(0, row.cells[i].textLength)
            : 0,
    ];
    return _TableStartState(
      includeCaption: false,
      rowIndex: partialState.rowIndex,
      cellOffsets: normalizedOffsets,
    );
  }

  final textOffset = cursor.textOffset;
  final captionLength = block.captionTextLength;
  if (captionLength > 0 && textOffset < captionLength) {
    return _TableStartState(
      includeCaption: true,
      rowIndex: 0,
      cellOffsets: block.rows.isEmpty
          ? const []
          : List<int>.filled(block.rows.first.cells.length, 0),
    );
  }

  var consumed = captionLength;
  for (int rowIndex = 0; rowIndex < block.rows.length; rowIndex++) {
    final rowLength = block.rows[rowIndex].textLength;
    if (textOffset < consumed + rowLength) {
      return _TableStartState(
        includeCaption: false,
        rowIndex: rowIndex,
        cellOffsets: List<int>.filled(block.rows[rowIndex].cells.length, 0),
      );
    }
    consumed += rowLength;
  }

  return _TableStartState(
    includeCaption: false,
    rowIndex: block.rows.length,
    cellOffsets: const [],
  );
}

_TableRowFragment? _buildTableRowFragment({
  required TableRowData row,
  required List<int> cellOffsets,
  required double top,
  required double left,
  required List<double> columnWidths,
  required LayoutConfig config,
  required LineBreaker lineBreaker,
  required double availableHeight,
  required bool allowOversizeFirstBand,
}) {
  final columnCount = columnWidths.length;
  final consumedByCell = List<int>.filled(row.cells.length, 0);
  var textHeight = 0.0;
  var bandCount = 0;

  while (true) {
    final nextBand = <_MeasuredCellLine?>[];
    var bandHeight = 0.0;
    var hasContent = false;

    for (int columnIndex = 0; columnIndex < row.cells.length; columnIndex++) {
      final cell = row.cells[columnIndex];
      final nextOffset = cellOffsets[columnIndex] + consumedByCell[columnIndex];
      if (nextOffset >= cell.textLength) {
        nextBand.add(null);
        continue;
      }

      final baseStyle = cell.isHeader
          ? config.baseTextStyle.copyWith(fontWeight: FontWeight.bold)
          : config.baseTextStyle;
      final line = _measureNextCellLine(
        spans: cell.spans,
        textOffset: nextOffset,
        baseStyle: baseStyle,
        maxWidth: _tableParagraphWidthForColumn(columnWidths, columnIndex),
        lineBreaker: lineBreaker,
      );
      nextBand.add(line);
      if (line != null) {
        hasContent = true;
        bandHeight = math.max(bandHeight, line.height);
      }
    }

    if (!hasContent) break;

    final candidateHeight = _tableCellPadding * 2 + textHeight + bandHeight;
    if (candidateHeight > availableHeight &&
        !(bandCount == 0 && allowOversizeFirstBand)) {
      break;
    }

    textHeight += bandHeight;
    bandCount++;
    for (int columnIndex = 0; columnIndex < row.cells.length; columnIndex++) {
      final line = nextBand[columnIndex];
      if (line != null) {
        consumedByCell[columnIndex] += line.charsConsumed;
      }
    }
  }

  if (consumedByCell.every((chars) => chars == 0)) {
    return null;
  }

  final rowHeight = _tableCellPadding * 2 + textHeight;

  final cells = <LayoutTableCell>[];
  var currentX = left;
  for (int columnIndex = 0; columnIndex < columnCount; columnIndex++) {
    final columnWidth = columnWidths[columnIndex];
    ui.Paragraph? paragraph;
    var isHeader = false;
    if (columnIndex < row.cells.length) {
      final cell = row.cells[columnIndex];
      isHeader = cell.isHeader;
      final consumedChars = consumedByCell[columnIndex];
      if (consumedChars > 0) {
        final baseStyle = cell.isHeader
            ? config.baseTextStyle.copyWith(fontWeight: FontWeight.bold)
            : config.baseTextStyle;
        paragraph = layoutRichParagraph(
          spans: _sliceAttributedSpans(
            cell.spans,
            cellOffsets[columnIndex],
            consumedChars,
          ),
          baseStyle: baseStyle,
          textDirection: config.textDirection,
          width: _tableParagraphWidthForColumn(columnWidths, columnIndex),
        );
      }
    }

    cells.add(LayoutTableCell(
      rect: Rect.fromLTWH(
        currentX,
        top,
        columnWidth,
        rowHeight,
      ),
      paragraph: paragraph,
      isHeader: isHeader,
    ));
    currentX += columnWidth;
  }

  return _TableRowFragment(
    cells: cells,
    height: rowHeight,
    consumedByCell: consumedByCell,
    isCompleteRow: [
      for (int i = 0; i < row.cells.length; i++)
        cellOffsets[i] + consumedByCell[i] >= row.cells[i].textLength,
    ].every((isComplete) => isComplete),
  );
}

List<double> _computeTableColumnWidths({
  required TableBlock block,
  required double tableWidth,
  required LayoutConfig config,
}) {
  final columnCount = math.max(1, block.columnCount);
  if (columnCount == 1) {
    return [tableWidth];
  }

  final minimumColumnWidth =
      math.min(_tableMinimumColumnWidth, tableWidth / columnCount);
  if (tableWidth <= minimumColumnWidth * columnCount + 0.01) {
    return _distributeEvenly(tableWidth, columnCount);
  }

  final desiredWidths = List<double>.filled(columnCount, minimumColumnWidth);
  for (final row in block.rows) {
    for (int columnIndex = 0; columnIndex < row.cells.length; columnIndex++) {
      final cell = row.cells[columnIndex];
      if (cell.spans.isEmpty) continue;

      final baseStyle = cell.isHeader
          ? config.baseTextStyle.copyWith(fontWeight: FontWeight.bold)
          : config.baseTextStyle;
      final intrinsicWidth = measureRichParagraphMaxIntrinsicWidth(
        spans: cell.spans,
        baseStyle: baseStyle,
        textDirection: config.textDirection,
      );
      desiredWidths[columnIndex] = math.max(
        desiredWidths[columnIndex],
        intrinsicWidth + _tableCellPadding * 2,
      );
    }
  }

  return _fitDesiredWidthsToTable(
    desiredWidths: desiredWidths,
    totalWidth: tableWidth,
    minimumWidth: minimumColumnWidth,
  );
}

List<double> _fitDesiredWidthsToTable({
  required List<double> desiredWidths,
  required double totalWidth,
  required double minimumWidth,
}) {
  final columnCount = desiredWidths.length;
  final desiredSum = desiredWidths.fold<double>(0, (sum, width) => sum + width);
  if (desiredSum <= 0) {
    return _distributeEvenly(totalWidth, columnCount);
  }

  if (desiredSum <= totalWidth) {
    final extra = totalWidth - desiredSum;
    final widths = [
      for (final width in desiredWidths)
        width + extra * (width / desiredSum),
    ];
    return _normalizeWidthSum(widths, totalWidth);
  }

  if (minimumWidth * columnCount >= totalWidth - 0.01) {
    return _distributeEvenly(totalWidth, columnCount);
  }

  final widths = List<double>.filled(columnCount, 0);
  final pending = <int>{for (int i = 0; i < columnCount; i++) i};
  var remainingWidth = totalWidth;
  var remainingDesired =
      desiredWidths.fold<double>(0, (sum, width) => sum + width);

  while (pending.isNotEmpty) {
    var assignedMinimum = false;
    final pendingSnapshot = pending.toList();
    for (final index in pendingSnapshot) {
      final scaledWidth = remainingWidth * (desiredWidths[index] / remainingDesired);
      if (scaledWidth <= minimumWidth) {
        widths[index] = minimumWidth;
        remainingWidth -= minimumWidth;
        remainingDesired -= desiredWidths[index];
        pending.remove(index);
        assignedMinimum = true;
      }
    }

    if (!assignedMinimum) {
      for (final index in pending) {
        widths[index] = remainingWidth * (desiredWidths[index] / remainingDesired);
      }
      break;
    }

    if (remainingWidth <= 0 || remainingDesired <= 0) {
      final evenWidth =
          pending.isEmpty ? 0.0 : math.max(1.0, remainingWidth / pending.length);
      for (final index in pending) {
        widths[index] = evenWidth;
      }
      break;
    }
  }

  return _normalizeWidthSum(widths, totalWidth);
}

List<double> _distributeEvenly(double totalWidth, int columnCount) {
  final width = totalWidth / columnCount;
  return List<double>.filled(columnCount, width);
}

List<double> _normalizeWidthSum(List<double> widths, double totalWidth) {
  if (widths.isEmpty) return widths;
  final diff = totalWidth - widths.fold<double>(0, (sum, width) => sum + width);
  widths[widths.length - 1] += diff;
  return widths;
}

double _tableParagraphWidthForColumn(List<double> columnWidths, int columnIndex) {
  return math.max(1.0, columnWidths[columnIndex] - _tableCellPadding * 2);
}

_MeasuredCellLine? _measureNextCellLine({
  required List<AttributedSpan> spans,
  required int textOffset,
  required TextStyle baseStyle,
  required double maxWidth,
  required LineBreaker lineBreaker,
}) {
  final line = lineBreaker.layoutNextLine(
    spans: spans,
    textOffset: textOffset,
    maxWidth: maxWidth,
    baseStyle: baseStyle,
    cursorBase: const DocumentCursor.zero().advanceBy(textOffset),
  );
  if (line == null) return null;

  final charsConsumed = line.end.textOffset - line.start.textOffset;
  final measured = _MeasuredCellLine(
    charsConsumed: charsConsumed,
    height: line.height,
  );
  line.paragraph.dispose();
  return measured;
}

List<AttributedSpan> _sliceAttributedSpans(
  List<AttributedSpan> spans,
  int startOffset,
  int maxChars,
) {
  final result = <AttributedSpan>[];
  var currentOffset = 0;
  var charsRemaining = maxChars;

  for (final span in spans) {
    if (charsRemaining <= 0) break;

    final spanEnd = currentOffset + span.length;
    if (spanEnd <= startOffset) {
      currentOffset = spanEnd;
      continue;
    }

    final sliceStart =
        startOffset > currentOffset ? startOffset - currentOffset : 0;
    final available = span.length - sliceStart;
    final take = math.min(available, charsRemaining);
    if (take > 0) {
      result.add(span.substring(sliceStart, sliceStart + take));
      charsRemaining -= take;
    }

    currentOffset = spanEnd;
  }

  return result;
}

_BandLayout _layoutTextBand({
  required Block block,
  required DocumentCursor cursor,
  required double y,
  required Rect contentRect,
  required LayoutConfig config,
  required LineBreaker lineBreaker,
  required List<Obstacle> obstacles,
  required double bandHeight,
  required TextStyle? headingStyleOverride,
}) {
  final resolved = _resolveBlockAtOffset(
    block,
    config,
    cursor.textOffset,
    headingStyleOverride: headingStyleOverride,
  );
  if (resolved.spans == null) {
    return _BandLayout(lines: const [], consumedChars: 0, bandHeight: bandHeight);
  }

  final blocked = <Interval>[];
  final bandTop = y;
  final bandBottom = y + bandHeight;
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
    return _BandLayout(lines: const [], consumedChars: 0, bandHeight: bandHeight);
  }

  final lines = <LayoutLine>[];
  var currentCursor = cursor;
  var maxHeight = 0.0;
  var markerAdded = false;
  var trailingSpacing = 0.0;

  for (final slot in slots) {
    if (currentCursor.textOffset >= block.textLength) break;

    final current = _resolveBlockAtOffset(
      block,
      config,
      currentCursor.textOffset,
      headingStyleOverride: headingStyleOverride,
    );
    if (current.spans == null) break;

    final line = lineBreaker.layoutNextLine(
      spans: current.spans!,
      textOffset: current.localOffset,
      maxWidth: slot.width,
      baseStyle: current.style,
      cursorBase: currentCursor,
    );
    if (line == null) break;

    final positionedLine = line.copyWith(x: slot.left, y: y);
    lines.add(positionedLine);
    maxHeight = math.max(maxHeight, positionedLine.height);
    final charsConsumed = line.end.textOffset - line.start.textOffset;

    if (!markerAdded &&
        current.markerText != null &&
        current.localOffset == 0) {
      final markerLine = _buildMarkerLine(
        markerText: current.markerText!,
        style: current.style,
        textStartX: contentRect.left + current.leftIndent,
        y: y,
        cursor: currentCursor,
        textDirection: config.textDirection,
      );
      lines.add(markerLine);
      maxHeight = math.max(maxHeight, markerLine.height);
      markerAdded = true;
    }

    currentCursor = line.end;
    final segmentComplete =
        current.localOffset + charsConsumed >= current.segmentLength;
    if (segmentComplete) {
      trailingSpacing = current.spacingAfterSegment;
      break;
    }
    if (line.hardBreak) break;
  }

  return _BandLayout(
    lines: lines,
    consumedChars: currentCursor.textOffset - cursor.textOffset,
    bandHeight: maxHeight == 0 ? bandHeight : maxHeight,
    trailingSpacing: trailingSpacing,
  );
}

LayoutLine _buildMarkerLine({
  required String markerText,
  required TextStyle style,
  required double textStartX,
  required double y,
  required DocumentCursor cursor,
  required TextDirection textDirection,
}) {
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(
      textDirection: textDirection,
      fontSize: style.fontSize,
      fontFamily: style.fontFamily,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      height: style.height,
    ),
  );
  builder.pushStyle(ui.TextStyle(
    color: style.color,
    fontSize: style.fontSize,
    fontWeight: style.fontWeight,
    fontStyle: style.fontStyle,
    fontFamily: style.fontFamily,
    height: style.height,
  ));
  builder.addText(markerText);
  builder.pop();

  final paragraph = builder.build();
  paragraph.layout(const ui.ParagraphConstraints(width: 200));
  final metrics = paragraph.getLineMetricsAt(0);

  final width = metrics?.width ?? paragraph.maxIntrinsicWidth;
  final height = metrics?.height ?? paragraph.height;
  final ascent = metrics?.ascent ?? height;
  final baseline = metrics?.baseline ?? ascent;
  final x = math.max(0.0, textStartX - width - 6.0);

  return LayoutLine(
    paragraph: paragraph,
    x: x,
    y: y,
    width: width,
    height: height,
    ascent: ascent,
    baseline: baseline,
    start: cursor,
    end: cursor,
    hardBreak: false,
  );
}

// ---------------------------------------------------------------------------
// Drop cap support
// ---------------------------------------------------------------------------

/// Result of building a drop cap: the visual element, the obstacle that
/// body text flows around, and the number of characters consumed.
class _DropCapResult {
  final LayoutDropCap layoutDropCap;
  final RectangleObstacle obstacle;
  final int charCount;

  const _DropCapResult({
    required this.layoutDropCap,
    required this.obstacle,
    required this.charCount,
  });
}

/// Build a drop cap for the first character(s) of a paragraph.
///
/// Returns `null` if the paragraph has no text or the drop cap cannot
/// be measured (e.g., the paragraph consists only of whitespace).
_DropCapResult? _buildDropCap({
  required ParagraphBlock block,
  required LayoutConfig config,
  required Rect contentRect,
  required double y,
  required LineBreaker lineBreaker,
}) {
  final plainText = block.plainText;
  if (plainText.isEmpty) return null;

  // Extract the first character.
  const charCount = 1;
  final dropCapChar = plainText.substring(0, charCount);

  // Compute the target height: dropCapLines * lineHeight.
  final targetHeight = config.dropCapLines * config.lineHeight;

  // Determine the style for the drop cap letter.
  final baseStyle = config.dropCapStyle ?? config.baseTextStyle;
  final baseFontSize = baseStyle.fontSize ?? 16.0;

  // Start with the configured scale and adjust to fill targetHeight.
  // We do a quick measurement loop to get the font size right.
  var fontSize = baseFontSize * config.dropCapFontScale;
  late ui.Paragraph dropCapParagraph;
  late double dropCapWidth;
  late double dropCapHeight;

  // Binary-search-like approach: measure, adjust if needed.
  for (int attempt = 0; attempt < 5; attempt++) {
    final style = baseStyle.copyWith(fontSize: fontSize);
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textDirection: config.textDirection,
        fontSize: style.fontSize,
        fontFamily: style.fontFamily,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
        height: style.height,
      ),
    );
    builder.pushStyle(ui.TextStyle(
      color: style.color,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      fontFamily: style.fontFamily,
      height: style.height,
    ));
    builder.addText(dropCapChar);
    builder.pop();

    final p = builder.build();
    p.layout(const ui.ParagraphConstraints(width: double.infinity));
    dropCapWidth = p.maxIntrinsicWidth;
    dropCapHeight = p.height;

    if ((dropCapHeight - targetHeight).abs() < 2.0 || attempt == 4) {
      dropCapParagraph = p;
      break;
    }

    // Scale fontSize proportionally to reach targetHeight.
    final ratio = targetHeight / dropCapHeight;
    fontSize *= ratio;
    p.dispose();
  }

  // Position at the left edge of the content area, at the current y.
  final dcX = contentRect.left;
  final dcY = y;

  // Build the obstacle that text flows around.
  // The obstacle covers the drop cap width + padding, for the height
  // of dropCapLines * lineHeight.
  final obstacle = RectangleObstacle(
    x: dcX,
    y: dcY,
    width: dropCapWidth,
    height: targetHeight,
    padding: config.dropCapPadding,
  );

  return _DropCapResult(
    layoutDropCap: LayoutDropCap(
      paragraph: dropCapParagraph,
      x: dcX,
      y: dcY,
    ),
    obstacle: obstacle,
    charCount: charCount,
  );
}

// ---------------------------------------------------------------------------
// Adaptive headline sizing
// ---------------------------------------------------------------------------

/// Measure how many lines [spans] would occupy at the given [style] and
/// [maxWidth], using the [lineBreaker] for accurate measurement.
int _countLines({
  required List<AttributedSpan> spans,
  required TextStyle style,
  required double maxWidth,
  required LineBreaker lineBreaker,
}) {
  int lineCount = 0;
  int offset = 0;
  final totalLen = spans.fold(0, (sum, s) => sum + s.length);
  const dummyCursor = DocumentCursor.zero();

  while (offset < totalLen) {
    final line = lineBreaker.layoutNextLine(
      spans: spans,
      textOffset: offset,
      maxWidth: maxWidth,
      baseStyle: style,
      cursorBase: dummyCursor.advanceBy(offset),
    );
    if (line == null) break;
    final charsConsumed = line.end.textOffset - line.start.textOffset;
    if (charsConsumed <= 0) break;
    offset += charsConsumed;
    lineCount++;
    // Dispose the measurement paragraph — we don't need it.
    line.paragraph.dispose();
  }

  return lineCount;
}

/// Compute a potentially-scaled-down [TextStyle] for a heading so it
/// fits within [config.headingMaxLines] at the given [maxWidth].
///
/// Returns the original style unmodified if it already fits.
TextStyle _adaptHeadingStyle({
  required List<AttributedSpan> spans,
  required TextStyle baseHeadingStyle,
  required double maxWidth,
  required LayoutConfig config,
  required LineBreaker lineBreaker,
}) {
  if (config.headingMaxLines <= 0) return baseHeadingStyle;

  final originalFontSize = baseHeadingStyle.fontSize ?? 16.0;
  final minFontSize = originalFontSize * config.headingMinScale;
  var currentStyle = baseHeadingStyle;
  var currentFontSize = originalFontSize;

  while (currentFontSize > minFontSize) {
    final lineCount = _countLines(
      spans: spans,
      style: currentStyle,
      maxWidth: maxWidth,
      lineBreaker: lineBreaker,
    );

    if (lineCount <= config.headingMaxLines) {
      return currentStyle;
    }

    // Shrink by 10%.
    currentFontSize *= 0.9;
    if (currentFontSize < minFontSize) {
      currentFontSize = minFontSize;
    }
    currentStyle = baseHeadingStyle.copyWith(fontSize: currentFontSize);
  }

  // Final check at minimum size.
  return currentStyle;
}
