# pretext

`pretext` is a native Flutter text layout engine for paginated reading surfaces.

It provides:

- obstacle-aware text flow
- swipe-based pagination
- multi-column layout
- EPUB loading and parsing
- a turnkey `EpubReader` widget
- TOC navigation and saved reading progress

## Install

```yaml
dependencies:
  pretext: ^0.4.0
```

## Quick Start

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
      bookId: 'my-book',
    );
  }
}
```

To load an EPUB from bytes:

```dart
import 'dart:typed_data';

import 'package:pretext/pretext.dart';

EpubLoadResult openBook(Uint8List bytes) {
  return loadEpub(bytes);
}
```

If you want lower-level control, use `PagedReader`, `DocumentView`, `layoutPage`, and `layoutMultiColumnPage` directly.

## Core API

- `loadEpub(bytes)` parses EPUB archives into `Document`, TOC entries, images, and href targets.
- `EpubReader` gives you a swipeable reader UI with TOC jumps and progress persistence hooks.
- `PagedReader` gives you paginated `PageView`-based reading for any `Document`.
- `layoutPage` and `layoutMultiColumnPage` expose the raw layout engine.

## Example

Run the example app to see:

- EPUB reader flow
- simple pagination
- obstacle avoidance
- the dragon test
- multi-column flow

```bash
cd example
flutter run
```
