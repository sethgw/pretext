/// A horizontal interval [left, right].
class Interval {
  final double left;
  final double right;

  const Interval(this.left, this.right);

  double get width => right - left;

  bool get isEmpty => right <= left;

  /// Whether this interval overlaps with [other].
  bool overlaps(Interval other) => left < other.right && right > other.left;

  @override
  String toString() => 'Interval($left, $right)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Interval && left == other.left && right == other.right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// Given a [base] horizontal interval and a list of [blocked] intervals,
/// return the remaining usable text slots.
///
/// This is a direct port of Pretext's `carveTextLineSlots()` — the
/// interval subtraction math that makes obstacle avoidance work.
///
/// Example:
/// ```
/// base:    [80, 420]
/// blocked: [200, 310]
/// result:  [80, 200], [310, 420]
/// ```
///
/// Slots narrower than [minWidth] are discarded — they're too narrow
/// to hold meaningful text.
List<Interval> carveSlots(
  Interval base,
  List<Interval> blocked, {
  double minWidth = 50.0,
}) {
  var slots = [base];

  for (final block in blocked) {
    final next = <Interval>[];
    for (final slot in slots) {
      // No overlap — keep slot as-is
      if (block.right <= slot.left || block.left >= slot.right) {
        next.add(slot);
        continue;
      }
      // Left remainder
      if (block.left > slot.left) {
        next.add(Interval(slot.left, block.left));
      }
      // Right remainder
      if (block.right < slot.right) {
        next.add(Interval(block.right, slot.right));
      }
    }
    slots = next;
  }

  return slots.where((s) => s.width >= minWidth).toList();
}
