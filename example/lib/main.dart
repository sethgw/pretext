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
            title: 'Dragon Test',
            subtitle: 'The main demo: a dragon cuts through the page and the text bends around it',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DragonDemo()),
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

Document _buildDragonDemoDocument() {
  final intro = ParagraphBlock.plain(
    'The dragon test is the canonical Pretext demo: a moving object crosses the page, and the text has to discover the remaining open space line by line. Swipe forward and the dragon advances farther to the right on each page.',
  );

  final body = _demoText
      .split('\n\n')
      .where((p) => p.trim().isNotEmpty)
      .take(8)
      .map(ParagraphBlock.plain)
      .toList();

  return Document.singleChapter([
    HeadingBlock(
      level: 1,
      spans: [const AttributedSpan.plain('The Dragon Test')],
    ),
    intro,
    ...body,
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
// Demo 3: Dragon Test
// ---------------------------------------------------------------------------

class DragonDemo extends StatefulWidget {
  const DragonDemo({super.key});

  @override
  State<DragonDemo> createState() => _DragonDemoState();
}

class _DragonDemoState extends State<DragonDemo> {
  final _document = _buildDragonDemoDocument();
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor = brightness == Brightness.dark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFFAF7F2);

    return Scaffold(
      appBar: AppBar(title: const Text('Dragon Test')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            color: brightness == Brightness.dark
                ? const Color(0xFF151515)
                : const Color(0xFFF2E6D6),
            child: Text(
              'Swipe through the book. Each page moves the dragon farther across the spread, and every line has to reflow around the body, wing, and tail.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: brightness == Brightness.dark
                    ? const Color(0xFFE8D5B6)
                    : const Color(0xFF5B2C18),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pageSize = constraints.biggest;
                final dragon = _dragonObstacleForPage(_pageIndex, pageSize);

                return Stack(
                  children: [
                    PagedReader(
                      document: _document,
                      config: _baseConfig(brightness),
                      backgroundColor: bgColor,
                      obstacleBuilder: (pageIndex, pageSize) => [
                        _dragonObstacleForPage(pageIndex, pageSize),
                      ],
                      onPageChanged: (pageIndex) {
                        setState(() {
                          _pageIndex = pageIndex;
                        });
                      },
                    ),
                    IgnorePointer(
                      child: CustomPaint(
                        size: pageSize,
                        painter: _DragonOverlayPainter(
                          dragon: dragon,
                          brightness: brightness,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo 4: Multi-Column Flow
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

PolygonObstacle _dragonObstacleForPage(int pageIndex, Size pageSize) {
  final dragonWidth = (pageSize.width * 0.46).clamp(170.0, 250.0).toDouble();
  final dragonHeight = dragonWidth * 1.18;
  final x = pageSize.width * 0.06 + pageIndex * dragonWidth * 0.42;
  final y = (pageSize.height * 0.10).clamp(52.0, 110.0).toDouble();

  return PolygonObstacle(
    points: [
      (x: x + dragonWidth * 0.15, y: y + dragonHeight * 0.11),
      (x: x + dragonWidth * 0.54, y: y + dragonHeight * 0.00),
      (x: x + dragonWidth * 0.92, y: y + dragonHeight * 0.17),
      (x: x + dragonWidth * 0.80, y: y + dragonHeight * 0.48),
      (x: x + dragonWidth * 1.02, y: y + dragonHeight * 0.69),
      (x: x + dragonWidth * 0.71, y: y + dragonHeight * 0.89),
      (x: x + dragonWidth * 0.48, y: y + dragonHeight * 0.77),
      (x: x + dragonWidth * 0.29, y: y + dragonHeight * 0.99),
      (x: x + dragonWidth * 0.06, y: y + dragonHeight * 0.75),
      (x: x + dragonWidth * 0.00, y: y + dragonHeight * 0.48),
    ],
    horizontalPadding: 12,
    verticalPadding: 6,
  );
}

class _DragonOverlayPainter extends CustomPainter {
  final PolygonObstacle dragon;
  final Brightness brightness;

  const _DragonOverlayPainter({
    required this.dragon,
    required this.brightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dragon.points.length < 3) {
      return;
    }

    final path = Path()..moveTo(dragon.points.first.x, dragon.points.first.y);
    for (int i = 1; i < dragon.points.length; i++) {
      path.lineTo(dragon.points[i].x, dragon.points[i].y);
    }
    path.close();

    final bounds = path.getBounds();
    final shadowColor = brightness == Brightness.dark
        ? const Color(0xAA160705)
        : const Color(0x55160705);
    final strokeColor = brightness == Brightness.dark
        ? const Color(0xFFD8A96B)
        : const Color(0xFF7B2B11);
    final flameOuter = brightness == Brightness.dark
        ? const Color(0x99FF9E39)
        : const Color(0x88D76A21);
    final flameInner = brightness == Brightness.dark
        ? const Color(0xCCFFE3A2)
        : const Color(0xCCFFD27A);

    canvas.drawShadow(path, shadowColor, 14, false);

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: brightness == Brightness.dark
            ? const [
                Color(0xCCB84D2D),
                Color(0xCC81211A),
                Color(0xCC220A07),
              ]
            : const [
                Color(0xCCDA7C42),
                Color(0xCCAA3A20),
                Color(0xCC4A170F),
              ],
      ).createShader(bounds.inflate(12));

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = strokeColor;

    canvas.drawPath(path, bodyPaint);
    canvas.drawPath(path, strokePaint);

    final spinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = strokeColor.withValues(alpha: 0.55);
    final spinePath = Path()
      ..moveTo(bounds.left + bounds.width * 0.24, bounds.top + bounds.height * 0.22)
      ..quadraticBezierTo(
        bounds.left + bounds.width * 0.48,
        bounds.top - bounds.height * 0.04,
        bounds.left + bounds.width * 0.76,
        bounds.top + bounds.height * 0.20,
      )
      ..quadraticBezierTo(
        bounds.left + bounds.width * 0.66,
        bounds.top + bounds.height * 0.40,
        bounds.left + bounds.width * 0.82,
        bounds.top + bounds.height * 0.58,
      );
    canvas.drawPath(spinePath, spinePaint);

    final eyeCenter = Offset(
      bounds.left + bounds.width * 0.84,
      bounds.top + bounds.height * 0.57,
    );
    canvas.drawCircle(
      eyeCenter,
      4.0,
      Paint()..color = const Color(0xFFFFE08A),
    );
    canvas.drawCircle(
      eyeCenter.translate(1.2, 0),
      1.2,
      Paint()..color = const Color(0xFF220A07),
    );

    final flameBase = Offset(
      bounds.right - bounds.width * 0.02,
      bounds.top + bounds.height * 0.66,
    );
    final flamePath = Path()
      ..moveTo(flameBase.dx, flameBase.dy)
      ..quadraticBezierTo(
        flameBase.dx + 18,
        flameBase.dy - 12,
        flameBase.dx + 34,
        flameBase.dy - 2,
      )
      ..quadraticBezierTo(
        flameBase.dx + 18,
        flameBase.dy + 10,
        flameBase.dx,
        flameBase.dy + 8,
      )
      ..close();
    canvas.drawPath(flamePath, Paint()..color = flameOuter);

    final innerFlamePath = Path()
      ..moveTo(flameBase.dx + 2, flameBase.dy + 2)
      ..quadraticBezierTo(
        flameBase.dx + 13,
        flameBase.dy - 5,
        flameBase.dx + 23,
        flameBase.dy + 0,
      )
      ..quadraticBezierTo(
        flameBase.dx + 14,
        flameBase.dy + 6,
        flameBase.dx + 2,
        flameBase.dy + 6,
      )
      ..close();
    canvas.drawPath(innerFlamePath, Paint()..color = flameInner);
  }

  @override
  bool shouldRepaint(covariant _DragonOverlayPainter oldDelegate) {
    return !identical(dragon, oldDelegate.dragon) ||
        brightness != oldDelegate.brightness;
  }
}
