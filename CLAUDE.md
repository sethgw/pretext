# Pretext — Flutter Text Layout Engine

## What This Is

A Dart port of [Pretext](https://chenglou.me/pretext/)'s text layout algorithms for Flutter. Uses Flutter's native text engine (dart:ui Paragraph + HarfBuzz/ICU) for measurement, with custom layout logic for pagination, multi-column flow, and obstacle-aware text wrapping.

## Architecture

```
dart:ui Paragraph (measurement) → LineBreaker → PageLayout → PagePainter
```

- **Document model** (`lib/src/document/`): Block, AttributedSpan, SpanStyle, DocumentCursor
- **Layout engine** (`lib/src/layout/`): LineBreaker, page_layout, column_layout
- **Obstacles** (`lib/src/obstacles/`): Obstacle types + interval_solver
- **Rendering** (`lib/src/rendering/`): PagePainter (CustomPainter)
- **Widgets** (`lib/src/widgets/`): DocumentView, PagedReader

## Key Patterns

- `layoutNextLine()` in `line_breaker.dart` is the core — it's the Flutter adaptation of Pretext's central API
- `carveSlots()` in `interval_solver.dart` is a direct port of Pretext's `carveTextLineSlots()`
- `CircleObstacle.horizontalBlockAt()` is a direct port of Pretext's `circleIntervalForBand()`
- All layout functions are pure functions (no side effects, no state)
- `LayoutPage` carries pre-built `Paragraph` objects ready to paint

## Commands

- `flutter pub get` — install dependencies
- `flutter test` — run tests
- `flutter analyze` — lint check
- `cd example && flutter run` — run the demo app

## Conventions

- Package imports (`package:pretext/...`) not relative imports
- Pure functions for layout — no widget state in the engine
- Obstacles are immutable value objects
- `DocumentCursor` is serializable for progress persistence
