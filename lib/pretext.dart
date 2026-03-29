/// A Pretext-inspired native text layout engine for Flutter.
///
/// Provides pagination, multi-column flow, obstacle-aware text wrapping,
/// and rich document rendering — all using Flutter's native text engine
/// (dart:ui Paragraph + HarfBuzz/ICU). Zero WebView. Zero JS.
library;

// Document model
export 'src/document/document.dart';
export 'src/document/block.dart';
export 'src/document/attributed_span.dart';
export 'src/document/span_style.dart';
export 'src/document/document_cursor.dart';

// Layout engine
export 'src/layout/layout_config.dart';
export 'src/layout/layout_result.dart';
export 'src/layout/line_breaker.dart';
export 'src/layout/page_layout.dart';
export 'src/layout/column_layout.dart';

// Obstacles
export 'src/obstacles/obstacle.dart';
export 'src/obstacles/interval_solver.dart';

// Rendering
export 'src/rendering/page_painter.dart';

// Widgets
export 'src/widgets/document_view.dart';
export 'src/widgets/paged_reader.dart';
