import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Style descriptor for a run of text within a [Block].
///
/// Maps to Flutter [TextStyle] at layout time via [toTextStyle].
/// Designed to be lightweight and mergeable — only non-null fields
/// override the base style.
class SpanStyle {
  final bool bold;
  final bool italic;
  final double? fontSize;
  final double? fontSizeScale;
  final Color? color;
  final String? fontFamily;
  final String? href;
  final TextDecoration? decoration;
  final double? letterSpacing;
  final double? letterSpacingScale;
  final double? height;
  final double? lineHeightPx;
  final FontWeight? fontWeight;

  const SpanStyle({
    this.bold = false,
    this.italic = false,
    this.fontSize,
    this.fontSizeScale,
    this.color,
    this.fontFamily,
    this.href,
    this.decoration,
    this.letterSpacing,
    this.letterSpacingScale,
    this.height,
    this.lineHeightPx,
    this.fontWeight,
  });

  static const normal = SpanStyle();

  bool get isLink => href != null;

  /// Merge another style on top of this one. Non-null fields in [other] win.
  SpanStyle mergeWith(SpanStyle other) {
    final mergedFontSize = _mergeAbsoluteAndScale(
      currentAbsolute: fontSize,
      currentScale: fontSizeScale,
      otherAbsolute: other.fontSize,
      otherScale: other.fontSizeScale,
    );
    final mergedLetterSpacing = _mergeAbsoluteAndScale(
      currentAbsolute: letterSpacing,
      currentScale: letterSpacingScale,
      otherAbsolute: other.letterSpacing,
      otherScale: other.letterSpacingScale,
    );
    final mergedLineHeight = _mergeAbsoluteAndScale(
      currentAbsolute: height,
      currentScale: lineHeightPx,
      otherAbsolute: other.height,
      otherScale: other.lineHeightPx,
    );

    return SpanStyle(
      bold: other.bold || bold,
      italic: other.italic || italic,
      fontSize: mergedFontSize.absolute,
      fontSizeScale: mergedFontSize.scale,
      color: other.color ?? color,
      fontFamily: other.fontFamily ?? fontFamily,
      href: other.href ?? href,
      decoration: other.decoration ?? decoration,
      letterSpacing: mergedLetterSpacing.absolute,
      letterSpacingScale: mergedLetterSpacing.scale,
      height: mergedLineHeight.absolute,
      lineHeightPx: mergedLineHeight.scale,
      fontWeight: other.fontWeight ?? fontWeight,
    );
  }

  /// Convert to a Flutter [TextStyle], applying overrides on top of [base].
  TextStyle toTextStyle(TextStyle base) {
    final resolvedFontSize = fontSize ??
        (fontSizeScale != null && base.fontSize != null
            ? base.fontSize! * fontSizeScale!
            : null);
    final resolvedLetterSpacing = letterSpacing ??
        (letterSpacingScale != null && (resolvedFontSize ?? base.fontSize) != null
            ? (resolvedFontSize ?? base.fontSize!) * letterSpacingScale!
            : null);
    final resolvedHeight = height ??
        (lineHeightPx != null && (resolvedFontSize ?? base.fontSize) != null
            ? lineHeightPx! / (resolvedFontSize ?? base.fontSize!)
            : null);

    return base.copyWith(
      fontWeight: fontWeight ?? (bold ? FontWeight.bold : null),
      fontStyle: italic ? FontStyle.italic : null,
      fontSize: resolvedFontSize,
      color: color,
      fontFamily: fontFamily,
      decoration: decoration,
      letterSpacing: resolvedLetterSpacing,
      height: resolvedHeight,
    );
  }

  /// Convert to a [dart:ui TextStyle] for use with [ParagraphBuilder].
  ui.TextStyle toUiTextStyle(TextStyle base) {
    final merged = toTextStyle(base);
    return ui.TextStyle(
      color: merged.color,
      fontSize: merged.fontSize,
      fontWeight: merged.fontWeight,
      fontStyle: merged.fontStyle,
      fontFamily: merged.fontFamily,
      letterSpacing: merged.letterSpacing,
      height: merged.height,
      decoration: merged.decoration,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpanStyle &&
          bold == other.bold &&
          italic == other.italic &&
          fontSize == other.fontSize &&
          fontSizeScale == other.fontSizeScale &&
          color == other.color &&
          fontFamily == other.fontFamily &&
          href == other.href &&
          decoration == other.decoration &&
          letterSpacing == other.letterSpacing &&
          letterSpacingScale == other.letterSpacingScale &&
          height == other.height &&
          lineHeightPx == other.lineHeightPx &&
          fontWeight == other.fontWeight;

  @override
  int get hashCode => Object.hash(
        bold,
        italic,
        fontSize,
        fontSizeScale,
        color,
        fontFamily,
        href,
        decoration,
        letterSpacing,
        letterSpacingScale,
        height,
        lineHeightPx,
        fontWeight,
      );
}

({double? absolute, double? scale}) _mergeAbsoluteAndScale({
  required double? currentAbsolute,
  required double? currentScale,
  required double? otherAbsolute,
  required double? otherScale,
}) {
  if (otherAbsolute != null) {
    return (absolute: otherAbsolute, scale: null);
  }
  if (otherScale != null) {
    return (absolute: null, scale: otherScale);
  }
  return (absolute: currentAbsolute, scale: currentScale);
}
