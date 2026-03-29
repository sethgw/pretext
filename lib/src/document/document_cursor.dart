import 'package:pretext/src/document/document.dart';

/// A position within a [Document].
///
/// Tracks chapter, block, and character offset. Serializable for
/// progress persistence (e.g., saving reading position).
///
/// Inspired by Pretext's `LayoutCursor` — enables cursor handoff
/// between columns, pages, and layout regions.
class DocumentCursor implements Comparable<DocumentCursor> {
  final int chapterIndex;
  final int blockIndex;
  final int textOffset;
  final String? blockData;

  const DocumentCursor({
    required this.chapterIndex,
    required this.blockIndex,
    required this.textOffset,
    this.blockData,
  });

  const DocumentCursor.zero()
      : chapterIndex = 0,
        blockIndex = 0,
        textOffset = 0,
        blockData = null;

  /// Whether this cursor is at the very start of the document.
  bool get isAtStart =>
      chapterIndex == 0 && blockIndex == 0 && textOffset == 0;

  /// Whether this cursor has reached the end of the given [document].
  bool isAtEnd(Document document) {
    if (chapterIndex >= document.chapters.length) return true;
    if (chapterIndex < document.chapters.length - 1) return false;
    final chapter = document.chapters[chapterIndex];
    if (blockIndex >= chapter.blocks.length) return true;
    if (blockIndex < chapter.blocks.length - 1) return false;
    return textOffset >= chapter.blocks[blockIndex].textLength;
  }

  /// Whether the cursor is at the end of its current block.
  bool isAtBlockEnd(Document document) {
    final block = document.blockAt(this);
    if (block == null) return true;
    return textOffset >= block.textLength;
  }

  /// Advance to the start of the next block within the same chapter,
  /// or to the next chapter if this was the last block.
  DocumentCursor nextBlock(Document document) {
    if (chapterIndex >= document.chapters.length) return this;
    final chapter = document.chapters[chapterIndex];
    if (blockIndex + 1 < chapter.blocks.length) {
      return DocumentCursor(
        chapterIndex: chapterIndex,
        blockIndex: blockIndex + 1,
        textOffset: 0,
        blockData: null,
      );
    }
    // Move to next chapter
    return DocumentCursor(
      chapterIndex: chapterIndex + 1,
      blockIndex: 0,
      textOffset: 0,
      blockData: null,
    );
  }

  /// Advance by [chars] characters within the current block.
  DocumentCursor advanceBy(int chars) {
    return DocumentCursor(
      chapterIndex: chapterIndex,
      blockIndex: blockIndex,
      textOffset: textOffset + chars,
      blockData: null,
    );
  }

  /// Compute a 0.0–1.0 progress value within the given [document].
  double progressIn(Document document) {
    final total = document.totalTextLength;
    if (total == 0) return 1.0;

    int consumed = 0;
    for (int c = 0; c < chapterIndex && c < document.chapters.length; c++) {
      consumed += document.chapters[c].textLength;
    }
    if (chapterIndex < document.chapters.length) {
      final chapter = document.chapters[chapterIndex];
      for (int b = 0; b < blockIndex && b < chapter.blocks.length; b++) {
        consumed += chapter.blocks[b].textLength;
      }
      consumed += textOffset;
    }
    return (consumed / total).clamp(0.0, 1.0);
  }

  /// Serialize to a string for persistence.
  String serialize() => blockData == null
      ? '$chapterIndex:$blockIndex:$textOffset'
      : '$chapterIndex:$blockIndex:$textOffset|$blockData';

  /// Deserialize from a string.
  static DocumentCursor deserialize(String s) {
    final blockDataSplit = s.split('|');
    final parts = blockDataSplit.first.split(':');
    if (parts.length != 3) return const DocumentCursor.zero();
    return DocumentCursor(
      chapterIndex: int.tryParse(parts[0]) ?? 0,
      blockIndex: int.tryParse(parts[1]) ?? 0,
      textOffset: int.tryParse(parts[2]) ?? 0,
      blockData: blockDataSplit.length > 1 ? blockDataSplit.sublist(1).join('|') : null,
    );
  }

  @override
  int compareTo(DocumentCursor other) {
    final c = chapterIndex.compareTo(other.chapterIndex);
    if (c != 0) return c;
    final b = blockIndex.compareTo(other.blockIndex);
    if (b != 0) return b;
    final t = textOffset.compareTo(other.textOffset);
    if (t != 0) return t;
    if (blockData == other.blockData) return 0;
    if (blockData == null) return -1;
    if (other.blockData == null) return 1;
    return blockData!.compareTo(other.blockData!);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentCursor &&
          chapterIndex == other.chapterIndex &&
          blockIndex == other.blockIndex &&
          textOffset == other.textOffset &&
          blockData == other.blockData;

  @override
  int get hashCode => Object.hash(chapterIndex, blockIndex, textOffset, blockData);

  @override
  String toString() =>
      'DocumentCursor(ch: $chapterIndex, block: $blockIndex, offset: $textOffset, blockData: $blockData)';
}
