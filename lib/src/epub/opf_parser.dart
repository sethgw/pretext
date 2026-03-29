import 'package:pretext/src/document/document.dart';
import 'package:xml/xml.dart';

/// A single item from the OPF manifest element.
class ManifestItem {
  final String id;
  final String href;
  final String mediaType;

  /// EPUB 3 properties attribute (e.g. "nav"). Null for EPUB 2 items.
  final String? properties;

  const ManifestItem({
    required this.id,
    required this.href,
    required this.mediaType,
    this.properties,
  });
}

/// A single item from the OPF spine element.
class SpineItem {
  final String idref;
  final bool linear;

  const SpineItem({required this.idref, this.linear = true});
}

/// The parsed contents of an OPF package document.
class OpfData {
  final DocumentMetadata metadata;

  /// Manifest items keyed by their id attribute.
  final Map<String, ManifestItem> manifest;

  /// Spine items in reading order.
  final List<SpineItem> spine;

  /// The manifest ID of the NCX table of contents (from `<spine toc="...">`).
  final String? tocId;

  /// The manifest item ID whose properties contain "nav" (EPUB 3 navigation).
  final String? navItemId;

  const OpfData({
    required this.metadata,
    required this.manifest,
    required this.spine,
    this.tocId,
    this.navItemId,
  });
}

/// Parses META-INF/container.xml and returns the full-path of the OPF file.
///
/// The container.xml has a `<rootfile full-path="...">` element that tells us
/// where the OPF package document lives inside the EPUB archive.
String parseContainerXml(String xml) {
  final document = XmlDocument.parse(xml);

  // Find <rootfile> element — may be namespaced.
  final rootfiles = document.findAllElements('rootfile');
  if (rootfiles.isEmpty) {
    throw const FormatException('No <rootfile> element found in container.xml');
  }

  final fullPath = rootfiles.first.getAttribute('full-path');
  if (fullPath == null || fullPath.isEmpty) {
    throw const FormatException(
      'No full-path attribute on <rootfile> in container.xml',
    );
  }

  return fullPath;
}

/// Parses an OPF package document and returns structured [OpfData].
///
/// [basePath] is the directory containing the OPF file (e.g. "OEBPS/").
/// Manifest hrefs are resolved relative to this path.
OpfData parseOpf(String xml, {required String basePath}) {
  final document = XmlDocument.parse(xml);
  final package = document.rootElement;

  // --- Metadata ---
  final metadataEl = _findFirst(package, 'metadata');
  String? title;
  String? author;
  String? language;
  String? publisher;

  if (metadataEl != null) {
    title = _dcText(metadataEl, 'title');
    author = _dcText(metadataEl, 'creator');
    language = _dcText(metadataEl, 'language');
    publisher = _dcText(metadataEl, 'publisher');
  }

  final metadata = DocumentMetadata(
    title: title,
    author: author,
    language: language,
    publisher: publisher,
  );

  // --- Manifest ---
  final manifestEl = _findFirst(package, 'manifest');
  final manifest = <String, ManifestItem>{};
  String? navItemId;

  if (manifestEl != null) {
    for (final item in manifestEl.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      final mediaType = item.getAttribute('media-type');
      if (id == null || href == null || mediaType == null) continue;

      final resolvedHref = _resolveHref(basePath, href);
      final properties = item.getAttribute('properties');

      manifest[id] = ManifestItem(
        id: id,
        href: resolvedHref,
        mediaType: mediaType,
        properties: properties,
      );

      // Detect EPUB 3 nav document.
      if (properties != null && properties.split(' ').contains('nav')) {
        navItemId = id;
      }
    }
  }

  // --- Spine ---
  final spineEl = _findFirst(package, 'spine');
  final spine = <SpineItem>[];
  String? tocId;

  if (spineEl != null) {
    tocId = spineEl.getAttribute('toc');

    for (final itemref in spineEl.findAllElements('itemref')) {
      final idref = itemref.getAttribute('idref');
      if (idref == null) continue;

      final linearAttr = itemref.getAttribute('linear');
      final linear = linearAttr != 'no';

      spine.add(SpineItem(idref: idref, linear: linear));
    }
  }

  return OpfData(
    metadata: metadata,
    manifest: manifest,
    spine: spine,
    tocId: tocId,
    navItemId: navItemId,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Finds the first child element matching [localName], ignoring namespaces.
XmlElement? _findFirst(XmlElement parent, String localName) {
  final results = parent.findAllElements(localName);
  return results.isEmpty ? null : results.first;
}

/// Extracts text from a Dublin Core element like `<dc:title>`.
///
/// Dublin Core elements may appear as `<dc:title>` (namespace-prefixed) or
/// just `<title>` depending on the XML serialization. We use `namespace: '*'`
/// to match regardless of namespace prefix.
String? _dcText(XmlElement metadata, String localName) {
  final elements = metadata.findAllElements(localName, namespace: '*');
  if (elements.isEmpty) return null;
  final text = elements.first.innerText.trim();
  return text.isEmpty ? null : text;
}

/// Resolves a manifest [href] relative to [basePath].
///
/// Uses [Uri] to normalize `.` and `..` segments. For example:
///   basePath = "OEBPS/", href = "chapter1.xhtml"
///   → "OEBPS/chapter1.xhtml"
///
///   basePath = "OEBPS/", href = "../images/cover.jpg"
///   → "images/cover.jpg"
String _resolveHref(String basePath, String href) {
  final baseUri = Uri.parse(basePath);
  final resolved = baseUri.resolve(href);
  return resolved.path;
}
