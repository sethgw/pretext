import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:pretext/src/document/document_cursor.dart';

/// A single laid-out line of text, ready to paint.
///
/// Each line carries its own pre-built [ui.Paragraph] from the layout phase,
/// positioned at ([x], [y]) in page-local coordinates. The paragraph was
/// laid out at the specific slot width during obstacle-aware line breaking,
/// so it renders pixel-perfect when painted at its position.
class LayoutLine {
  /// The pre-built, pre-laid-out paragraph for this line.
  final ui.Paragraph paragraph;

  /// X position in page-local coordinates.
  final double x;

  /// Y position in page-local coordinates (top of line).
  final double y;

  /// The rendered width of this line's text content.
  final double width;

  /// The full height of this line.
  final double height;

  /// Ascent above the baseline.
  final double ascent;

  /// The baseline Y position relative to the line's top.
  final double baseline;

  /// Cursor at the start of this line's text.
  final DocumentCursor start;

  /// Cursor at the end of this line's text (exclusive).
  final DocumentCursor end;

  /// Whether this line ends with a hard break (newline / end of block).
  final bool hardBreak;

  const LayoutLine({
    required this.paragraph,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.ascent,
    required this.baseline,
    required this.start,
    required this.end,
    required this.hardBreak,
  });

  /// The bounding rect of this line in page-local coordinates.
  Rect get rect => Rect.fromLTWH(x, y, width, height);

  LayoutLine copyWith({
    double? x,
    double? y,
  }) {
    return LayoutLine(
      paragraph: paragraph,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      ascent: ascent,
      baseline: baseline,
      start: start,
      end: end,
      hardBreak: hardBreak,
    );
  }
}

/// A positioned block-level image within a page.
class LayoutImage {
  final String src;
  final Rect rect;
  final String? alt;

  const LayoutImage({
    required this.src,
    required this.rect,
    this.alt,
  });

  LayoutImage copyWith({
    Rect? rect,
  }) {
    return LayoutImage(
      src: src,
      rect: rect ?? this.rect,
      alt: alt,
    );
  }
}

/// A horizontal rule positioned on a page.
class LayoutRule {
  final double x;
  final double y;
  final double width;
  final double thickness;

  const LayoutRule({
    required this.x,
    required this.y,
    required this.width,
    this.thickness = 1.0,
  });

  Rect get rect => Rect.fromLTWH(x, y, width, thickness);

  LayoutRule copyWith({
    double? x,
    double? y,
  }) {
    return LayoutRule(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      thickness: thickness,
    );
  }
}

/// A drop cap letter positioned on a page.
///
/// The drop cap is rendered as a separate [ui.Paragraph] that sits at the
/// top-left of the content area, spanning several body-text lines. The
/// surrounding body text flows around it via the obstacle system.
class LayoutDropCap {
  /// The pre-built paragraph containing the drop cap letter.
  final ui.Paragraph paragraph;

  /// X position in page-local coordinates.
  final double x;

  /// Y position in page-local coordinates.
  final double y;

  const LayoutDropCap({
    required this.paragraph,
    required this.x,
    required this.y,
  });
}

/// A complete laid-out page — the output of the layout engine.
///
/// Contains all positioned lines and images, plus the cursor range
/// this page covers (for progress tracking and page navigation).
class LayoutPage {
  /// All positioned text lines on this page.
  final List<LayoutLine> lines;

  /// All positioned images on this page.
  final List<LayoutImage> images;

  /// All horizontal rules on this page.
  final List<LayoutRule> rules;

  /// All drop cap letters on this page.
  final List<LayoutDropCap> dropCaps;

  /// Cursor at the start of this page's content.
  final DocumentCursor startCursor;

  /// Cursor at the end of this page's content (start of next page).
  final DocumentCursor endCursor;

  /// The page dimensions this was laid out for.
  final Size size;

  const LayoutPage({
    required this.lines,
    this.images = const [],
    this.rules = const [],
    this.dropCaps = const [],
    required this.startCursor,
    required this.endCursor,
    required this.size,
  });

  /// Whether this page has any visible content.
  bool get isEmpty =>
      lines.isEmpty &&
      images.isEmpty &&
      rules.isEmpty &&
      dropCaps.isEmpty;
}
