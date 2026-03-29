import 'package:flutter/material.dart';
import 'package:pretext/pretext.dart';

void main() {
  runApp(const PretextExampleApp());
}

class PretextExampleApp extends StatelessWidget {
  const PretextExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pretext Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4C9A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DemoSelector(),
    );
  }
}

class DemoSelector extends StatelessWidget {
  const DemoSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pretext Demos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DemoTile(
            title: 'Simple Pagination',
            subtitle: 'Text broken into pages with swipe navigation',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SimplePaginationDemo()),
            ),
          ),
          _DemoTile(
            title: 'Obstacle Avoidance',
            subtitle: 'Text flows around a draggable circle — like Pretext\'s editorial engine',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ObstacleDemo()),
            ),
          ),
          _DemoTile(
            title: 'Multi-Column Flow',
            subtitle: 'Two-column layout with cursor handoff between columns',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MultiColumnDemo()),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DemoTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo text
// ---------------------------------------------------------------------------

const _demoText = '''The web renders text through a pipeline that was designed thirty years ago for static documents. A browser loads a font, shapes the text into glyphs, measures their combined width, determines where lines break, and positions each line vertically. Every step depends on the previous one.

For a paragraph in a blog post, this pipeline is invisible. The browser loads, lays out, and paints before the reader's eye has traveled from the address bar to the first word. But the web is no longer a collection of static documents. It is a platform for applications, and those applications need to know about text in ways the original pipeline never anticipated.

A messaging application needs to know the exact height of every message bubble before rendering a virtualized list. A masonry layout needs the height of every card to position them without overlap. An editorial page needs text to flow around images, advertisements, and interactive elements.

Every one of these operations requires text measurement. And every text measurement on the web today requires a synchronous layout reflow. The cost is devastating. Measuring the height of a single text block forces the browser to recalculate the position of every element on the page.

What if text measurement did not require the DOM at all? What if you could compute exactly where every line of text would break, exactly how wide each line would be, and exactly how tall the entire text block would be, using nothing but arithmetic?

This is the core insight behind a new approach to text layout. The canvas API includes a measureText method that returns the width of any string in any font without triggering a layout reflow. Canvas measurement uses the same font engine as DOM rendering.

With DOM-free text measurement, an entire class of previously impractical interfaces becomes trivial. Text can flow around arbitrary shapes, not because the layout engine supports it, but because you control the line widths directly. For each line of text, you compute which horizontal intervals are blocked by obstacles, subtract them from the available width, and pass the remaining width to the layout engine.

The editorial layouts we see in print magazines — text flowing around photographs, pull quotes interrupting the column, multiple columns with seamless text handoff — these become possible when layout is just arithmetic.

Multi-column text flow with cursor handoff is perhaps the most striking capability. The left column consumes text until it reaches the bottom, then hands its cursor to the right column. The right column picks up exactly where the left column stopped, with no duplication, no gap, and perfect line breaking at the column boundary.

Real-time text reflow around animated obstacles is the ultimate stress test. Text can flow around multiple moving objects simultaneously, every frame, at sixty frames per second. Each frame, the layout engine computes obstacle intersections for every line of text, determines the available horizontal slots, lays out each line at the correct width and position, and updates the display with the results.

This is what changes when text measurement becomes free. Not slightly better — categorically different. The interfaces that were too expensive to build become trivial. The layouts that existed only in print become interactive. The text that sat in boxes begins to flow.''';

Document _buildDemoDocument() {
  final paragraphs = _demoText
      .split('\n\n')
      .where((p) => p.trim().isNotEmpty)
      .toList();

  return Document.singleChapter([
    HeadingBlock(
      level: 1,
      spans: [const AttributedSpan.plain('The Future of Text Layout')],
    ),
    ...paragraphs.map((p) => ParagraphBlock.plain(p)),
  ]);
}

LayoutConfig _baseConfig(Brightness brightness) {
  return LayoutConfig(
    baseTextStyle: TextStyle(
      fontSize: 17,
      height: 1.6,
      color: brightness == Brightness.dark ? const Color(0xFFE8E0D4) : const Color(0xFF2C2C2C),
      fontFamily: 'Georgia',
    ),
    lineHeight: 27.2, // 17 * 1.6
    blockSpacing: 14,
    margins: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
    headingStyleResolver: (level) {
      final scale = level == 1 ? 1.8 : (level == 2 ? 1.4 : 1.2);
      return TextStyle(
        fontSize: 17 * scale,
        fontWeight: FontWeight.bold,
        height: 1.3,
        color: brightness == Brightness.dark ? const Color(0xFFF5F0E8) : const Color(0xFF1A1A1A),
        fontFamily: 'Georgia',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Demo 1: Simple Pagination
// ---------------------------------------------------------------------------

class SimplePaginationDemo extends StatefulWidget {
  const SimplePaginationDemo({super.key});

  @override
  State<SimplePaginationDemo> createState() => _SimplePaginationDemoState();
}

class _SimplePaginationDemoState extends State<SimplePaginationDemo> {
  final _document = _buildDemoDocument();
  double _progress = 0.0;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor = brightness == Brightness.dark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFFAF7F2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Pagination'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 2,
          ),
        ),
      ),
      body: PagedReader(
        document: _document,
        config: _baseConfig(brightness),
        backgroundColor: bgColor,
        onProgressChanged: (p) => setState(() => _progress = p),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo 2: Obstacle Avoidance
// ---------------------------------------------------------------------------

class ObstacleDemo extends StatefulWidget {
  const ObstacleDemo({super.key});

  @override
  State<ObstacleDemo> createState() => _ObstacleDemoState();
}

class _ObstacleDemoState extends State<ObstacleDemo> {
  final _document = _buildDemoDocument();
  double _orbX = 200;
  double _orbY = 300;
  static const _orbR = 80.0;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor = brightness == Brightness.dark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFFAF7F2);
    final config = _baseConfig(brightness);

    return Scaffold(
      appBar: AppBar(title: const Text('Obstacle Avoidance')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final pageSize = constraints.biggest;
          final obstacles = [
            CircleObstacle(
              cx: _orbX,
              cy: _orbY,
              r: _orbR,
              horizontalPadding: 16,
              verticalPadding: 6,
            ),
          ];

          final page = layoutPage(
            document: _document,
            startCursor: _document.startCursor,
            pageSize: pageSize,
            config: config,
            obstacles: obstacles,
          );

          return GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _orbX = (_orbX + details.delta.dx)
                    .clamp(_orbR, pageSize.width - _orbR);
                _orbY = (_orbY + details.delta.dy)
                    .clamp(_orbR, pageSize.height - _orbR);
              });
            },
            child: Stack(
              children: [
                CustomPaint(
                  size: pageSize,
                  painter: PagePainter(
                    page: page,
                    backgroundColor: bgColor,
                  ),
                ),
                // The draggable orb
                Positioned(
                  left: _orbX - _orbR,
                  top: _orbY - _orbR,
                  child: IgnorePointer(
                    child: Container(
                      width: _orbR * 2,
                      height: _orbR * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.3, -0.3),
                          colors: [
                            const Color(0x666B4C9A),
                            const Color(0x266B4C9A),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55, 0.72],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo 3: Multi-Column Flow
// ---------------------------------------------------------------------------

class MultiColumnDemo extends StatelessWidget {
  const MultiColumnDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor = brightness == Brightness.dark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFFAF7F2);
    final document = _buildDemoDocument();
    final config = _baseConfig(brightness);

    return Scaffold(
      appBar: AppBar(title: const Text('Multi-Column Flow')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final pageSize = constraints.biggest;
          final page = layoutMultiColumnPage(
            document: document,
            startCursor: document.startCursor,
            pageSize: pageSize,
            config: config,
            columnCount: 2,
            columnGap: 32,
          );

          return CustomPaint(
            size: pageSize,
            painter: PagePainter(
              page: page,
              backgroundColor: bgColor,
            ),
          );
        },
      ),
    );
  }
}
