import 'package:flutter/widgets.dart';

import 'package:pretext/src/document/document.dart';
import 'package:pretext/src/document/document_cursor.dart';
import 'package:pretext/src/layout/layout_config.dart';
import 'package:pretext/src/layout/layout_result.dart';
import 'package:pretext/src/layout/page_layout.dart';
import 'package:pretext/src/obstacles/obstacle.dart';
import 'package:pretext/src/rendering/page_painter.dart';
import 'package:pretext/src/widgets/progress_store.dart';

/// A paginated reader widget backed by [PageView].
///
/// Lazily lays out pages on demand and caches them. Supports
/// obstacle builders per page, progress callbacks, and cursor tracking.
///
/// When [progressStore] and [bookId] are provided, the reader will
/// automatically restore the saved reading position on startup and
/// persist the current position on every page change.
///
/// This is the main consumer-facing widget for ebook reading.
class PagedReader extends StatefulWidget {
  final Document document;
  final LayoutConfig config;
  final DocumentCursor? initialCursor;
  final ValueChanged<DocumentCursor>? onCursorChanged;
  final ValueChanged<double>? onProgressChanged;
  final ValueChanged<int>? onPageChanged;
  final List<Obstacle> Function(int pageIndex, Size pageSize)? obstacleBuilder;
  final Color? backgroundColor;
  final bool debugObstacles;

  /// Optional store for persisting reading progress across sessions.
  final ProgressStore? progressStore;

  /// Book identifier used as the key for [progressStore].
  final String? bookId;

  const PagedReader({
    super.key,
    required this.document,
    required this.config,
    this.initialCursor,
    this.onCursorChanged,
    this.onProgressChanged,
    this.onPageChanged,
    this.obstacleBuilder,
    this.backgroundColor,
    this.debugObstacles = false,
    this.progressStore,
    this.bookId,
  });

  @override
  State<PagedReader> createState() => PagedReaderState();
}

class PagedReaderState extends State<PagedReader> {
  final _pageCache = <int, LayoutPage>{};
  final _cursorToPage = <String, int>{};
  late PageController _pageController;
  Size? _lastSize;
  int _currentPageIndex = 0;
  int? _totalPages;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _restoreProgress();
  }

  /// Restore saved reading position from [ProgressStore], if available.
  Future<void> _restoreProgress() async {
    final store = widget.progressStore;
    final bookId = widget.bookId;
    if (store == null || bookId == null) return;

    final cursor = await store.load(bookId);
    if (cursor != null && mounted) {
      goToCursor(cursor);
    }
  }

  /// Persist the current reading position to [ProgressStore], if available.
  void _saveProgress(DocumentCursor cursor) {
    final store = widget.progressStore;
    final bookId = widget.bookId;
    if (store == null || bookId == null) return;

    store.save(bookId, cursor);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PagedReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.document != oldWidget.document ||
        widget.config != oldWidget.config) {
      _invalidateCache();
    }
  }

  void _invalidateCache() {
    _pageCache.clear();
    _cursorToPage.clear();
    _totalPages = null;
    _lastSize = null;
  }

  /// Get or compute the page at [index].
  LayoutPage? _getPage(int index, Size pageSize) {
    // Invalidate cache if size changed
    if (_lastSize != pageSize) {
      _invalidateCache();
      _lastSize = pageSize;
    }

    // Return cached page
    if (_pageCache.containsKey(index)) {
      return _pageCache[index];
    }

    // We need to compute sequentially from the last known page
    // because each page's start cursor depends on the previous page's end cursor
    DocumentCursor cursor;
    if (index == 0) {
      cursor = widget.initialCursor ?? widget.document.startCursor;
    } else {
      final prevPage = _getPage(index - 1, pageSize);
      if (prevPage == null) return null;
      cursor = prevPage.endCursor;
    }

    if (cursor.isAtEnd(widget.document)) {
      _totalPages = index;
      return null;
    }

    final obstacles =
        widget.obstacleBuilder?.call(index, pageSize) ?? const [];

    final page = layoutPage(
      document: widget.document,
      startCursor: cursor,
      pageSize: pageSize,
      config: widget.config,
      obstacles: obstacles,
    );

    if (page.isEmpty) {
      _totalPages = index;
      return null;
    }

    _pageCache[index] = page;
    _cursorToPage[cursor.serialize()] = index;
    return page;
  }

  /// Navigate to the page containing the given cursor.
  void goToCursor(DocumentCursor cursor) {
    final serialized = cursor.serialize();
    if (_cursorToPage.containsKey(serialized)) {
      final pageIndex = _cursorToPage[serialized]!;
      _pageController.jumpToPage(pageIndex);
      return;
    }

    // Linear scan to find the page (could optimize with binary search)
    if (_lastSize == null) return;
    for (int i = 0; i < (_totalPages ?? 10000); i++) {
      final page = _getPage(i, _lastSize!);
      if (page == null) break;
      if (cursor.compareTo(page.startCursor) >= 0 &&
          cursor.compareTo(page.endCursor) < 0) {
        _pageController.jumpToPage(i);
        return;
      }
    }
  }

  /// The current page index.
  int get currentPageIndex => _currentPageIndex;

  /// The total number of pages (null if not yet computed).
  int? get totalPages => _totalPages;

  /// The current reading progress (0.0–1.0).
  double get progress {
    if (_lastSize == null) return 0.0;
    final page = _getPage(_currentPageIndex, _lastSize!);
    if (page == null) return 1.0;
    return page.endCursor.progressIn(widget.document);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageSize = constraints.biggest;

        return PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentPageIndex = index;
            });

            final page = _getPage(index, pageSize);
            if (page != null) {
              widget.onCursorChanged?.call(page.startCursor);
              widget.onProgressChanged
                  ?.call(page.endCursor.progressIn(widget.document));
              _saveProgress(page.startCursor);
            }
            widget.onPageChanged?.call(index);
          },
          itemBuilder: (context, index) {
            final page = _getPage(index, pageSize);
            if (page == null) return null;

            final obstacles = widget.obstacleBuilder?.call(index, pageSize) ??
                const [];

            return CustomPaint(
              size: pageSize,
              painter: PagePainter(
                page: page,
                backgroundColor: widget.backgroundColor,
                debugObstacles: widget.debugObstacles,
                obstacles: obstacles,
              ),
            );
          },
        );
      },
    );
  }
}
