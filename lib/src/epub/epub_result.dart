import 'dart:typed_data';

import 'package:pretext/src/document/document.dart';

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

  const EpubLoadResult({
    required this.document,
    this.tableOfContents = const [],
    this.images = const {},
  });
}
