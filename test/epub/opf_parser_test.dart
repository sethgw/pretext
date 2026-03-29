import 'package:flutter_test/flutter_test.dart';
import 'package:pretext/src/epub/opf_parser.dart';

const _containerXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';

const _opfXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Test Book Title</dc:title>
    <dc:creator>Jane Author</dc:creator>
    <dc:language>en</dc:language>
    <dc:publisher>Test Publisher</dc:publisher>
  </metadata>
  <manifest>
    <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="chapter2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="img1" href="images/cover.jpg" media-type="image/jpeg"/>
    <item id="style" href="style.css" media-type="text/css"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="chapter1"/>
    <itemref idref="chapter2"/>
  </spine>
</package>
''';

void main() {
  group('parseContainerXml', () {
    test('extracts the OPF file path', () {
      final path = parseContainerXml(_containerXml);
      expect(path, 'OEBPS/content.opf');
    });

    test('throws on missing rootfile element', () {
      const bad = '''
<?xml version="1.0"?>
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles/>
</container>
''';
      expect(() => parseContainerXml(bad), throwsFormatException);
    });
  });

  group('parseOpf', () {
    late OpfData result;

    setUp(() {
      result = parseOpf(_opfXml, basePath: 'OEBPS/');
    });

    test('extracts metadata title', () {
      expect(result.metadata.title, 'Test Book Title');
    });

    test('extracts metadata author', () {
      expect(result.metadata.author, 'Jane Author');
    });

    test('extracts metadata language', () {
      expect(result.metadata.language, 'en');
    });

    test('extracts metadata publisher', () {
      expect(result.metadata.publisher, 'Test Publisher');
    });

    test('builds manifest map keyed by id', () {
      expect(result.manifest, hasLength(6));
      expect(result.manifest.containsKey('chapter1'), isTrue);
      expect(result.manifest.containsKey('nav'), isTrue);
      expect(result.manifest.containsKey('ncx'), isTrue);
      expect(result.manifest.containsKey('img1'), isTrue);
      expect(result.manifest.containsKey('style'), isTrue);
    });

    test('manifest items have correct media types', () {
      expect(
        result.manifest['chapter1']!.mediaType,
        'application/xhtml+xml',
      );
      expect(result.manifest['img1']!.mediaType, 'image/jpeg');
      expect(result.manifest['style']!.mediaType, 'text/css');
    });

    test('builds spine list in document order', () {
      expect(result.spine, hasLength(2));
      expect(result.spine[0].idref, 'chapter1');
      expect(result.spine[1].idref, 'chapter2');
    });

    test('spine items default to linear', () {
      expect(result.spine[0].linear, isTrue);
      expect(result.spine[1].linear, isTrue);
    });

    test('finds tocId from spine toc attribute', () {
      expect(result.tocId, 'ncx');
    });

    test('finds nav item from manifest properties', () {
      expect(result.navItemId, 'nav');
    });

    test('manifest hrefs are resolved against basePath', () {
      expect(result.manifest['chapter1']!.href, 'OEBPS/chapter1.xhtml');
      expect(result.manifest['img1']!.href, 'OEBPS/images/cover.jpg');
      expect(result.manifest['style']!.href, 'OEBPS/style.css');
    });

    test('resolves parent directory references in hrefs', () {
      const opfWithParentRef = '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"/>
  <manifest>
    <item id="shared" href="../shared/style.css" media-type="text/css"/>
  </manifest>
  <spine/>
</package>
''';
      final data = parseOpf(opfWithParentRef, basePath: 'OEBPS/');
      expect(data.manifest['shared']!.href, 'shared/style.css');
    });

    test('handles non-linear spine items', () {
      const opfWithNonLinear = '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"/>
  <manifest>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="appendix" href="appendix.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
    <itemref idref="appendix" linear="no"/>
  </spine>
</package>
''';
      final data = parseOpf(opfWithNonLinear, basePath: '');
      expect(data.spine[0].linear, isTrue);
      expect(data.spine[1].linear, isFalse);
    });

    test('handles missing optional metadata fields', () {
      const minimalOpf = '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Minimal</dc:title>
  </metadata>
  <manifest/>
  <spine/>
</package>
''';
      final data = parseOpf(minimalOpf, basePath: '');
      expect(data.metadata.title, 'Minimal');
      expect(data.metadata.author, isNull);
      expect(data.metadata.language, isNull);
      expect(data.metadata.publisher, isNull);
      expect(data.tocId, isNull);
      expect(data.navItemId, isNull);
    });
  });
}
