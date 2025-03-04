import 'package:xml/xml.dart';

/// Preprocesses SVG content to ensure it uses nonzero fill rule
String preprocessSvg(String svgContent) {
  try {
    final document = XmlDocument.parse(svgContent);

    // Find all path elements and update their fill-rule
    final paths = document.findAllElements('path');
    for (final path in paths) {
      if (path.getAttribute('fill-rule') == 'evenodd') {
        path.setAttribute('fill-rule', 'nonzero');
      }
    }

    // Check for fill-rule in style attributes
    for (final element in document.findAllElements('*')) {
      final style = element.getAttribute('style');
      if (style != null && style.contains('fill-rule:evenodd')) {
        final newStyle =
            style.replaceAll('fill-rule:evenodd', 'fill-rule:nonzero');
        element.setAttribute('style', newStyle);
      }
    }

    return document.toXmlString();
  } catch (e) {
    // If parsing fails, return original content
    return svgContent;
  }
}
