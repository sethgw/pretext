import 'package:flutter/widgets.dart';

import 'package:pretext/src/layout/layout_config.dart';
import 'package:pretext/src/layout/page_layout.dart';
import 'package:pretext/src/document/document.dart';
import 'package:pretext/src/document/document_cursor.dart';
import 'package:pretext/src/obstacles/obstacle.dart';
import 'package:pretext/src/rendering/page_painter.dart';

/// A widget that displays a single page of a [Document].
///
/// Lays out text from [startCursor] into a page-sized rectangle,
/// flowing around any [obstacles]. Useful for single-page display
/// or as a building block for custom reader UIs.
class DocumentView extends StatelessWidget {
  final Document document;
  final LayoutConfig config;
  final DocumentCursor startCursor;
  final List<Obstacle> obstacles;
  final Color? backgroundColor;
  final bool debugObstacles;

  const DocumentView({
    super.key,
    required this.document,
    required this.config,
    this.startCursor = const DocumentCursor.zero(),
    this.obstacles = const [],
    this.backgroundColor,
    this.debugObstacles = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageSize = constraints.biggest;
        final page = layoutPage(
          document: document,
          startCursor: startCursor,
          pageSize: pageSize,
          config: config,
          obstacles: obstacles,
        );

        return CustomPaint(
          size: pageSize,
          painter: PagePainter(
            page: page,
            backgroundColor: backgroundColor,
            debugObstacles: debugObstacles,
            obstacles: obstacles,
          ),
        );
      },
    );
  }
}
