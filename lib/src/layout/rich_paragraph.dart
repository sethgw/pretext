import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:pretext/src/document/attributed_span.dart';

/// Build a rich [ui.Paragraph] from attributed spans and a base text style.
ui.Paragraph buildRichParagraph({
  required List<AttributedSpan> spans,
  required TextStyle baseStyle,
  required TextDirection textDirection,
  int? maxLines,
}) {
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(
      textDirection: textDirection,
      maxLines: maxLines,
      fontSize: baseStyle.fontSize,
      fontFamily: baseStyle.fontFamily,
      fontWeight: baseStyle.fontWeight,
      fontStyle: baseStyle.fontStyle,
      height: baseStyle.height,
    ),
  );

  for (final span in spans) {
    builder.pushStyle(span.style.toUiTextStyle(baseStyle));
    builder.addText(span.text);
    builder.pop();
  }

  return builder.build();
}

/// Build and lay out a rich paragraph to the given width.
ui.Paragraph layoutRichParagraph({
  required List<AttributedSpan> spans,
  required TextStyle baseStyle,
  required TextDirection textDirection,
  required double width,
  int? maxLines,
}) {
  final paragraph = buildRichParagraph(
    spans: spans,
    baseStyle: baseStyle,
    textDirection: textDirection,
    maxLines: maxLines,
  );
  paragraph.layout(ui.ParagraphConstraints(width: width));
  return paragraph;
}

/// Measure the max intrinsic width of a rich paragraph.
double measureRichParagraphMaxIntrinsicWidth({
  required List<AttributedSpan> spans,
  required TextStyle baseStyle,
  required TextDirection textDirection,
}) {
  if (spans.isEmpty) return 0.0;

  final paragraph = buildRichParagraph(
    spans: spans,
    baseStyle: baseStyle,
    textDirection: textDirection,
  );
  paragraph.layout(const ui.ParagraphConstraints(width: 100000));
  final width = paragraph.maxIntrinsicWidth;
  paragraph.dispose();
  return width;
}
