## 0.3.0

- Paginate using measured line metrics instead of a fixed line-height step
- Carry richer block output through layout and painting, including lists, blockquotes, rules, images, and table rendering
- Parse EPUB tables into structured table blocks with multi-page row continuation and content-based column sizing
- Add shared rich paragraph shaping helpers and stronger layout coverage, including the dragon obstacle tests
- Add a first-class dragon demo to the example app

## 0.0.1

- Initial development release
- Core document model (Block, AttributedSpan, SpanStyle, DocumentCursor)
- Line-by-line layout engine using dart:ui Paragraph
- Page layout with obstacle avoidance
- Multi-column flow with cursor handoff
- Obstacle types: Rectangle, Circle, Polygon
- PagePainter (CustomPainter) rendering
- PagedReader and DocumentView widgets
