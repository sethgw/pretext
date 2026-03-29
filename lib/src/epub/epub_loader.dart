import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pretext/src/document/attributed_span.dart';
import 'package:pretext/src/document/block.dart';
import 'package:pretext/src/document/document.dart';
import 'package:pretext/src/document/document_cursor.dart';
import 'package:pretext/src/document/span_style.dart';
import 'package:pretext/src/epub/content_parser.dart';
import 'package:pretext/src/epub/css_parser.dart';
import 'package:pretext/src/epub/epub_result.dart';
import 'package:pretext/src/epub/opf_parser.dart';
import 'package:pretext/src/epub/toc_parser.dart';

/// Load an EPUB file from raw bytes and return a parsed [EpubLoadResult].
///
/// The pipeline:
/// 1. Decompress the ZIP archive
/// 2. Parse META-INF/container.xml to find the OPF path
/// 3. Parse the OPF for metadata, manifest, and spine
/// 4. Parse the table of contents (EPUB 3 nav or EPUB 2 NCX)
/// 5. For each spine item: load CSS, convert XHTML to [Chapter]
/// 6. Extract embedded images
/// 7. Assemble into [Document] + TOC + images
EpubLoadResult loadEpub(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);

  // --- Step 1: Find the OPF path ---
  final containerXml = _readString(archive, 'META-INF/container.xml');
  if (containerXml == null) {
    throw const FormatException(
      'Invalid EPUB: missing META-INF/container.xml',
    );
  }
  final opfPath = parseContainerXml(containerXml);
  final opfBasePath = _dirOf(opfPath);

  // --- Step 2: Parse OPF ---
  final opfXml = _readString(archive, opfPath);
  if (opfXml == null) {
    throw FormatException('Invalid EPUB: missing OPF file at $opfPath');
  }
  final opf = parseOpf(opfXml, basePath: opfBasePath);

  // --- Step 3: Parse TOC ---
  final toc = parseToc(
    opf: opf,
    readFile: (path) => _readString(archive, path) ?? '',
  );

  // --- Step 4: Load stylesheets ---
  final stylesheets = _loadStylesheets(archive, opf);

  // --- Step 5: Convert spine items to chapters ---
  final chapters = <Chapter>[];
  final hrefTargets = <String, DocumentCursor>{};
  for (final spineItem in opf.spine) {
    if (!spineItem.linear) continue;

    final manifestItem = opf.manifest[spineItem.idref];
    if (manifestItem == null) continue;

    // Only process XHTML content documents.
    if (!manifestItem.mediaType.contains('xhtml') &&
        !manifestItem.mediaType.contains('html')) {
      continue;
    }

    final xhtml = _readString(archive, manifestItem.href);
    if (xhtml == null) continue;

    // Merge all loaded stylesheets plus any linked from this document.
    final docStyles = Map<String, SpanStyle>.from(stylesheets);
    _mergeLinkedStylesheets(archive, xhtml, manifestItem.href, docStyles);

    final result = parseContentDocument(
      xhtml,
      stylesheet: docStyles.isEmpty ? null : docStyles,
    );
    final chapter = _normalizeChapterAssets(result.chapter, manifestItem.href);

    if (chapter.blocks.isNotEmpty) {
      final chapterIndex = chapters.length;
      chapters.add(chapter);
      hrefTargets[manifestItem.href] = DocumentCursor(
        chapterIndex: chapterIndex,
        blockIndex: 0,
        textOffset: 0,
      );
      for (final anchor in result.anchors.entries) {
        hrefTargets['${manifestItem.href}#${anchor.key}'] = DocumentCursor(
          chapterIndex: chapterIndex,
          blockIndex: anchor.value,
          textOffset: 0,
        );
      }
    }
  }

  // --- Step 6: Extract images ---
  final images = _extractImages(archive, opf);

  // --- Step 7: Assemble result ---
  return EpubLoadResult(
    document: Document(
      chapters: chapters,
      metadata: opf.metadata,
    ),
    tableOfContents: toc,
    images: images,
    hrefTargets: hrefTargets,
  );
}

// ---------------------------------------------------------------------------
// Archive helpers
// ---------------------------------------------------------------------------

/// Read a file from the archive as a UTF-8 string.
String? _readString(Archive archive, String path) {
  // Normalize path: strip leading slash, normalize separators.
  final normalized = path.startsWith('/') ? path.substring(1) : path;

  for (final file in archive.files) {
    if (file.name == normalized && file.isFile) {
      final bytes = file.content as List<int>;
      return utf8.decode(bytes, allowMalformed: true);
    }
  }
  return null;
}

/// Read a file from the archive as raw bytes.
Uint8List? _readBytes(Archive archive, String path) {
  final normalized = path.startsWith('/') ? path.substring(1) : path;

  for (final file in archive.files) {
    if (file.name == normalized && file.isFile) {
      final content = file.content as List<int>;
      return content is Uint8List ? content : Uint8List.fromList(content);
    }
  }
  return null;
}

/// Get the directory portion of a path (e.g., "OEBPS/content.opf" -> "OEBPS/").
String _dirOf(String path) {
  final lastSlash = path.lastIndexOf('/');
  if (lastSlash < 0) return '';
  return path.substring(0, lastSlash + 1);
}

// ---------------------------------------------------------------------------
// Stylesheet loading
// ---------------------------------------------------------------------------

/// Load all CSS files from the manifest.
Map<String, SpanStyle> _loadStylesheets(Archive archive, OpfData opf) {
  final merged = <String, SpanStyle>{};

  for (final item in opf.manifest.values) {
    if (item.mediaType == 'text/css') {
      final css = _readString(archive, item.href);
      if (css != null) {
        final styles = parseStylesheet(css);
        for (final entry in styles.entries) {
          final existing = merged[entry.key];
          merged[entry.key] =
              existing != null ? existing.mergeWith(entry.value) : entry.value;
        }
      }
    }
  }

  return merged;
}

/// Parse `<link rel="stylesheet" href="...">` from XHTML and merge any
/// additional CSS files that weren't in the manifest (or were but provide
/// doc-specific overrides).
void _mergeLinkedStylesheets(
  Archive archive,
  String xhtml,
  String docHref,
  Map<String, SpanStyle> target,
) {
  // Quick regex scan — avoids parsing the entire XHTML doc again.
  final linkRegex = RegExp(
    r"""<link[^>]+rel\s*=\s*["']stylesheet["'][^>]+href\s*=\s*["']([^"']+)["']""",
    caseSensitive: false,
  );

  final docDir = _dirOf(docHref);

  for (final match in linkRegex.allMatches(xhtml)) {
    final href = match.group(1);
    if (href == null) continue;

    final resolvedHref = Uri.parse(docDir).resolve(href).path;
    final css = _readString(archive, resolvedHref);
    if (css != null) {
      final styles = parseStylesheet(css);
      for (final entry in styles.entries) {
        final existing = target[entry.key];
        target[entry.key] =
            existing != null ? existing.mergeWith(entry.value) : entry.value;
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Image extraction
// ---------------------------------------------------------------------------

/// Extract all image files from the EPUB manifest.
Map<String, Uint8List> _extractImages(Archive archive, OpfData opf) {
  final images = <String, Uint8List>{};

  for (final item in opf.manifest.values) {
    if (item.mediaType.startsWith('image/')) {
      final bytes = _readBytes(archive, item.href);
      if (bytes != null) {
        images[item.href] = bytes;
      }
    }
  }

  return images;
}

Chapter _normalizeChapterAssets(Chapter chapter, String docHref) {
  return Chapter(
    title: chapter.title,
    blocks: _normalizeBlocks(chapter.blocks, docHref),
  );
}

List<Block> _normalizeBlocks(List<Block> blocks, String docHref) {
  return blocks.map((block) => _normalizeBlock(block, docHref)).toList(growable: false);
}

Block _normalizeBlock(Block block, String docHref) {
  return switch (block) {
    ParagraphBlock(:final spans) =>
      ParagraphBlock(_normalizeSpans(spans, docHref)),
    HeadingBlock(:final level, :final spans) =>
      HeadingBlock(level: level, spans: _normalizeSpans(spans, docHref)),
    ImageBlock(:final src, :final width, :final height, :final alt) =>
      ImageBlock(
        src: _resolveBookHref(docHref, src),
        width: width,
        height: height,
        alt: alt,
      ),
    BlockquoteBlock(:final children) =>
      BlockquoteBlock(_normalizeBlocks(children, docHref)),
    ListBlock(:final ordered, :final items) =>
      ListBlock(
        ordered: ordered,
        items: items
            .map((item) => _normalizeSpans(item, docHref))
            .toList(growable: false),
      ),
    HorizontalRuleBlock() => block,
    TableBlock(:final caption, :final rows) =>
      TableBlock(
        caption: caption == null ? null : _normalizeSpans(caption, docHref),
        rows: rows
            .map(
              (row) => TableRowData(
                row.cells
                    .map(
                      (cell) => TableCellData(
                        spans: _normalizeSpans(cell.spans, docHref),
                        isHeader: cell.isHeader,
                      ),
                    )
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
      ),
  };
}

List<AttributedSpan> _normalizeSpans(List<AttributedSpan> spans, String docHref) {
  return spans
      .map((span) {
        final href = span.style.href;
        if (href == null || href.isEmpty) {
          return span;
        }
        final resolvedHref = _resolveBookHref(docHref, href);
        if (resolvedHref == href) {
          return span;
        }
        return AttributedSpan(
          span.text,
          style: span.style.copyWith(href: resolvedHref),
        );
      })
      .toList(growable: false);
}

String _resolveBookHref(String baseHref, String href) {
  final trimmed = href.trim();
  if (trimmed.isEmpty) return '';

  final parsed = Uri.parse(trimmed);
  if (parsed.scheme.isNotEmpty && parsed.scheme != 'file') {
    return parsed.toString();
  }

  final resolved = Uri.parse(baseHref).resolve(trimmed);
  if (resolved.scheme.isNotEmpty && resolved.scheme != 'file') {
    return resolved.toString();
  }

  final path = resolved.path.startsWith('/')
      ? resolved.path.substring(1)
      : resolved.path;
  if (resolved.fragment.isEmpty) return path;
  return '$path#${resolved.fragment}';
}
