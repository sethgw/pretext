import 'package:flutter/painting.dart';

/// Configuration for the layout engine.
///
/// Controls fonts, sizes, spacing, margins, and theme colors.
/// Passed to all layout functions to determine how text is measured and placed.
class LayoutConfig {
  /// Base text style applied to body paragraphs.
  final TextStyle baseTextStyle;

  /// Line height in logical pixels. This is the vertical distance between
  /// the tops of consecutive lines (not the CSS `line-height` multiplier).
  final double lineHeight;

  /// Vertical spacing between blocks (paragraphs, headings, etc.).
  final double blockSpacing;

  /// Text direction (LTR or RTL).
  final TextDirection textDirection;

  /// Page margins.
  final EdgeInsets margins;

  /// Heading style resolver. Given a heading level (1–6), returns the
  /// TextStyle to use. Falls back to scaled versions of [baseTextStyle].
  final TextStyle Function(int level)? headingStyleResolver;

  /// Maximum characters to pass to a single Paragraph for line-break
  /// measurement. Higher values are more correct for very long words
  /// but slightly slower. 500 is a safe default.
  final int lookaheadChars;

  /// Minimum slot width (in logical pixels) for obstacle-carved text slots.
  /// Slots narrower than this are skipped.
  final double minSlotWidth;

  /// Left indent applied to list items (in logical pixels).
  final double listIndent;

  /// Left indent applied to blockquotes (in logical pixels).
  final double blockquoteIndent;

  const LayoutConfig({
    required this.baseTextStyle,
    required this.lineHeight,
    this.blockSpacing = 12.0,
    this.textDirection = TextDirection.ltr,
    this.margins = const EdgeInsets.all(24.0),
    this.headingStyleResolver,
    this.lookaheadChars = 500,
    this.minSlotWidth = 50.0,
    this.listIndent = 24.0,
    this.blockquoteIndent = 24.0,
  });

  /// Resolve the text style for a heading at the given [level].
  TextStyle headingStyle(int level) {
    if (headingStyleResolver != null) {
      return headingStyleResolver!(level);
    }
    // Default: scale down from 2.0x for h1 to 1.1x for h6
    final scale = 2.0 - (level - 1) * 0.18;
    return baseTextStyle.copyWith(
      fontSize: (baseTextStyle.fontSize ?? 16.0) * scale,
      fontWeight: FontWeight.bold,
    );
  }

  /// The content area after margins are applied.
  Rect contentRect(Size pageSize) {
    return margins.deflateRect(Offset.zero & pageSize);
  }

  LayoutConfig copyWith({
    TextStyle? baseTextStyle,
    double? lineHeight,
    double? blockSpacing,
    TextDirection? textDirection,
    EdgeInsets? margins,
    TextStyle Function(int level)? headingStyleResolver,
    int? lookaheadChars,
    double? minSlotWidth,
    double? listIndent,
    double? blockquoteIndent,
  }) {
    return LayoutConfig(
      baseTextStyle: baseTextStyle ?? this.baseTextStyle,
      lineHeight: lineHeight ?? this.lineHeight,
      blockSpacing: blockSpacing ?? this.blockSpacing,
      textDirection: textDirection ?? this.textDirection,
      margins: margins ?? this.margins,
      headingStyleResolver: headingStyleResolver ?? this.headingStyleResolver,
      lookaheadChars: lookaheadChars ?? this.lookaheadChars,
      minSlotWidth: minSlotWidth ?? this.minSlotWidth,
      listIndent: listIndent ?? this.listIndent,
      blockquoteIndent: blockquoteIndent ?? this.blockquoteIndent,
    );
  }
}
