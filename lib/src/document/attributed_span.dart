import 'package:pretext/src/document/span_style.dart';

/// A run of text with an associated [SpanStyle].
///
/// The building block of rich text content within a [Block].
/// A paragraph is represented as a list of [AttributedSpan]s,
/// where each span carries its own style (bold, italic, link, etc.).
class AttributedSpan {
  final String text;
  final SpanStyle style;

  const AttributedSpan(this.text, {this.style = SpanStyle.normal});

  /// Convenience for plain unstyled text.
  const AttributedSpan.plain(this.text) : style = SpanStyle.normal;

  /// The number of characters in this span.
  int get length => text.length;

  /// Whether this span is empty.
  bool get isEmpty => text.isEmpty;

  /// Create a substring span preserving the style.
  AttributedSpan substring(int start, [int? end]) {
    return AttributedSpan(text.substring(start, end), style: style);
  }

  @override
  String toString() => 'AttributedSpan("$text", style: $style)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttributedSpan && text == other.text && style == other.style;

  @override
  int get hashCode => Object.hash(text, style);
}
