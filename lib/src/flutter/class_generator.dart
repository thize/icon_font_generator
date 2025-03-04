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
      final iconNames = <String>[];

      for (final glyph in glyphList) {
        final name = glyph.metadata.name;
        if (name != null && folderGlyphNames.contains(name)) {
          final charCode = glyph.metadata.charCode;
          if (charCode != null) {
            final camelCaseName = _formatIconName(name);
            iconNames.add(camelCaseName);
            buffer.writeln('  /// $name icon');
            buffer.writeln('  final IconData $camelCaseName = '
                'const IconData(0x${charCode.toRadixString(16)}, fontFamily: _kFontFam);');
          }
        }
      }

      // Add allIcons list
      buffer.writeln();
      buffer.writeln('  /// List of all icons in this class');
      buffer.writeln('  List<IconData> get allIcons => [');
      for (final iconName in iconNames) {
        buffer.writeln('    $iconName,');
      }
      buffer.writeln('  ];');

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
  buffer.writeln();

  // Collect root icons for allIcons list
  final rootIconNames = <String>[];
  if (folderStructure.containsKey('root')) {
    for (final glyph in glyphList) {
      final name = glyph.metadata.name;
      if (name != null && folderStructure['root']!.keys.contains(name)) {
        final camelCaseName = _formatIconName(name);
        rootIconNames.add(camelCaseName);
      }
    }
  }

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
  
  // Add allIcons list for root icons
  if (rootIconNames.isNotEmpty) {
    buffer.writeln('  /// List of all root icons');
    buffer.writeln('  static List<IconData> get rootIcons => [');
    for (final iconName in rootIconNames) {
      buffer.writeln('    $iconName,');
    }
    buffer.writeln('  ];');
  }

  // Add combined allIcons getter
  buffer.writeln();
  buffer.writeln('  /// List of all icons in all categories');
  buffer.writeln('  static List<IconData> get allIcons => [');
  if (rootIconNames.isNotEmpty) {
    buffer.writeln('    ...rootIcons,');
  }
  folderStructure.forEach((folder, svgFiles) {
    if (folder != 'root') {
      final getterName = _formatGetterName(folder);
      buffer.writeln('    ...$getterName.allIcons,');
    }
  });
  buffer.writeln('  ];');

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
  return parts.first +
      parts.skip(1).map((part) {
        if (part.isEmpty) return '';
        return part[0].toUpperCase() + part.substring(1).toLowerCase();
      }).join('');
}
