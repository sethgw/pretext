import 'package:pretext/src/document/block.dart';
import 'package:pretext/src/document/document_cursor.dart';

/// Metadata about a document (title, author, etc.).
class DocumentMetadata {
  final String? title;
  final String? author;
  final String? language;
  final String? publisher;

  const DocumentMetadata({this.title, this.author, this.language, this.publisher});
}

/// A chapter within a document.
class Chapter {
  final String? title;
  final List<Block> blocks;

  const Chapter({this.title, required this.blocks});

  /// Total character count across all blocks.
  int get textLength =>
      blocks.fold(0, (sum, block) => sum + block.textLength);
}

/// A complete document composed of chapters.
///
/// This is the top-level input to the layout engine. A [Document] can be
/// constructed manually, parsed from an EPUB, or built from any structured
/// text source.
class Document {
  final List<Chapter> chapters;
  final DocumentMetadata? metadata;

  const Document({required this.chapters, this.metadata});

  /// Convenience for a single-chapter document.
  Document.singleChapter(List<Block> blocks, {this.metadata})
      : chapters = [Chapter(blocks: blocks)];

  /// Total character count across all chapters.
  int get totalTextLength =>
      chapters.fold(0, (sum, ch) => sum + ch.textLength);

  /// Get the block at the given cursor position, or null if past the end.
  Block? blockAt(DocumentCursor cursor) {
    if (cursor.chapterIndex >= chapters.length) return null;
    final chapter = chapters[cursor.chapterIndex];
    if (cursor.blockIndex >= chapter.blocks.length) return null;
    return chapter.blocks[cursor.blockIndex];
  }

  /// Total number of blocks across all chapters.
  int get totalBlockCount =>
      chapters.fold(0, (sum, ch) => sum + ch.blocks.length);

  /// A cursor pointing to the very start of the document.
  DocumentCursor get startCursor => const DocumentCursor.zero();

  /// A cursor pointing past the end of the document.
  DocumentCursor get endCursor {
    if (chapters.isEmpty) return const DocumentCursor.zero();
    final lastChapter = chapters.length - 1;
    final lastBlock = chapters[lastChapter].blocks.length;
    return DocumentCursor(
      chapterIndex: lastChapter,
      blockIndex: lastBlock,
      textOffset: 0,
    );
  }
}
