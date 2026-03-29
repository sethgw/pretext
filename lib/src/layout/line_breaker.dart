import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:pretext/src/document/attributed_span.dart';
import 'package:pretext/src/document/block.dart';
import 'package:pretext/src/document/document_cursor.dart';
import 'package:pretext/src/layout/layout_result.dart';
import 'package:pretext/src/layout/rich_paragraph.dart';

/// The core line-breaking engine — Flutter's adaptation of Pretext's
/// `layoutNextLine()`.
///
/// Uses [dart:ui Paragraph] with `maxLines: 2` for text shaping and
/// line-break computation (HarfBuzz + ICU), then reads the first line's
/// boundary and metrics. This gives us correct line breaking for ALL
/// scripts (Latin, CJK, Arabic, Thai, etc.) while letting us control
/// line widths per-line for obstacle avoidance.
class LineBreaker {
  final TextDirection textDirection;
  final int lookaheadChars;

  const LineBreaker({
    this.textDirection = TextDirection.ltr,
    this.lookaheadChars = 500,
  });

  /// Lay out one line of text from a [ParagraphBlock] or [HeadingBlock],
  /// starting at [textOffset], fitting within [maxWidth].
  ///
  /// Returns `null` if there is no more text to lay out in this block.
  ///
  /// The returned [LayoutLine] has `x: 0, y: 0` — the caller is responsible
  /// for positioning it (page layout handles this).
  LayoutLine? layoutNextLine({
    required List<AttributedSpan> spans,
    required int textOffset,
    required double maxWidth,
    required TextStyle baseStyle,
    required DocumentCursor cursorBase,
  }) {
    // Get the spans starting from textOffset
    final slicedSpans = _sliceSpans(spans, textOffset, lookaheadChars);
    if (slicedSpans.isEmpty) return null;

    // Check if we have any actual text
    final totalChars =
        slicedSpans.fold(0, (sum, s) => sum + s.text.length);
    if (totalChars == 0) return null;

    // Build a measurement paragraph with 2 lines so we can detect overflow
    final measureParagraph = buildRichParagraph(
      spans: slicedSpans,
      baseStyle: baseStyle,
      textDirection: textDirection,
      maxLines: 2,
    );
    measureParagraph.layout(ui.ParagraphConstraints(width: maxWidth));

    final lineMetrics = measureParagraph.getLineMetricsAt(0);
    if (lineMetrics == null) {
      measureParagraph.dispose();
      return null;
    }

    final lineBoundary = measureParagraph
        .getLineBoundary(const ui.TextPosition(offset: 0));
    measureParagraph.dispose();

    // The line boundary end tells us how many characters fit on line 1
    final lineCharCount = lineBoundary.end;
    if (lineCharCount <= 0) return null;

    // Build a tight rendering paragraph with just this line's text
    final renderSpans = _sliceSpans(spans, textOffset, lineCharCount);
    final renderParagraph = buildRichParagraph(
      spans: renderSpans,
      baseStyle: baseStyle,
      textDirection: textDirection,
    );
    renderParagraph.layout(ui.ParagraphConstraints(width: maxWidth));

    final renderMetrics = renderParagraph.getLineMetricsAt(0);
    final width = renderMetrics?.width ?? 0.0;
    final height = lineMetrics.height;
    final ascent = lineMetrics.ascent;
    final baseline = lineMetrics.baseline;

    return LayoutLine(
      paragraph: renderParagraph,
      x: 0,
      y: 0,
      width: width,
      height: height,
      ascent: ascent,
      baseline: baseline,
      start: cursorBase,
      end: cursorBase.advanceBy(lineCharCount),
      hardBreak: lineMetrics.hardBreak,
    );
  }
  /// Slice spans from [startOffset] for up to [maxChars] characters.
  ///
  /// Returns a list of spans that cover the character range
  /// [startOffset, startOffset + maxChars).
  static List<AttributedSpan> _sliceSpans(
    List<AttributedSpan> spans,
    int startOffset,
    int maxChars,
  ) {
    final result = <AttributedSpan>[];
    int currentOffset = 0;
    int charsRemaining = maxChars;

    for (final span in spans) {
      if (charsRemaining <= 0) break;

      final spanEnd = currentOffset + span.length;

      if (spanEnd <= startOffset) {
        // This span is entirely before our start point
        currentOffset = spanEnd;
        continue;
      }

      // Calculate the slice within this span
      final sliceStart =
          startOffset > currentOffset ? startOffset - currentOffset : 0;
      final available = span.length - sliceStart;
      final take = available < charsRemaining ? available : charsRemaining;

      if (take > 0) {
        result.add(span.substring(sliceStart, sliceStart + take));
        charsRemaining -= take;
      }

      currentOffset = spanEnd;
    }

    return result;
  }
}
