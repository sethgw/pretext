import 'package:flutter_test/flutter_test.dart';
import 'package:pretext/src/obstacles/interval_solver.dart';

void main() {
  group('Interval', () {
    test('width is right minus left', () {
      expect(const Interval(10, 50).width, 40);
    });

    test('isEmpty when right <= left', () {
      expect(const Interval(10, 10).isEmpty, isTrue);
      expect(const Interval(10, 5).isEmpty, isTrue);
      expect(const Interval(10, 11).isEmpty, isFalse);
    });

    test('overlaps detects intersection', () {
      const a = Interval(10, 50);
      expect(a.overlaps(const Interval(40, 60)), isTrue);
      expect(a.overlaps(const Interval(0, 20)), isTrue);
      expect(a.overlaps(const Interval(50, 60)), isFalse); // touching, not overlapping
      expect(a.overlaps(const Interval(60, 70)), isFalse);
    });
  });

  group('carveSlots', () {
    test('no blocked intervals returns base', () {
      final slots = carveSlots(const Interval(0, 400), []);
      expect(slots, [const Interval(0, 400)]);
    });

    test('single blocked interval splits into two slots', () {
      final slots = carveSlots(
        const Interval(80, 420),
        [const Interval(200, 310)],
      );
      expect(slots.length, 2);
      expect(slots[0], const Interval(80, 200));
      expect(slots[1], const Interval(310, 420));
    });

    test('blocked interval at left edge leaves right slot', () {
      final slots = carveSlots(
        const Interval(0, 400),
        [const Interval(0, 100)],
      );
      expect(slots, [const Interval(100, 400)]);
    });

    test('blocked interval at right edge leaves left slot', () {
      final slots = carveSlots(
        const Interval(0, 400),
        [const Interval(300, 400)],
      );
      expect(slots, [const Interval(0, 300)]);
    });

    test('fully blocked returns empty', () {
      final slots = carveSlots(
        const Interval(0, 400),
        [const Interval(-10, 410)],
      );
      expect(slots, isEmpty);
    });

    test('multiple blocked intervals carve correctly', () {
      final slots = carveSlots(
        const Interval(0, 400),
        [const Interval(50, 100), const Interval(200, 250)],
      );
      expect(slots.length, 3);
      expect(slots[0], const Interval(0, 50));
      expect(slots[1], const Interval(100, 200));
      expect(slots[2], const Interval(250, 400));
    });

    test('narrow remainders are filtered by minWidth', () {
      final slots = carveSlots(
        const Interval(0, 400),
        [const Interval(10, 390)],
        minWidth: 50,
      );
      // Left slot is 10px, right slot is 10px — both below minWidth
      expect(slots, isEmpty);
    });

    test('overlapping blocked intervals merge correctly', () {
      final slots = carveSlots(
        const Interval(0, 400),
        [const Interval(100, 200), const Interval(150, 300)],
      );
      expect(slots.length, 2);
      expect(slots[0], const Interval(0, 100));
      expect(slots[1], const Interval(300, 400));
    });
  });
}
