import 'package:flutter/painting.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import 'package:pretext/src/document/attributed_span.dart';
import 'package:pretext/src/document/block.dart';
import 'package:pretext/src/document/document.dart';
import 'package:pretext/src/document/span_style.dart';
import 'package:pretext/src/epub/css_parser.dart';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Parse an EPUB XHTML content document into a [Chapter] and anchor map.
///
/// The [xhtml] string is parsed using the lenient HTML5 parser (from
/// `package:html`) since EPUB XHTML is frequently malformed.
///
/// If [stylesheet] is provided, CSS class and element styles are resolved
/// for each element via [resolveElementStyle] and [parseInlineStyle].
///
/// Returns a record containing the parsed [Chapter] and a map of element
/// `id` attributes to their block index (for TOC / fragment linking).
({Chapter chapter, Map<String, int> anchors}) parseContentDocument(
  String xhtml, {
  String? title,
  Map<String, SpanStyle>? stylesheet,
}) {
  final document = html_parser.parse(xhtml);

  // Find <body>, or fall back to the document element.
  final body = document.body ?? document.documentElement;
  if (body == null) {
    return (
      chapter: Chapter(title: title, blocks: const []),
      anchors: const {},
    );
  }

  final context = _ParseContext(stylesheet: stylesheet ?? const {});
  _processBlockChildren(body, context, SpanStyle.normal);

  // Flush any trailing inline content.
  _flushInlineBuffer(context);

  return (
    chapter: Chapter(title: title, blocks: context.blocks),
    anchors: context.anchors,
  );
}

// ---------------------------------------------------------------------------
// Internal parse context
// ---------------------------------------------------------------------------

class _ParseContext {
  final Map<String, SpanStyle> stylesheet;
  final List<Block> blocks = [];
  final Map<String, int> anchors = {};

  /// Accumulator for inline spans being collected for the current implicit
  /// or explicit block.
  final List<AttributedSpan> inlineBuffer = [];

  _ParseContext({required this.stylesheet});
}

// ---------------------------------------------------------------------------
// Block-level element classification
// ---------------------------------------------------------------------------

const _blockElements = <String>{
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'blockquote',
  'ul',
  'ol',
  'hr',
  'img',
  'figure',
  'div',
  'section',
  'article',
  'aside',
  'header',
  'footer',
  'main',
  'nav',
  'pre',
  'table',
};

bool _isBlockElement(html_dom.Node node) {
  if (node is! html_dom.Element) return false;
  return _blockElements.contains(node.localName?.toLowerCase());
}

// ---------------------------------------------------------------------------
// Block processing
// ---------------------------------------------------------------------------

/// Walk children of [parent], producing blocks in [context].
void _processBlockChildren(
  html_dom.Element parent,
  _ParseContext context,
  SpanStyle inheritedStyle,
) {
  for (final child in parent.nodes) {
    if (child is html_dom.Element) {
      final tag = child.localName?.toLowerCase() ?? '';

      if (_isBlockElement(child)) {
        // Flush any accumulated inline content before this block.
        _flushInlineBuffer(context);
        _processBlockElement(child, tag, context, inheritedStyle);
      } else {
        // Inline element — accumulate spans.
        _processInlineNode(child, context, inheritedStyle, false);
      }
    } else if (child is html_dom.Text) {
      _processTextNode(child, context, inheritedStyle, false);
    }
  }
}

/// Process a single block-level element.
void _processBlockElement(
  html_dom.Element element,
  String tag,
  _ParseContext context,
  SpanStyle inheritedStyle,
) {
  // Record anchor ID before processing.
  _recordAnchor(element, context);

  // Resolve CSS for this element.
  final resolvedStyle = _resolveStyle(element, tag, context, inheritedStyle);

  switch (tag) {
    case 'p':
      final spans = _collectInlineSpans(element, context, resolvedStyle, false);
      final normalized = _normalizeSpans(spans);
      if (normalized.isNotEmpty) {
        context.blocks.add(ParagraphBlock(normalized));
      }

    case 'h1':
    case 'h2':
    case 'h3':
    case 'h4':
    case 'h5':
    case 'h6':
      final level = int.parse(tag.substring(1));
      final spans = _collectInlineSpans(element, context, resolvedStyle, false);
      final normalized = _normalizeSpans(spans);
      if (normalized.isNotEmpty) {
        context.blocks
            .add(HeadingBlock(level: level, spans: normalized));
      }

    case 'blockquote':
      final innerContext =
          _ParseContext(stylesheet: context.stylesheet);
      _processBlockChildren(element, innerContext, resolvedStyle);
      _flushInlineBuffer(innerContext);
      if (innerContext.blocks.isNotEmpty) {
        context.blocks.add(BlockquoteBlock(innerContext.blocks));
        // Merge anchors from inner context.
        context.anchors.addAll(innerContext.anchors);
      }

    case 'ul':
    case 'ol':
      final ordered = tag == 'ol';
      final items = <List<AttributedSpan>>[];
      for (final li in element.children) {
        if (li.localName?.toLowerCase() == 'li') {
          _recordAnchor(li, context);
          final spans =
              _collectInlineSpans(li, context, resolvedStyle, false);
          final normalized = _normalizeSpans(spans);
          if (normalized.isNotEmpty) {
            items.add(normalized);
          }
        }
      }
      if (items.isNotEmpty) {
        context.blocks.add(ListBlock(ordered: ordered, items: items));
      }

    case 'hr':
      context.blocks.add(const HorizontalRuleBlock());

    case 'img':
      final block = _imageFromElement(element);
      if (block != null) {
        context.blocks.add(block);
      }

    case 'figure':
      _processFigure(element, context, resolvedStyle);

    case 'pre':
      final spans = _collectInlineSpans(element, context, resolvedStyle, true);
      final normalized = _normalizeSpansPre(spans);
      if (normalized.isNotEmpty) {
        context.blocks.add(ParagraphBlock(normalized));
      }

    case 'table':
      _processTable(element, context, resolvedStyle);

    // Transparent wrapper elements — recurse into children.
    case 'div':
    case 'section':
    case 'article':
    case 'aside':
    case 'header':
    case 'footer':
    case 'main':
    case 'nav':
      _processBlockChildren(element, context, resolvedStyle);
  }
}

// ---------------------------------------------------------------------------
// Inline processing
// ---------------------------------------------------------------------------

/// Collect all inline spans from an element's children.
///
/// Returns a flat list of [AttributedSpan]s. If [preserveWhitespace] is true,
/// whitespace normalization is skipped (for `<pre>` blocks).
List<AttributedSpan> _collectInlineSpans(
  html_dom.Element element,
  _ParseContext context,
  SpanStyle inheritedStyle,
  bool preserveWhitespace,
) {
  final spans = <AttributedSpan>[];
  _walkInlineChildren(element, context, inheritedStyle, preserveWhitespace,
      spans);
  return spans;
}

/// Recursively walk inline children, appending to [spans].
void _walkInlineChildren(
  html_dom.Node parent,
  _ParseContext context,
  SpanStyle inheritedStyle,
  bool preserveWhitespace,
  List<AttributedSpan> spans,
) {
  for (final child in parent.nodes) {
    if (child is html_dom.Text) {
      final text = preserveWhitespace
          ? child.text
          : _collapseWhitespace(child.text);
      if (text.isNotEmpty) {
        spans.add(AttributedSpan(text, style: inheritedStyle));
      }
    } else if (child is html_dom.Element) {
      final tag = child.localName?.toLowerCase() ?? '';
      _recordAnchor(child, context);

      // Resolve style for this inline element.
      final resolvedStyle =
          _resolveInlineStyle(child, tag, context, inheritedStyle);

      if (tag == 'br') {
        spans.add(AttributedSpan('\n', style: inheritedStyle));
      } else if (tag == 'img') {
        // Inline images are rare; just note alt text if present.
        final alt = child.attributes['alt'];
        if (alt != null && alt.isNotEmpty) {
          spans.add(AttributedSpan(alt, style: inheritedStyle));
        }
      } else {
        _walkInlineChildren(
            child, context, resolvedStyle, preserveWhitespace, spans);
      }
    }
  }
}

/// Process an inline node within [context.inlineBuffer] (for mixed content).
void _processInlineNode(
  html_dom.Element element,
  _ParseContext context,
  SpanStyle inheritedStyle,
  bool preserveWhitespace,
) {
  final tag = element.localName?.toLowerCase() ?? '';
  _recordAnchor(element, context);

  final resolvedStyle =
      _resolveInlineStyle(element, tag, context, inheritedStyle);

  if (tag == 'br') {
    context.inlineBuffer.add(AttributedSpan('\n', style: inheritedStyle));
  } else {
    _walkInlineChildren(
        element, context, resolvedStyle, preserveWhitespace,
        context.inlineBuffer);
  }
}

/// Process a text node within [context.inlineBuffer] (for mixed content).
void _processTextNode(
  html_dom.Text textNode,
  _ParseContext context,
  SpanStyle inheritedStyle,
  bool preserveWhitespace,
) {
  final text = preserveWhitespace
      ? textNode.text
      : _collapseWhitespace(textNode.text);
  if (text.isNotEmpty) {
    context.inlineBuffer.add(AttributedSpan(text, style: inheritedStyle));
  }
}

/// Flush any accumulated inline spans in [context.inlineBuffer] into a
/// [ParagraphBlock], if non-empty after normalization.
void _flushInlineBuffer(_ParseContext context) {
  if (context.inlineBuffer.isEmpty) return;

  final normalized = _normalizeSpans(List.of(context.inlineBuffer));
  context.inlineBuffer.clear();

  if (normalized.isNotEmpty) {
    context.blocks.add(ParagraphBlock(normalized));
  }
}

// ---------------------------------------------------------------------------
// Style resolution helpers
// ---------------------------------------------------------------------------

/// Resolve the style for a block-level element by combining stylesheet rules,
/// inline style attribute, and inherited style.
SpanStyle _resolveStyle(
  html_dom.Element element,
  String tag,
  _ParseContext context,
  SpanStyle inheritedStyle,
) {
  var style = inheritedStyle;

  if (context.stylesheet.isNotEmpty) {
    final classes = _getClasses(element);
    final id = element.attributes['id'];
    final cssStyle =
        resolveElementStyle(context.stylesheet, tag, classes, id);
    style = style.mergeWith(cssStyle);
  }

  final inlineStyleAttr = element.attributes['style'];
  if (inlineStyleAttr != null && inlineStyleAttr.isNotEmpty) {
    style = style.mergeWith(parseInlineStyle(inlineStyleAttr));
  }

  return style;
}

/// Resolve style for an inline element, applying tag-based semantic styles
/// on top of CSS and inherited style.
SpanStyle _resolveInlineStyle(
  html_dom.Element element,
  String tag,
  _ParseContext context,
  SpanStyle inheritedStyle,
) {
  var style = inheritedStyle;

  // Apply stylesheet rules.
  if (context.stylesheet.isNotEmpty) {
    final classes = _getClasses(element);
    final id = element.attributes['id'];
    final cssStyle =
        resolveElementStyle(context.stylesheet, tag, classes, id);
    style = style.mergeWith(cssStyle);
  }

  // Apply semantic tag-based styles.
  switch (tag) {
    case 'strong':
    case 'b':
      style = style.mergeWith(const SpanStyle(bold: true));
    case 'em':
    case 'i':
      style = style.mergeWith(const SpanStyle(italic: true));
    case 'a':
      final href = element.attributes['href'];
      if (href != null) {
        style = style.mergeWith(SpanStyle(href: href));
      }
    case 'code':
    case 'tt':
    case 'kbd':
    case 'samp':
      style = style.mergeWith(const SpanStyle(fontFamily: 'monospace'));
    case 'u':
      style = style.mergeWith(
          const SpanStyle(decoration: TextDecoration.underline));
    case 's':
    case 'strike':
    case 'del':
      style = style.mergeWith(
          const SpanStyle(decoration: TextDecoration.lineThrough));
    case 'sup':
    case 'sub':
      style = style.mergeWith(const SpanStyle(fontSizeScale: 0.8));
    case 'span':
      // No semantic style — CSS rules above are sufficient.
      break;
    default:
      // Other inline elements are transparent.
      break;
  }

  // Apply inline style attribute.
  final inlineStyleAttr = element.attributes['style'];
  if (inlineStyleAttr != null && inlineStyleAttr.isNotEmpty) {
    style = style.mergeWith(parseInlineStyle(inlineStyleAttr));
  }

  return style;
}

// ---------------------------------------------------------------------------
// Figure processing
// ---------------------------------------------------------------------------

/// Process a `<figure>` element: extract `<img>` and optional `<figcaption>`.
void _processFigure(
  html_dom.Element figure,
  _ParseContext context,
  SpanStyle inheritedStyle,
) {
  _recordAnchor(figure, context);

  html_dom.Element? imgElement;
  html_dom.Element? captionElement;

  for (final child in figure.children) {
    final tag = child.localName?.toLowerCase();
    if (tag == 'img' && imgElement == null) {
      imgElement = child;
    } else if (tag == 'figcaption' && captionElement == null) {
      captionElement = child;
    }
  }

  if (imgElement != null) {
    String? alt = imgElement.attributes['alt'];

    // If there is a figcaption, use its text as the alt text.
    if (captionElement != null) {
      final captionText = captionElement.text.trim();
      if (captionText.isNotEmpty) {
        alt = captionText;
      }
    }

    final src = imgElement.attributes['src'] ?? '';
    final width = _parseDoubleSafe(imgElement.attributes['width']);
    final height = _parseDoubleSafe(imgElement.attributes['height']);

    context.blocks.add(ImageBlock(
      src: src,
      alt: alt,
      width: width,
      height: height,
    ));
  }
}

// ---------------------------------------------------------------------------
// Table processing
// ---------------------------------------------------------------------------

/// Flatten a table into readable paragraphs so EPUB table content is not lost.
///
/// Captions become their own paragraph block. Each row becomes a paragraph with
/// cells separated by ` | `. Nested block content inside a cell is flattened in
/// reading order, using ` / ` between block fragments within the same cell.
void _processTable(
  html_dom.Element table,
  _ParseContext context,
  SpanStyle inheritedStyle,
) {
  html_dom.Element? caption;
  final rows = <html_dom.Element>[];

  for (final child in table.children) {
    final tag = child.localName?.toLowerCase();
    switch (tag) {
      case 'caption':
        caption ??= child;
      case 'thead':
      case 'tbody':
      case 'tfoot':
        rows.addAll(_collectTableRows(child));
      case 'tr':
        rows.add(child);
    }
  }

  if (caption != null) {
    _recordAnchor(caption, context);
    final captionStyle =
        _resolveStyle(caption, 'caption', context, inheritedStyle);
    final captionSpans = _normalizeSpans(
      _collectTableCellSpans(caption, context, captionStyle),
    );
    if (captionSpans.isNotEmpty) {
      context.blocks.add(ParagraphBlock(captionSpans));
    }
  }

  for (final row in rows) {
    _recordAnchor(row, context);
    final rowSpans = _normalizeSpans(
      _flattenTableRow(row, context, inheritedStyle),
    );
    if (rowSpans.isNotEmpty) {
      context.blocks.add(ParagraphBlock(rowSpans));
    }
  }
}

Iterable<html_dom.Element> _collectTableRows(html_dom.Element parent) sync* {
  for (final child in parent.children) {
    final tag = child.localName?.toLowerCase();
    switch (tag) {
      case 'tr':
        yield child;
      case 'thead':
      case 'tbody':
      case 'tfoot':
        yield* _collectTableRows(child);
    }
  }
}

List<AttributedSpan> _flattenTableRow(
  html_dom.Element row,
  _ParseContext context,
  SpanStyle inheritedStyle,
) {
  final spans = <AttributedSpan>[];
  var wroteCell = false;

  for (final cell in row.children) {
    final tag = cell.localName?.toLowerCase();
    if (tag != 'td' && tag != 'th') continue;

    _recordAnchor(cell, context);
    var cellStyle = _resolveStyle(cell, tag!, context, inheritedStyle);
    if (tag == 'th') {
      cellStyle = cellStyle.mergeWith(const SpanStyle(bold: true));
    }

    final cellSpans = _normalizeSpans(
      _collectTableCellSpans(cell, context, cellStyle),
    );
    if (cellSpans.isEmpty) continue;

    if (wroteCell) {
      spans.add(AttributedSpan(' | ', style: inheritedStyle));
    }
    spans.addAll(cellSpans);
    wroteCell = true;
  }

  return spans;
}

List<AttributedSpan> _collectTableCellSpans(
  html_dom.Element cell,
  _ParseContext context,
  SpanStyle inheritedStyle,
) {
  final spans = <AttributedSpan>[];
  _walkTableCellChildren(cell, context, inheritedStyle, spans);
  return spans;
}

void _walkTableCellChildren(
  html_dom.Node parent,
  _ParseContext context,
  SpanStyle inheritedStyle,
  List<AttributedSpan> spans,
) {
  for (final child in parent.nodes) {
    if (child is html_dom.Text) {
      final text = _collapseWhitespace(child.text);
      if (text.isNotEmpty) {
        spans.add(AttributedSpan(text, style: inheritedStyle));
      }
      continue;
    }

    if (child is! html_dom.Element) continue;

    final tag = child.localName?.toLowerCase() ?? '';
    _recordAnchor(child, context);

    if (tag == 'br') {
      spans.add(AttributedSpan('\n', style: inheritedStyle));
      continue;
    }

    if (tag == 'img') {
      final alt = child.attributes['alt'];
      if (alt != null && alt.isNotEmpty) {
        spans.add(AttributedSpan(alt, style: inheritedStyle));
      }
      continue;
    }

    final resolvedStyle = _isTableCellBoundaryTag(tag)
        ? _resolveStyle(child, tag, context, inheritedStyle)
        : _resolveInlineStyle(child, tag, context, inheritedStyle);
    final childSpans = <AttributedSpan>[];
    _walkTableCellChildren(child, context, resolvedStyle, childSpans);
    final normalized = _normalizeSpans(childSpans);
    if (normalized.isEmpty) continue;

    if (_isTableCellBoundaryTag(tag) && spans.isNotEmpty) {
      spans.add(AttributedSpan(' / ', style: inheritedStyle));
    }
    spans.addAll(normalized);
  }
}

bool _isTableCellBoundaryTag(String tag) {
  switch (tag) {
    case 'caption':
    case 'li':
    case 'table':
    case 'tbody':
    case 'td':
    case 'tfoot':
    case 'th':
    case 'thead':
    case 'tr':
      return true;
    default:
      return _blockElements.contains(tag);
  }
}

// ---------------------------------------------------------------------------
// Image helpers
// ---------------------------------------------------------------------------

ImageBlock? _imageFromElement(html_dom.Element element) {
  final src = element.attributes['src'];
  if (src == null || src.isEmpty) return null;

  return ImageBlock(
    src: src,
    alt: element.attributes['alt'],
    width: _parseDoubleSafe(element.attributes['width']),
    height: _parseDoubleSafe(element.attributes['height']),
  );
}

double? _parseDoubleSafe(String? value) {
  if (value == null || value.isEmpty) return null;
  return double.tryParse(value);
}

// ---------------------------------------------------------------------------
// Whitespace handling
// ---------------------------------------------------------------------------

/// Collapse runs of whitespace (spaces, tabs, newlines) to a single space.
String _collapseWhitespace(String text) {
  return text.replaceAll(RegExp(r'\s+'), ' ');
}

/// Normalize a list of spans: trim leading/trailing whitespace from the
/// combined text, and remove empty spans.
List<AttributedSpan> _normalizeSpans(List<AttributedSpan> spans) {
  if (spans.isEmpty) return const [];

  // Remove completely empty spans first.
  var result = spans.where((s) => s.text.isNotEmpty).toList();
  if (result.isEmpty) return const [];

  // Trim leading whitespace from the first span.
  if (result.first.text.startsWith(' ')) {
    final trimmed = result.first.text.trimLeft();
    if (trimmed.isEmpty) {
      result.removeAt(0);
      if (result.isEmpty) return const [];
      // Recurse in case the next span also starts with whitespace.
      return _normalizeSpans(result);
    }
    result[0] = AttributedSpan(trimmed, style: result.first.style);
  }

  if (result.isEmpty) return const [];

  // Trim trailing whitespace from the last span.
  if (result.last.text.endsWith(' ')) {
    final trimmed = result.last.text.trimRight();
    if (trimmed.isEmpty) {
      result.removeLast();
      if (result.isEmpty) return const [];
      return _normalizeSpans(result);
    }
    result[result.length - 1] =
        AttributedSpan(trimmed, style: result.last.style);
  }

  return result;
}

/// Normalize spans for `<pre>` blocks: remove empty spans but preserve
/// whitespace.
List<AttributedSpan> _normalizeSpansPre(List<AttributedSpan> spans) {
  return spans.where((s) => s.text.isNotEmpty).toList();
}

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

/// Extract the list of CSS classes from an element's `class` attribute.
List<String> _getClasses(html_dom.Element element) {
  final classAttr = element.attributes['class'];
  if (classAttr == null || classAttr.trim().isEmpty) return const [];
  return classAttr.trim().split(RegExp(r'\s+')).toList();
}

/// Record an element's `id` attribute in the anchor map.
void _recordAnchor(html_dom.Element element, _ParseContext context) {
  final id = element.attributes['id'];
  if (id != null && id.isNotEmpty) {
    // Map to the current block count (the index the next block will occupy).
    context.anchors[id] = context.blocks.length;
  }
}
