import 'dart:typed_data';

import 'package:pretext/src/document/document.dart';
import 'package:pretext/src/document/document_cursor.dart';

/// A single entry in an EPUB table of contents.
class TocEntry {
  final String title;
  final String href;
  final List<TocEntry> children;

  const TocEntry({
    required this.title,
    required this.href,
    this.children = const [],
  });

  @override
  String toString() => 'TocEntry("$title", href: "$href", '
      'children: ${children.length})';
}

/// The result of loading an EPUB file.
class EpubLoadResult {
  /// The parsed document, ready for layout.
  final Document document;

  /// The table of contents as a tree of entries.
  final List<TocEntry> tableOfContents;

  /// Images keyed by their manifest-relative path.
  /// Values are raw image bytes (JPEG, PNG, GIF, SVG).
  final Map<String, Uint8List> images;

  /// Internal navigation targets keyed by normalized spine href or href fragment.
  ///
  /// Example keys:
  /// - `OEBPS/chapter1.xhtml`
  /// - `OEBPS/chapter1.xhtml#intro`
  final Map<String, DocumentCursor> hrefTargets;

  const EpubLoadResult({
    required this.document,
    this.tableOfContents = const [],
    this.images = const {},
    this.hrefTargets = const {},
  });

  /// Resolve an EPUB href to a [DocumentCursor], if this book knows the target.
  DocumentCursor? resolveHref(String href) {
    final normalized = _normalizeHref(href);
    if (normalized.isEmpty) return null;
    return hrefTargets[normalized] ?? hrefTargets[_stripFragment(normalized)];
  }

  static String _normalizeHref(String href) {
    final trimmed = href.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.parse(trimmed);
    if (uri.scheme.isNotEmpty && uri.scheme != 'file') {
      return uri.toString();
    }

    final path = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    if (uri.fragment.isEmpty) return path;
    return '$path#${uri.fragment}';
  }

  static String _stripFragment(String href) {
    final fragmentIndex = href.indexOf('#');
    if (fragmentIndex < 0) return href;
    return href.substring(0, fragmentIndex);
  }
}
