import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';

import 'package:pretext/src/layout/layout_config.dart';

/// Groups visual settings for an EPUB reader.
///
/// Provides built-in light, sepia, and dark themes, plus conversion
/// to [LayoutConfig] for the layout engine. Use [copyWith] to create
/// modified variants (e.g., changing font size or font family).
class ReaderTheme {
  final String name;
  final Color backgroundColor;
  final Color textColor;

  /// Color for horizontal rules and dividers.
  final Color ruleColor;
  final String fontFamily;
  final double fontSize;

  /// Multiplied by [fontSize] to get the line height in logical pixels.
  final double lineHeightMultiplier;
  final EdgeInsets margins;
  final Brightness brightness;

  const ReaderTheme({
    required this.name,
    required this.backgroundColor,
    required this.textColor,
    required this.ruleColor,
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeightMultiplier,
    required this.margins,
    required this.brightness,
  });

  /// Convert to a [LayoutConfig] for the layout engine.
  LayoutConfig toLayoutConfig() {
    final baseStyle = TextStyle(
      color: textColor,
      fontSize: fontSize,
      fontFamily: fontFamily,
      height: lineHeightMultiplier,
    );
    return LayoutConfig(
      baseTextStyle: baseStyle,
      lineHeight: fontSize * lineHeightMultiplier,
      margins: margins,
    );
  }

  /// A clean white theme suitable for daytime reading.
  static const light = ReaderTheme(
    name: 'Light',
    backgroundColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF1A1A1A),
    ruleColor: Color(0x33000000),
    fontFamily: 'Georgia',
    fontSize: 17,
    lineHeightMultiplier: 1.6,
    margins: EdgeInsets.symmetric(horizontal: 28, vertical: 32),
    brightness: Brightness.light,
  );

  /// A warm paper-toned theme that reduces eye strain.
  static const sepia = ReaderTheme(
    name: 'Sepia',
    backgroundColor: Color(0xFFF5EDDA),
    textColor: Color(0xFF5B4636),
    ruleColor: Color(0x335B4636),
    fontFamily: 'Georgia',
    fontSize: 17,
    lineHeightMultiplier: 1.6,
    margins: EdgeInsets.symmetric(horizontal: 28, vertical: 32),
    brightness: Brightness.light,
  );

  /// A dark theme suitable for nighttime reading.
  static const dark = ReaderTheme(
    name: 'Dark',
    backgroundColor: Color(0xFF1A1A1A),
    textColor: Color(0xFFCCCCCC),
    ruleColor: Color(0x33CCCCCC),
    fontFamily: 'Georgia',
    fontSize: 17,
    lineHeightMultiplier: 1.6,
    margins: EdgeInsets.symmetric(horizontal: 28, vertical: 32),
    brightness: Brightness.dark,
  );

  /// Create a modified copy of this theme.
  ReaderTheme copyWith({
    String? name,
    Color? backgroundColor,
    Color? textColor,
    Color? ruleColor,
    String? fontFamily,
    double? fontSize,
    double? lineHeightMultiplier,
    EdgeInsets? margins,
    Brightness? brightness,
  }) {
    return ReaderTheme(
      name: name ?? this.name,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      ruleColor: ruleColor ?? this.ruleColor,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeightMultiplier: lineHeightMultiplier ?? this.lineHeightMultiplier,
      margins: margins ?? this.margins,
      brightness: brightness ?? this.brightness,
    );
  }
}
