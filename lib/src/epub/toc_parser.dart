import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:xml/xml.dart';

import 'package:pretext/src/epub/epub_result.dart';
import 'package:pretext/src/epub/opf_parser.dart';

/// Parses an EPUB 2 NCX table of contents document.
///
/// The NCX format uses `<navMap>` containing nested `<navPoint>` elements.
/// Returns an empty list if the document is malformed or has no entries.
List<TocEntry> parseNcx(String xml) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(xml);
  } on XmlException {
    return [];
  }

  final navMaps = document.findAllElements('navMap');
  if (navMaps.isEmpty) return [];

  final navMap = navMaps.first;
  return _parseNavPoints(navMap);
}

/// Recursively extracts [TocEntry] items from `<navPoint>` children of
/// [parent].
List<TocEntry> _parseNavPoints(XmlElement parent) {
  final entries = <TocEntry>[];

  for (final navPoint in parent.childElements) {
    if (navPoint.localName != 'navPoint') continue;

    final labelElements = navPoint.findAllElements('navLabel');
    if (labelElements.isEmpty) continue;
    final textElements = labelElements.first.findAllElements('text');
    if (textElements.isEmpty) continue;
    final title = textElements.first.innerText.trim();

    final contentElements = navPoint.findAllElements('content');
    if (contentElements.isEmpty) continue;
    final href = contentElements.first.getAttribute('src') ?? '';

    final children = _parseNavPoints(navPoint);

    entries.add(TocEntry(title: title, href: href, children: children));
  }

  return entries;
}

/// Parses an EPUB 3 navigation document (XHTML with `<nav epub:type="toc">`).
///
/// Uses the lenient HTML parser since navigation documents are XHTML.
/// Returns an empty list if no `<nav>` with `epub:type="toc"` is found.
List<TocEntry> parseNavDocument(String xhtml) {
  final document = html_parser.parse(xhtml);

  final navElement = _findTocNav(document);
  if (navElement == null) return [];

  // Find the top-level <ol> inside the nav element.
  final ol = navElement.querySelector('ol');
  if (ol == null) return [];

  return _parseOlEntries(ol);
}

/// Finds the `<nav>` element with `epub:type="toc"`.
///
/// The HTML parser may strip namespace prefixes, so we check both
/// `epub:type` and `type` attributes.
html_dom.Element? _findTocNav(html_dom.Document document) {
  for (final nav in document.querySelectorAll('nav')) {
    final epubType = nav.attributes['epub:type'] ?? nav.attributes['type'];
    if (epubType == 'toc') return nav;
  }
  return null;
}

/// Recursively extracts [TocEntry] items from an `<ol>` element containing
/// `<li>` children with `<a>` links and optional nested `<ol>` lists.
List<TocEntry> _parseOlEntries(html_dom.Element ol) {
  final entries = <TocEntry>[];

  for (final li in ol.children.where((e) => e.localName == 'li')) {
    final anchor = li.querySelector('a');
    if (anchor == null) continue;

    final title = anchor.text.trim();
    final href = anchor.attributes['href'] ?? '';

    // Check for nested <ol> for child entries.
    final nestedOl = li.querySelector('ol');
    final children = nestedOl != null ? _parseOlEntries(nestedOl) : <TocEntry>[];

    entries.add(TocEntry(title: title, href: href, children: children));
  }

  return entries;
}

/// High-level TOC parser that picks the best available format.
///
/// Prefers EPUB 3 navigation document over EPUB 2 NCX. The [readFile]
/// callback abstracts file access from the ZIP container — it receives a
/// manifest href path and returns the file contents as a string.
///
/// Returns an empty list if no table of contents is available.
List<TocEntry> parseToc({
  required OpfData opf,
  required String Function(String path) readFile,
}) {
  // Try EPUB 3 nav document first.
  if (opf.navItemId != null) {
    final navItem = opf.manifest[opf.navItemId!];
    if (navItem != null) {
      try {
        final content = readFile(navItem.href);
        final entries = parseNavDocument(content);
        if (entries.isNotEmpty) {
          return _resolveEntryHrefs(entries, navItem.href);
        }
      } on Object {
        // Fall through to NCX.
      }
    }
  }

  // Fallback to EPUB 2 NCX.
  if (opf.tocId != null) {
    final tocItem = opf.manifest[opf.tocId!];
    if (tocItem != null) {
      try {
        final content = readFile(tocItem.href);
        return _resolveEntryHrefs(parseNcx(content), tocItem.href);
      } on Object {
        return [];
      }
    }
  }

  return [];
}

List<TocEntry> _resolveEntryHrefs(List<TocEntry> entries, String basePath) {
  return entries
      .map(
        (entry) => TocEntry(
          title: entry.title,
          href: _resolveHref(basePath, entry.href),
          children: _resolveEntryHrefs(entry.children, basePath),
        ),
      )
      .toList(growable: false);
}

String _resolveHref(String basePath, String href) {
  final trimmed = href.trim();
  if (trimmed.isEmpty) return '';

  final resolved = Uri.parse(basePath).resolve(trimmed);
  if (resolved.scheme.isNotEmpty && resolved.scheme != 'file') {
    return resolved.toString();
  }

  final path = resolved.path.startsWith('/')
      ? resolved.path.substring(1)
      : resolved.path;
  if (resolved.fragment.isEmpty) return path;
  return '$path#${resolved.fragment}';
}
