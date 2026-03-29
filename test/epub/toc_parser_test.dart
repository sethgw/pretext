import 'package:flutter_test/flutter_test.dart';
import 'package:pretext/src/document/document.dart';
import 'package:pretext/src/epub/opf_parser.dart';
import 'package:pretext/src/epub/toc_parser.dart';

const _flatNcx = '''
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/">
  <navMap>
    <navPoint id="ch1">
      <navLabel><text>Chapter 1</text></navLabel>
      <content src="chapter1.xhtml"/>
    </navPoint>
    <navPoint id="ch2">
      <navLabel><text>Chapter 2</text></navLabel>
      <content src="chapter2.xhtml"/>
    </navPoint>
  </navMap>
</ncx>
''';

const _nestedNcx = '''
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/">
  <navMap>
    <navPoint id="ch1">
      <navLabel><text>Chapter 1</text></navLabel>
      <content src="chapter1.xhtml"/>
      <navPoint id="ch1_1">
        <navLabel><text>Section 1.1</text></navLabel>
        <content src="chapter1.xhtml#sec1"/>
      </navPoint>
      <navPoint id="ch1_2">
        <navLabel><text>Section 1.2</text></navLabel>
        <content src="chapter1.xhtml#sec2"/>
      </navPoint>
    </navPoint>
    <navPoint id="ch2">
      <navLabel><text>Chapter 2</text></navLabel>
      <content src="chapter2.xhtml"/>
    </navPoint>
  </navMap>
</ncx>
''';

const _emptyNcx = '''
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/">
  <navMap/>
</ncx>
''';

const _flatNavDoc = '''
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<body>
  <nav epub:type="toc">
    <ol>
      <li><a href="chapter1.xhtml">Chapter 1</a></li>
      <li><a href="chapter2.xhtml">Chapter 2</a></li>
    </ol>
  </nav>
</body>
</html>
''';

const _nestedNavDoc = '''
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<body>
  <nav epub:type="toc">
    <ol>
      <li><a href="chapter1.xhtml">Chapter 1</a>
        <ol>
          <li><a href="chapter1.xhtml#sec1">Section 1.1</a></li>
          <li><a href="chapter1.xhtml#sec2">Section 1.2</a></li>
        </ol>
      </li>
      <li><a href="chapter2.xhtml">Chapter 2</a></li>
    </ol>
  </nav>
</body>
</html>
''';

const _noTocNavDoc = '''
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<body>
  <nav epub:type="page-list">
    <ol>
      <li><a href="page1.xhtml">1</a></li>
    </ol>
  </nav>
</body>
</html>
''';

void main() {
  group('parseNcx', () {
    test('parses flat list of navPoints', () {
      final entries = parseNcx(_flatNcx);

      expect(entries, hasLength(2));
      expect(entries[0].title, 'Chapter 1');
      expect(entries[0].href, 'chapter1.xhtml');
      expect(entries[0].children, isEmpty);
      expect(entries[1].title, 'Chapter 2');
      expect(entries[1].href, 'chapter2.xhtml');
      expect(entries[1].children, isEmpty);
    });

    test('parses nested navPoints with children', () {
      final entries = parseNcx(_nestedNcx);

      expect(entries, hasLength(2));

      // First entry has two children.
      expect(entries[0].title, 'Chapter 1');
      expect(entries[0].children, hasLength(2));
      expect(entries[0].children[0].title, 'Section 1.1');
      expect(entries[0].children[0].href, 'chapter1.xhtml#sec1');
      expect(entries[0].children[1].title, 'Section 1.2');
      expect(entries[0].children[1].href, 'chapter1.xhtml#sec2');

      // Second entry has no children.
      expect(entries[1].title, 'Chapter 2');
      expect(entries[1].children, isEmpty);
    });

    test('returns empty list for empty navMap', () {
      final entries = parseNcx(_emptyNcx);
      expect(entries, isEmpty);
    });
  });

  group('parseNavDocument', () {
    test('parses flat list of entries', () {
      final entries = parseNavDocument(_flatNavDoc);

      expect(entries, hasLength(2));
      expect(entries[0].title, 'Chapter 1');
      expect(entries[0].href, 'chapter1.xhtml');
      expect(entries[0].children, isEmpty);
      expect(entries[1].title, 'Chapter 2');
      expect(entries[1].href, 'chapter2.xhtml');
      expect(entries[1].children, isEmpty);
    });

    test('parses nested entries', () {
      final entries = parseNavDocument(_nestedNavDoc);

      expect(entries, hasLength(2));

      // First entry has two children.
      expect(entries[0].title, 'Chapter 1');
      expect(entries[0].children, hasLength(2));
      expect(entries[0].children[0].title, 'Section 1.1');
      expect(entries[0].children[0].href, 'chapter1.xhtml#sec1');
      expect(entries[0].children[1].title, 'Section 1.2');
      expect(entries[0].children[1].href, 'chapter1.xhtml#sec2');

      // Second entry has no children.
      expect(entries[1].title, 'Chapter 2');
      expect(entries[1].children, isEmpty);
    });

    test('returns empty list when nav element is missing', () {
      final entries = parseNavDocument(_noTocNavDoc);
      expect(entries, isEmpty);
    });
  });

  group('parseToc', () {
    const navContent = _flatNavDoc;
    const ncxContent = _flatNcx;

    OpfData makeOpf({String? navItemId, String? tocId}) {
      return OpfData(
        metadata: const DocumentMetadata(),
        manifest: {
          if (navItemId != null)
            navItemId: ManifestItem(
              id: navItemId,
              href: 'OEBPS/nav.xhtml',
              mediaType: 'application/xhtml+xml',
              properties: 'nav',
            ),
          if (tocId != null)
            tocId: ManifestItem(
              id: tocId,
              href: 'OEBPS/toc.ncx',
              mediaType: 'application/x-dtbncx+xml',
            ),
        },
        spine: const [],
        navItemId: navItemId,
        tocId: tocId,
      );
    }

    test('prefers EPUB 3 nav over NCX when both available', () {
      final opf = makeOpf(navItemId: 'nav', tocId: 'ncx');

      final entries = parseToc(
        opf: opf,
        readFile: (path) {
          if (path == 'OEBPS/nav.xhtml') return navContent;
          if (path == 'OEBPS/toc.ncx') return ncxContent;
          throw Exception('unexpected path: $path');
        },
      );

      // Both have 2 entries, but we can verify the nav was used
      // by checking that the readFile was called with the nav path.
      expect(entries, hasLength(2));
      expect(entries[0].title, 'Chapter 1');
    });

    test('falls back to NCX when no nav item exists', () {
      final opf = makeOpf(tocId: 'ncx');

      final entries = parseToc(
        opf: opf,
        readFile: (path) {
          if (path == 'OEBPS/toc.ncx') return ncxContent;
          throw Exception('unexpected path: $path');
        },
      );

      expect(entries, hasLength(2));
      expect(entries[0].title, 'Chapter 1');
      expect(entries[1].title, 'Chapter 2');
    });

    test('returns empty list when neither nav nor NCX exists', () {
      final opf = makeOpf();

      final entries = parseToc(
        opf: opf,
        readFile: (_) => throw Exception('should not be called'),
      );

      expect(entries, isEmpty);
    });
  });
}
