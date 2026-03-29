import 'package:flutter_test/flutter_test.dart';
import 'package:pretext/src/document/block.dart';
import 'package:pretext/src/document/document.dart';
import 'package:pretext/src/document/document_cursor.dart';

void main() {
  final document = Document(
    chapters: [
      Chapter(blocks: [
        ParagraphBlock.plain('Hello world'), // 11 chars
        ParagraphBlock.plain('Second block'), // 12 chars
      ]),
      Chapter(blocks: [
        ParagraphBlock.plain('Chapter two'), // 11 chars
      ]),
    ],
  );

  group('DocumentCursor', () {
    test('zero cursor is at start', () {
      const cursor = DocumentCursor.zero();
      expect(cursor.isAtStart, isTrue);
      expect(cursor.chapterIndex, 0);
      expect(cursor.blockIndex, 0);
      expect(cursor.textOffset, 0);
    });

    test('isAtEnd detects document end', () {
      // Past last chapter
      const past = DocumentCursor(chapterIndex: 2, blockIndex: 0, textOffset: 0);
      expect(past.isAtEnd(document), isTrue);

      // At start
      const start = DocumentCursor.zero();
      expect(start.isAtEnd(document), isFalse);

      // Past last block of last chapter
      const pastBlock = DocumentCursor(chapterIndex: 1, blockIndex: 1, textOffset: 0);
      expect(pastBlock.isAtEnd(document), isTrue);
    });

    test('isAtBlockEnd detects end of current block', () {
      const atEnd = DocumentCursor(chapterIndex: 0, blockIndex: 0, textOffset: 11);
      expect(atEnd.isAtBlockEnd(document), isTrue);

      const midBlock = DocumentCursor(chapterIndex: 0, blockIndex: 0, textOffset: 5);
      expect(midBlock.isAtBlockEnd(document), isFalse);
    });

    test('nextBlock advances within chapter', () {
      const cursor = DocumentCursor(chapterIndex: 0, blockIndex: 0, textOffset: 11);
      final next = cursor.nextBlock(document);
      expect(next.chapterIndex, 0);
      expect(next.blockIndex, 1);
      expect(next.textOffset, 0);
    });

    test('nextBlock advances to next chapter', () {
      const cursor = DocumentCursor(chapterIndex: 0, blockIndex: 1, textOffset: 12);
      final next = cursor.nextBlock(document);
      expect(next.chapterIndex, 1);
      expect(next.blockIndex, 0);
      expect(next.textOffset, 0);
    });

    test('advanceBy increments textOffset', () {
      const cursor = DocumentCursor(chapterIndex: 0, blockIndex: 0, textOffset: 3);
      final advanced = cursor.advanceBy(5);
      expect(advanced.textOffset, 8);
      expect(advanced.chapterIndex, 0);
      expect(advanced.blockIndex, 0);
    });

    test('progressIn computes 0-1 range', () {
      const start = DocumentCursor.zero();
      expect(start.progressIn(document), 0.0);

      // Total text: 11 + 12 + 11 = 34 chars
      // After first block: 11/34
      const afterFirst = DocumentCursor(chapterIndex: 0, blockIndex: 0, textOffset: 11);
      expect(afterFirst.progressIn(document), closeTo(11 / 34, 0.01));
    });

    test('serialize and deserialize round-trip', () {
      const cursor = DocumentCursor(chapterIndex: 1, blockIndex: 3, textOffset: 42);
      final serialized = cursor.serialize();
      expect(serialized, '1:3:42');

      final deserialized = DocumentCursor.deserialize(serialized);
      expect(deserialized, cursor);
    });

    test('compareTo orders correctly', () {
      const a = DocumentCursor(chapterIndex: 0, blockIndex: 0, textOffset: 5);
      const b = DocumentCursor(chapterIndex: 0, blockIndex: 0, textOffset: 10);
      const c = DocumentCursor(chapterIndex: 0, blockIndex: 1, textOffset: 0);
      const d = DocumentCursor(chapterIndex: 1, blockIndex: 0, textOffset: 0);

      expect(a.compareTo(b), isNegative);
      expect(b.compareTo(a), isPositive);
      expect(a.compareTo(a), isZero);
      expect(b.compareTo(c), isNegative);
      expect(c.compareTo(d), isNegative);
    });
  });
}
