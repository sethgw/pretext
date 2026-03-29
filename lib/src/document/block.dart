import 'package:pretext/src/document/attributed_span.dart';

/// Sealed block hierarchy — the building blocks of document content.
///
/// A [Document] chapter is a list of [Block]s. Each block represents
/// a distinct content element: a paragraph, heading, image, etc.
sealed class Block {
  const Block();

  /// The total character count of the block's text content.
  /// Used for cursor arithmetic and progress calculation.
  int get textLength;
}

/// A paragraph of rich text.
class ParagraphBlock extends Block {
  final List<AttributedSpan> spans;

  const ParagraphBlock(this.spans);

  /// Convenience for a single plain-text paragraph.
  ParagraphBlock.plain(String text) : spans = [AttributedSpan.plain(text)];

  @override
  int get textLength => spans.fold(0, (sum, s) => sum + s.length);

  /// Get the plain text content of this paragraph.
  String get plainText => spans.map((s) => s.text).join();
}

/// A heading (h1–h6).
class HeadingBlock extends Block {
  final int level;
  final List<AttributedSpan> spans;

  const HeadingBlock({required this.level, required this.spans})
      : assert(level >= 1 && level <= 6);

  @override
  int get textLength => spans.fold(0, (sum, s) => sum + s.length);

  String get plainText => spans.map((s) => s.text).join();
}

/// A block-level image.
class ImageBlock extends Block {
  final String src;
  final double? width;
  final double? height;
  final String? alt;

  const ImageBlock({
    required this.src,
    this.width,
    this.height,
    this.alt,
  });

  @override
  int get textLength => 0;
}

/// A blockquote containing nested blocks.
class BlockquoteBlock extends Block {
  final List<Block> children;

  const BlockquoteBlock(this.children);

  @override
  int get textLength =>
      children.fold(0, (sum, block) => sum + block.textLength);
}

/// An ordered or unordered list.
class ListBlock extends Block {
  final bool ordered;
  final List<List<AttributedSpan>> items;

  const ListBlock({required this.ordered, required this.items});

  @override
  int get textLength => items.fold(
      0, (sum, item) => sum + item.fold(0, (s, span) => s + span.length));
}

/// A horizontal rule / thematic break.
class HorizontalRuleBlock extends Block {
  const HorizontalRuleBlock();

  @override
  int get textLength => 0;
}

/// A single table cell with rich text content.
class TableCellData {
  final List<AttributedSpan> spans;
  final bool isHeader;

  const TableCellData({
    required this.spans,
    this.isHeader = false,
  });

  int get textLength => spans.fold(0, (sum, span) => sum + span.length);

  String get plainText => spans.map((span) => span.text).join();
}

/// A single table row.
class TableRowData {
  final List<TableCellData> cells;

  const TableRowData(this.cells);

  int get textLength =>
      cells.fold(0, (sum, cell) => sum + cell.textLength);
}

/// A block-level table with optional caption and structured rows/cells.
class TableBlock extends Block {
  final List<AttributedSpan>? caption;
  final List<TableRowData> rows;

  const TableBlock({
    this.caption,
    required this.rows,
  });

  int get captionTextLength =>
      caption == null ? 0 : caption!.fold<int>(0, (sum, span) => sum + span.length);

  String? get captionText => caption?.map((span) => span.text).join();

  int get columnCount =>
      rows.fold(0, (maxColumns, row) => row.cells.length > maxColumns ? row.cells.length : maxColumns);

  @override
  int get textLength =>
      captionTextLength + rows.fold(0, (sum, row) => sum + row.textLength);
}
