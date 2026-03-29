# pretext

`pretext` is a native Flutter text layout engine for paginated reading surfaces.

It is built for reader-style interfaces where text cannot just live in a single scrolling column. The package gives you native pagination, obstacle-aware flow, EPUB parsing, and a swipe-based reader surface without WebView.

## Highlights

- obstacle-aware text flow around rectangles, circles, and polygons
- swipe-based pagination with lazy page layout
- multi-column layout with cursor handoff
- EPUB loading, TOC parsing, image extraction, and href target resolution
- a turnkey `EpubReader` widget on top of `PagedReader`
- saved reading progress hooks and built-in reader themes
- link hit testing for internal EPUB jumps and external-link callbacks

## Install

The package is currently hosted from GitHub.

```yaml
dependencies:
  pretext:
    git:
      url: git@github.com:sethgw/pretext.git
      ref: v0.4.0
```

If you prefer HTTPS:

```yaml
dependencies:
  pretext:
    git:
      url: https://github.com/sethgw/pretext.git
      ref: v0.4.0
```

## Quick Start

Load an EPUB from bytes:

```dart
import 'dart:typed_data';

import 'package:pretext/pretext.dart';

EpubLoadResult openBook(Uint8List bytes) {
  return loadEpub(bytes);
}
```

Render it in a swipeable reader:

```dart
import 'package:flutter/material.dart';
import 'package:pretext/pretext.dart';

class ReaderScreen extends StatelessWidget {
  final EpubLoadResult book;

  const ReaderScreen({
    super.key,
    required this.book,
  });

  @override
  Widget build(BuildContext context) {
    return EpubReader(
      book: book,
      theme: ReaderTheme.sepia,
      bookId: 'demo-book',
      onExternalLinkTap: (href) {
        debugPrint('Open externally: $href');
      },
    );
  }
}
```

If you want lower-level control, use `PagedReader`, `DocumentView`, `layoutPage`, and `layoutMultiColumnPage` directly.

## Core API

- `loadEpub(bytes)` parses an EPUB archive into a `Document`, TOC tree, image map, and href target map.
- `EpubReader` provides swipe navigation, TOC jumps, link handling, and progress persistence hooks.
- `PagedReader` gives you a paginated `PageView` surface for any `Document`.
- `DocumentView` renders a single laid-out page when you want custom chrome.
- `layoutPage` and `layoutMultiColumnPage` expose the raw engine output for custom readers and editorial layouts.

## Example App

The example app currently demos:

- EPUB reader flow
- simple pagination
- obstacle avoidance
- the dragon test
- multi-column flow

```bash
cd example
flutter run
```

## Current Status

The engine is already strong for:

- paginated reading
- obstacle-aware editorial layouts
- EPUB chapter/TOC ingestion
- in-book navigation through resolved href targets

The next reader-product layers are richer interaction features such as selection, highlights, bookmarks, search, and stronger external-link handling out of the box.
