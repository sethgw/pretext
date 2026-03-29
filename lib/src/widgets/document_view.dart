import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'package:pretext/src/document/document.dart';
import 'package:pretext/src/document/document_cursor.dart';
import 'package:pretext/src/layout/layout_config.dart';
import 'package:pretext/src/layout/layout_result.dart';
import 'package:pretext/src/layout/page_layout.dart';
import 'package:pretext/src/obstacles/obstacle.dart';
import 'package:pretext/src/rendering/page_painter.dart';

/// A widget that displays a single page of a [Document].
///
/// Lays out text from [startCursor] into a page-sized rectangle,
/// flowing around any [obstacles]. Useful for single-page display
/// or as a building block for custom reader UIs.
class DocumentView extends StatefulWidget {
  final Document document;
  final LayoutConfig config;
  final DocumentCursor startCursor;
  final List<Obstacle> obstacles;
  final Color? backgroundColor;
  final bool debugObstacles;
  final ui.Image? Function(String src)? imageResolver;
  final ValueChanged<String>? onLinkTap;

  const DocumentView({
    super.key,
    required this.document,
    required this.config,
    this.startCursor = const DocumentCursor.zero(),
    this.obstacles = const [],
    this.backgroundColor,
    this.debugObstacles = false,
    this.imageResolver,
    this.onLinkTap,
  });

  @override
  State<DocumentView> createState() => _DocumentViewState();
}

class _DocumentViewState extends State<DocumentView> {
  LayoutPage? _page;
  Size? _pageSize;

  @override
  void didUpdateWidget(DocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.document != oldWidget.document ||
        widget.config != oldWidget.config ||
        widget.startCursor != oldWidget.startCursor ||
        widget.obstacles != oldWidget.obstacles) {
      _disposePage();
      _page = null;
      _pageSize = null;
    }
  }

  @override
  void dispose() {
    _disposePage();
    super.dispose();
  }

  void _disposePage() {
    _page?.dispose();
    _page = null;
    _pageSize = null;
  }

  LayoutPage _getPage(Size pageSize) {
    if (_page == null || _pageSize != pageSize) {
      _disposePage();
      _page = layoutPage(
        document: widget.document,
        startCursor: widget.startCursor,
        pageSize: pageSize,
        config: widget.config,
        obstacles: widget.obstacles,
      );
      _pageSize = pageSize;
    }

    return _page!;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageSize = constraints.biggest;
        final page = _getPage(pageSize);
        final paintedPage = CustomPaint(
          size: pageSize,
          painter: PagePainter(
            page: page,
            backgroundColor: widget.backgroundColor,
            debugObstacles: widget.debugObstacles,
            obstacles: widget.obstacles,
            imageResolver: widget.imageResolver,
          ),
        );

        if (widget.onLinkTap == null) {
          return paintedPage;
        }

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            final href = page.hitTestLink(details.localPosition);
            if (href != null) {
              widget.onLinkTap?.call(href);
            }
          },
          child: paintedPage,
        );
      },
    );
  }
}
