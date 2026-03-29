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
  final Color? color;
  final String? fontFamily;
  final String? href;
  final TextDecoration? decoration;
  final double? letterSpacing;
  final double? height;
  final FontWeight? fontWeight;

  const SpanStyle({
    this.bold = false,
    this.italic = false,
    this.fontSize,
    this.color,
    this.fontFamily,
    this.href,
    this.decoration,
    this.letterSpacing,
    this.height,
    this.fontWeight,
  });

  static const normal = SpanStyle();

  bool get isLink => href != null;

  /// Merge another style on top of this one. Non-null fields in [other] win.
  SpanStyle mergeWith(SpanStyle other) {
    return SpanStyle(
      bold: other.bold || bold,
      italic: other.italic || italic,
      fontSize: other.fontSize ?? fontSize,
      color: other.color ?? color,
      fontFamily: other.fontFamily ?? fontFamily,
      href: other.href ?? href,
      decoration: other.decoration ?? decoration,
      letterSpacing: other.letterSpacing ?? letterSpacing,
      height: other.height ?? height,
      fontWeight: other.fontWeight ?? fontWeight,
    );
  }

  /// Convert to a Flutter [TextStyle], applying overrides on top of [base].
  TextStyle toTextStyle(TextStyle base) {
    return base.copyWith(
      fontWeight: fontWeight ?? (bold ? FontWeight.bold : null),
      fontStyle: italic ? FontStyle.italic : null,
      fontSize: fontSize,
      color: color,
      fontFamily: fontFamily,
      decoration: decoration,
      letterSpacing: letterSpacing,
      height: height,
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
          color == other.color &&
          fontFamily == other.fontFamily &&
          href == other.href &&
          decoration == other.decoration &&
          letterSpacing == other.letterSpacing &&
          height == other.height &&
          fontWeight == other.fontWeight;

  @override
  int get hashCode => Object.hash(
        bold,
        italic,
        fontSize,
        color,
        fontFamily,
        href,
        decoration,
        letterSpacing,
        height,
        fontWeight,
      );
}
