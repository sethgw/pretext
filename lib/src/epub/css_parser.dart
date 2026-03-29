import 'package:flutter/painting.dart';

import 'package:pretext/src/document/span_style.dart';

// ---------------------------------------------------------------------------
// Color parsing
// ---------------------------------------------------------------------------

/// Named CSS colors supported by the parser.
const _namedColors = <String, Color>{
  'black': Color(0xFF000000),
  'white': Color(0xFFFFFFFF),
  'red': Color(0xFFFF0000),
  'green': Color(0xFF008000),
  'blue': Color(0xFF0000FF),
  'gray': Color(0xFF808080),
  'grey': Color(0xFF808080),
};

/// Parse a CSS color value.
///
/// Supports `#RGB`, `#RRGGBB`, `rgb(r,g,b)`, and a small set of named colors
/// (black, white, red, green, blue, gray/grey).  Returns `null` for anything
/// it cannot understand.
Color? parseColor(String value) {
  final v = value.trim().toLowerCase();

  // Named colors.
  if (_namedColors.containsKey(v)) return _namedColors[v];

  // Hex: #RGB or #RRGGBB.
  if (v.startsWith('#')) {
    final hex = v.substring(1);
    if (hex.length == 3) {
      final r = int.tryParse(hex[0] * 2, radix: 16);
      final g = int.tryParse(hex[1] * 2, radix: 16);
      final b = int.tryParse(hex[2] * 2, radix: 16);
      if (r != null && g != null && b != null) {
        return Color.fromARGB(255, r, g, b);
      }
    } else if (hex.length == 6) {
      final intVal = int.tryParse(hex, radix: 16);
      if (intVal != null) return Color(0xFF000000 | intVal);
    }
    return null;
  }

  // rgb(r, g, b).
  if (v.startsWith('rgb(') && v.endsWith(')')) {
    final inner = v.substring(4, v.length - 1);
    final parts = inner.split(',');
    if (parts.length == 3) {
      final r = int.tryParse(parts[0].trim());
      final g = int.tryParse(parts[1].trim());
      final b = int.tryParse(parts[2].trim());
      if (r != null && g != null && b != null) {
        return Color.fromARGB(255, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
      }
    }
    return null;
  }

  return null;
}

// ---------------------------------------------------------------------------
// Inline style parsing
// ---------------------------------------------------------------------------

/// Map a CSS `font-weight` value to [FontWeight] and a bold flag.
({bool bold, FontWeight? fontWeight}) _parseFontWeight(String value) {
  final v = value.trim().toLowerCase();
  if (v == 'bold') return (bold: true, fontWeight: FontWeight.w700);
  if (v == 'normal') return (bold: false, fontWeight: FontWeight.w400);

  final n = int.tryParse(v);
  if (n != null) {
    final weight = switch (n) {
      100 => FontWeight.w100,
      200 => FontWeight.w200,
      300 => FontWeight.w300,
      400 => FontWeight.w400,
      500 => FontWeight.w500,
      600 => FontWeight.w600,
      700 => FontWeight.w700,
      800 => FontWeight.w800,
      900 => FontWeight.w900,
      _ => null,
    };
    return (bold: n >= 700, fontWeight: weight);
  }
  return (bold: false, fontWeight: null);
}

/// Parse a CSS `text-decoration` value.
TextDecoration? _parseTextDecoration(String value) {
  final v = value.trim().toLowerCase();
  if (v == 'underline') return TextDecoration.underline;
  if (v == 'line-through') return TextDecoration.lineThrough;
  if (v == 'none') return TextDecoration.none;
  return null;
}

/// Strip surrounding quotes (single or double) from a string.
String _stripQuotes(String s) {
  var v = s.trim();
  if (v.length >= 2) {
    if ((v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))) {
      v = v.substring(1, v.length - 1);
    }
  }
  return v;
}

/// Parse a CSS numeric value, stripping a known unit suffix.
///
/// Returns the numeric portion, or `null` on failure.
double? _parseNumeric(String value) {
  var v = value.trim().toLowerCase();
  // Strip known units.
  for (final unit in ['px', 'em', '%', 'pt', 'rem']) {
    if (v.endsWith(unit)) {
      v = v.substring(0, v.length - unit.length).trim();
      break;
    }
  }
  return double.tryParse(v);
}

/// Parse an inline `style` attribute string into a [SpanStyle].
///
/// Example input: `"font-weight: bold; color: #333; font-size: 14px"`
///
/// Unknown properties are silently ignored.  Malformed values are skipped
/// without throwing.  Returns [SpanStyle.normal] for empty or null-like input.
SpanStyle parseInlineStyle(String styleAttr) {
  final trimmed = styleAttr.trim();
  if (trimmed.isEmpty) return SpanStyle.normal;

  bool bold = false;
  bool italic = false;
  double? fontSize;
  Color? color;
  String? fontFamily;
  TextDecoration? decoration;
  double? letterSpacing;
  double? height;
  FontWeight? fontWeight;

  final declarations = trimmed.split(';');
  for (final decl in declarations) {
    final colonIdx = decl.indexOf(':');
    if (colonIdx < 0) continue;

    final prop = decl.substring(0, colonIdx).trim().toLowerCase();
    final value = decl.substring(colonIdx + 1).trim();
    if (prop.isEmpty || value.isEmpty) continue;

    try {
      switch (prop) {
        case 'font-weight':
          final result = _parseFontWeight(value);
          bold = result.bold;
          fontWeight = result.fontWeight;
        case 'font-style':
          if (value.trim().toLowerCase() == 'italic') italic = true;
        case 'font-size':
          fontSize = _parseNumeric(value);
        case 'color':
          color = parseColor(value);
        case 'font-family':
          // Take the first family name.
          final families = value.split(',');
          if (families.isNotEmpty) {
            fontFamily = _stripQuotes(families.first);
          }
        case 'text-decoration':
          decoration = _parseTextDecoration(value);
        case 'letter-spacing':
          letterSpacing = _parseNumeric(value);
        case 'line-height':
          height = _parseNumeric(value);
      }
    } catch (_) {
      // Skip malformed values.
    }
  }

  // Fast path: if nothing was set, return the canonical normal instance.
  if (!bold &&
      !italic &&
      fontSize == null &&
      color == null &&
      fontFamily == null &&
      decoration == null &&
      letterSpacing == null &&
      height == null &&
      fontWeight == null) {
    return SpanStyle.normal;
  }

  return SpanStyle(
    bold: bold,
    italic: italic,
    fontSize: fontSize,
    color: color,
    fontFamily: fontFamily,
    decoration: decoration,
    letterSpacing: letterSpacing,
    height: height,
    fontWeight: fontWeight,
  );
}

// ---------------------------------------------------------------------------
// Stylesheet parsing
// ---------------------------------------------------------------------------

/// Strip CSS comments (`/* ... */`) from [css].
String _stripComments(String css) {
  return css.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
}

/// Parse a CSS stylesheet string into a map of selector -> [SpanStyle].
///
/// Only simple selectors are supported: element (`p`), class (`.italic`),
/// id (`#title`), and element.class (`p.intro`).  Compound selectors
/// separated by commas (`h1, h2, h3 { ... }`) produce an entry for each
/// selector.
///
/// Returns an empty map for empty or fully-malformed input.
Map<String, SpanStyle> parseStylesheet(String css) {
  final result = <String, SpanStyle>{};

  final stripped = _stripComments(css);

  // Match rule blocks: selectors { declarations }
  final ruleRegex = RegExp(r'([^{}]+)\{([^}]*)\}');
  for (final match in ruleRegex.allMatches(stripped)) {
    final selectorPart = match.group(1)!.trim();
    final declarationPart = match.group(2)!.trim();

    if (selectorPart.isEmpty || declarationPart.isEmpty) continue;

    final style = parseInlineStyle(declarationPart);

    // Handle comma-separated selectors.
    final selectors = selectorPart.split(',');
    for (final sel in selectors) {
      final s = sel.trim();
      if (s.isNotEmpty) {
        // If a selector already exists, merge with the new style.
        final existing = result[s];
        result[s] = existing != null ? existing.mergeWith(style) : style;
      }
    }
  }

  return result;
}

// ---------------------------------------------------------------------------
// Style resolution
// ---------------------------------------------------------------------------

/// Resolve the effective [SpanStyle] for an element by checking [stylesheet].
///
/// The cascade order (later overrides earlier):
/// 1. Element selector (e.g. `p`)
/// 2. Class selectors (e.g. `.italic`)
/// 3. Element.class selectors (e.g. `p.italic`)
/// 4. ID selector (e.g. `#title`)
///
/// This approximates CSS specificity well enough for EPUB rendering.
SpanStyle resolveElementStyle(
  Map<String, SpanStyle> stylesheet,
  String element,
  List<String> classes,
  String? id,
) {
  var style = SpanStyle.normal;

  // 1. Element selector.
  final elementStyle = stylesheet[element];
  if (elementStyle != null) style = style.mergeWith(elementStyle);

  // 2. Class selectors.
  for (final cls in classes) {
    final classStyle = stylesheet['.$cls'];
    if (classStyle != null) style = style.mergeWith(classStyle);
  }

  // 3. Element.class selectors.
  for (final cls in classes) {
    final ecStyle = stylesheet['$element.$cls'];
    if (ecStyle != null) style = style.mergeWith(ecStyle);
  }

  // 4. ID selector.
  if (id != null && id.isNotEmpty) {
    final idStyle = stylesheet['#$id'];
    if (idStyle != null) style = style.mergeWith(idStyle);
  }

  return style;
}
