import 'dart:math';

import 'package:pretext/src/obstacles/interval_solver.dart';

/// An obstacle that text must flow around.
///
/// For each horizontal line band, an obstacle reports which horizontal
/// interval it blocks. The layout engine uses this to carve available
/// text slots via [carveSlots].
///
/// Obstacles can be rectangles, circles, or arbitrary polygons —
/// matching the full range of shapes in Pretext's editorial engine.
abstract class Obstacle {
  const Obstacle();

  /// Return the horizontal interval blocked by this obstacle
  /// in the vertical band [bandTop, bandBottom], or `null` if
  /// the obstacle does not intersect this band.
  Interval? horizontalBlockAt(double bandTop, double bandBottom);

  /// Return a copy of this obstacle shifted by [dx] horizontally
  /// and [dy] vertically. Used for multi-column layout where
  /// obstacles must be remapped to column-local coordinates.
  Obstacle shifted({double dx = 0, double dy = 0});
}

/// A rectangular obstacle.
class RectangleObstacle extends Obstacle {
  final double x;
  final double y;
  final double width;
  final double height;
  final double padding;

  const RectangleObstacle({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.padding = 8.0,
  });

  @override
  Interval? horizontalBlockAt(double bandTop, double bandBottom) {
    final top = y - padding;
    final bottom = y + height + padding;
    if (bandBottom <= top || bandTop >= bottom) return null;
    return Interval(x - padding, x + width + padding);
  }

  @override
  RectangleObstacle shifted({double dx = 0, double dy = 0}) {
    return RectangleObstacle(
      x: x + dx,
      y: y + dy,
      width: width,
      height: height,
      padding: padding,
    );
  }
}

/// A circular obstacle.
///
/// Uses the same math as Pretext's `circleIntervalForBand()` to compute
/// the exact horizontal interval blocked at each vertical band.
class CircleObstacle extends Obstacle {
  final double cx;
  final double cy;
  final double r;
  final double horizontalPadding;
  final double verticalPadding;

  const CircleObstacle({
    required this.cx,
    required this.cy,
    required this.r,
    this.horizontalPadding = 12.0,
    this.verticalPadding = 4.0,
  });

  @override
  Interval? horizontalBlockAt(double bandTop, double bandBottom) {
    final top = bandTop - verticalPadding;
    final bottom = bandBottom + verticalPadding;

    // Quick reject: band is entirely above or below the circle
    if (top >= cy + r || bottom <= cy - r) return null;

    // Find the minimum vertical distance from the circle center
    // to the nearest edge of the (padded) band
    final double minDy;
    if (cy >= top && cy <= bottom) {
      minDy = 0.0;
    } else if (cy < top) {
      minDy = top - cy;
    } else {
      minDy = cy - bottom;
    }

    if (minDy >= r) return null;

    // Pythagorean: half-width of the circle at this vertical distance
    final maxDx = sqrt(r * r - minDy * minDy);
    return Interval(
      cx - maxDx - horizontalPadding,
      cx + maxDx + horizontalPadding,
    );
  }

  @override
  CircleObstacle shifted({double dx = 0, double dy = 0}) {
    return CircleObstacle(
      cx: cx + dx,
      cy: cy + dy,
      r: r,
      horizontalPadding: horizontalPadding,
      verticalPadding: verticalPadding,
    );
  }
}

/// A polygonal obstacle defined by a list of points.
///
/// For each line band, scans the polygon edges to find the leftmost
/// and rightmost x-intersections, producing the blocked interval.
class PolygonObstacle extends Obstacle {
  final List<({double x, double y})> points;
  final double horizontalPadding;
  final double verticalPadding;

  const PolygonObstacle({
    required this.points,
    this.horizontalPadding = 8.0,
    this.verticalPadding = 4.0,
  });

  @override
  Interval? horizontalBlockAt(double bandTop, double bandBottom) {
    final sampleTop = bandTop - verticalPadding;
    final sampleBottom = bandBottom + verticalPadding;
    final startY = sampleTop.floor();
    final endY = sampleBottom.ceil();

    double left = double.infinity;
    double right = double.negativeInfinity;

    // Scan at integer y-values across the band
    for (int y = startY; y <= endY; y++) {
      final sampleY = y + 0.5;
      final xs = _polygonXsAtY(sampleY);

      // xs come in pairs: [enter, exit, enter, exit, ...]
      for (int i = 0; i + 1 < xs.length; i += 2) {
        if (xs[i] < left) left = xs[i];
        if (xs[i + 1] > right) right = xs[i + 1];
      }
    }

    if (!left.isFinite || !right.isFinite) return null;
    return Interval(left - horizontalPadding, right + horizontalPadding);
  }

  /// Find all x-intersections of the polygon edges with a horizontal
  /// line at [y], sorted ascending.
  List<double> _polygonXsAtY(double y) {
    final xs = <double>[];
    var a = points.last;

    for (final b in points) {
      if ((a.y <= y && y < b.y) || (b.y <= y && y < a.y)) {
        xs.add(a.x + ((y - a.y) * (b.x - a.x)) / (b.y - a.y));
      }
      a = b;
    }

    xs.sort();
    return xs;
  }

  @override
  PolygonObstacle shifted({double dx = 0, double dy = 0}) {
    return PolygonObstacle(
      points: points.map((p) => (x: p.x + dx, y: p.y + dy)).toList(),
      horizontalPadding: horizontalPadding,
      verticalPadding: verticalPadding,
    );
  }
}
