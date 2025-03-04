// Add this new function to your class_generator.dart file

import '../../icon_font_generator.dart';

/// Generates a Flutter class with subclasses organized by folders
String generateFlutterClassHierarchy({
  required List<GenericGlyph> glyphList,
  required Map<String, Map<String, String>> folderStructure,
  required String fontFileName,
  required String fontFamily,
  String? className,
}) {
  final buffer = StringBuffer();

  buffer.writeln("import 'package:flutter/widgets.dart';");
  buffer.writeln();

  final mainClassName = className ?? '${fontFamily}Icons';

  // Generate all subclasses first
  folderStructure.forEach((folder, svgFiles) {
    if (folder != 'root') {
      final subClassName = '${mainClassName}${_formatSubclassName(folder)}';
      buffer.writeln('class $subClassName {');
      buffer.writeln('  const $subClassName._();');
      buffer.writeln();
      buffer.writeln('// ignore: unused_field');
      buffer.writeln('  static const _kFontFam = \'$fontFamily\';');
      buffer.writeln();

      final folderGlyphNames = svgFiles.keys.toList();
      for (final glyph in glyphList) {
        final name = glyph.metadata.name;
        if (name != null && folderGlyphNames.contains(name)) {
          final charCode = glyph.metadata.charCode;
          if (charCode != null) {
            final camelCaseName = _formatIconName(name);
            buffer.writeln('  /// $name icon');
            buffer.writeln('  final IconData $camelCaseName = '
                'const IconData(0x${charCode.toRadixString(16)}, fontFamily: _kFontFam);');
          }
        }
      }

      buffer.writeln('}');
      buffer.writeln();
    }
  });

  // Generate main class
  buffer.writeln('/// Icons generated from $fontFamily font');
  buffer.writeln('class $mainClassName {');
  buffer.writeln('  const $mainClassName._();');
  buffer.writeln();
  buffer.writeln('// ignore: unused_field');
  buffer.writeln('  static const _kFontFam = \'$fontFamily\';');
  // Removed _kFontPkg declaration
  buffer.writeln();

  // Generate static subclass references
  folderStructure.forEach((folder, svgFiles) {
    if (folder == 'root') {
      _generateIconConstants(buffer, glyphList, svgFiles.keys.toList(), '  ');
    } else {
      final subClassName = '${mainClassName}${_formatSubclassName(folder)}';
      buffer.writeln('  /// Directory path: $folder');
      buffer.writeln(
          '  static const $subClassName ${_formatGetterName(folder)} = $subClassName._();');
      buffer.writeln();
    }
  });

  buffer.writeln('}');

  return buffer.toString();
}

/// Helper function to format folder name as a getter name
String _formatGetterName(String folder) {
  final parts = folder.split('_');
  final first = parts.first.toLowerCase();
  final rest = parts.skip(1).map((part) {
    if (part.isEmpty) return '';
    return part[0].toUpperCase() + part.substring(1).toLowerCase();
  }).join('');
  return first + rest;
}

/// Helper function to format folder name as a valid class name
String _formatSubclassName(String folder) {
  final parts = folder.split('_');
  return parts.map((part) {
    if (part.isEmpty) return '';
    return part[0].toUpperCase() + part.substring(1);
  }).join('');
}

/// Helper function to generate icon constants
void _generateIconConstants(StringBuffer buffer, List<GenericGlyph> glyphList,
    List<String> iconNames, String indent) {
  for (final glyph in glyphList) {
    final name = glyph.metadata.name;
    if (name != null && iconNames.contains(name)) {
      final charCode = glyph.metadata.charCode;
      if (charCode != null) {
        final camelCaseName = _formatIconName(name);
        buffer.writeln('$indent/// $name icon');
        buffer.writeln('${indent}static const IconData $camelCaseName = '
            'IconData(0x${charCode.toRadixString(16)}, fontFamily: _kFontFam);');
      }
    }
  }
}

/// Helper function to format icon name as camelCase
String _formatIconName(String name) {
  final parts = name.split('_');
  return parts.first + parts.skip(1).map((part) {
    if (part.isEmpty) return '';
    return part[0].toUpperCase() + part.substring(1).toLowerCase();
  }).join('');
}
