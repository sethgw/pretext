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

  // --- Drop cap configuration ---

  /// Whether to render a drop cap at the start of each chapter's first
  /// paragraph.
  final bool enableDropCaps;

  /// How many body-text lines the drop cap letter spans (default: 3).
  final int dropCapLines;

  /// Multiplier on the base font size used to render the drop cap letter
  /// (default: 3.5). The actual font size may be adjusted so the drop cap
  /// exactly spans [dropCapLines] lines.
  final double dropCapFontScale;

  /// Optional override style for the drop cap letter. If null, the base
  /// text style is used (scaled up).
  final TextStyle? dropCapStyle;

  /// Horizontal padding between the drop cap letter and the body text
  /// (in logical pixels).
  final double dropCapPadding;

  // --- Adaptive headline configuration ---

  /// Maximum number of lines a heading is allowed to occupy before the
  /// engine shrinks the font to fit. Set to 0 to disable adaptive sizing.
  final int headingMaxLines;

  /// Minimum scale factor when shrinking a heading (default: 0.6).
  /// The heading font size will never be reduced below
  /// `originalSize * headingMinScale`.
  final double headingMinScale;

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
    this.enableDropCaps = false,
    this.dropCapLines = 3,
    this.dropCapFontScale = 3.5,
    this.dropCapStyle,
    this.dropCapPadding = 6.0,
    this.headingMaxLines = 3,
    this.headingMinScale = 0.6,
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
    bool? enableDropCaps,
    int? dropCapLines,
    double? dropCapFontScale,
    TextStyle? dropCapStyle,
    double? dropCapPadding,
    int? headingMaxLines,
    double? headingMinScale,
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
      enableDropCaps: enableDropCaps ?? this.enableDropCaps,
      dropCapLines: dropCapLines ?? this.dropCapLines,
      dropCapFontScale: dropCapFontScale ?? this.dropCapFontScale,
      dropCapStyle: dropCapStyle ?? this.dropCapStyle,
      dropCapPadding: dropCapPadding ?? this.dropCapPadding,
      headingMaxLines: headingMaxLines ?? this.headingMaxLines,
      headingMinScale: headingMinScale ?? this.headingMinScale,
    );
  }
}
