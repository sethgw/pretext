import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:pretext/src/document/document_cursor.dart';
import 'package:pretext/src/epub/epub_result.dart';
import 'package:pretext/src/widgets/paged_reader.dart';
import 'package:pretext/src/widgets/progress_store.dart';
import 'package:pretext/src/widgets/reader_theme.dart';
import 'package:pretext/src/widgets/toc_drawer.dart';

/// A turnkey swipe-based EPUB reader built on top of [PagedReader].
///
/// Provides:
/// - horizontal page swiping
/// - built-in reader chrome
/// - table of contents drawer navigation
/// - optional progress persistence via [ProgressStore]
/// - automatic decoding of EPUB image assets when possible
class EpubReader extends StatefulWidget {
  final EpubLoadResult book;
  final ReaderTheme theme;
  final ProgressStore? progressStore;
  final String? bookId;
  final String? title;
  final GlobalKey<PagedReaderState>? readerKey;
  final ValueChanged<DocumentCursor>? onCursorChanged;
  final ValueChanged<double>? onProgressChanged;
  final ValueChanged<String>? onExternalLinkTap;

  const EpubReader({
    super.key,
    required this.book,
    this.theme = ReaderTheme.light,
    this.progressStore,
    this.bookId,
    this.title,
    this.readerKey,
    this.onCursorChanged,
    this.onProgressChanged,
    this.onExternalLinkTap,
  });

  @override
  State<EpubReader> createState() => _EpubReaderState();
}

class _EpubReaderState extends State<EpubReader> {
  final _fallbackReaderKey = GlobalKey<PagedReaderState>();
  Map<String, ui.Image> _decodedImages = const {};
  int _imageDecodeGeneration = 0;

  GlobalKey<PagedReaderState> get _readerKey =>
      widget.readerKey ?? _fallbackReaderKey;

  @override
  void initState() {
    super.initState();
    _decodeImages();
  }

  @override
  void didUpdateWidget(EpubReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.book != oldWidget.book) {
      _decodeImages();
    }
  }

  @override
  void dispose() {
    _imageDecodeGeneration++;
    _disposeImages(_decodedImages);
    super.dispose();
  }

  Future<void> _decodeImages() async {
    final generation = ++_imageDecodeGeneration;
    final decodedImages = <String, ui.Image>{};

    for (final entry in widget.book.images.entries) {
      final decoded = await _decodeImage(entry.value);
      if (decoded != null) {
        decodedImages[entry.key] = decoded;
      }
    }

    if (!mounted || generation != _imageDecodeGeneration) {
      _disposeImages(decodedImages);
      return;
    }

    final previousImages = _decodedImages;
    setState(() {
      _decodedImages = decodedImages;
    });
    _disposeImages(previousImages);
  }

  Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } on Object {
      return null;
    }
  }

  void _disposeImages(Map<String, ui.Image> images) {
    for (final image in images.values) {
      image.dispose();
    }
  }

  void _handleTocTap(TocEntry entry) {
    final cursor = widget.book.resolveHref(entry.href);
    if (cursor == null) {
      return;
    }

    Navigator.of(context).maybePop();
    _readerKey.currentState?.goToCursor(cursor);
  }

  void _handleLinkTap(String href) {
    final cursor = widget.book.resolveHref(href);
    if (cursor != null) {
      _readerKey.currentState?.goToCursor(cursor);
      return;
    }
    widget.onExternalLinkTap?.call(href);
  }

  @override
  Widget build(BuildContext context) {
    final readerTheme = widget.theme;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: readerTheme.textColor,
      brightness: readerTheme.brightness,
    );
    final title = widget.title ??
        widget.book.document.metadata?.title ??
        'Untitled Book';

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: readerTheme.backgroundColor,
        canvasColor: readerTheme.backgroundColor,
        dividerColor: readerTheme.ruleColor,
        appBarTheme: AppBarTheme(
          backgroundColor: readerTheme.backgroundColor,
          foregroundColor: readerTheme.textColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        drawerTheme: DrawerThemeData(
          backgroundColor: readerTheme.backgroundColor,
          surfaceTintColor: Colors.transparent,
        ),
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: readerTheme.textColor,
              displayColor: readerTheme.textColor,
              fontFamily: readerTheme.fontFamily,
            ),
      ),
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        drawer: widget.book.tableOfContents.isEmpty
            ? null
            : TocDrawer(
                entries: widget.book.tableOfContents,
                title: title,
                onEntryTapped: _handleTocTap,
              ),
        backgroundColor: readerTheme.backgroundColor,
        body: PagedReader(
          key: _readerKey,
          document: widget.book.document,
          config: readerTheme.toLayoutConfig(),
          backgroundColor: readerTheme.backgroundColor,
          progressStore: widget.progressStore,
          bookId: widget.bookId,
          imageResolver: (src) => _decodedImages[src],
          onCursorChanged: widget.onCursorChanged,
          onProgressChanged: widget.onProgressChanged,
          onLinkTap: _handleLinkTap,
        ),
      ),
    );
  }
}
