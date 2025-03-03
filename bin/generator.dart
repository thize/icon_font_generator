import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_style/dart_style.dart';
import 'package:icon_font_generator/src/cli/arguments.dart';
import 'package:icon_font_generator/src/cli/options.dart';
import 'package:icon_font_generator/src/common/api.dart';
import 'package:icon_font_generator/src/flutter/class_generator.dart';
import 'package:icon_font_generator/src/otf/io.dart';
import 'package:icon_font_generator/src/utils/logger.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

final _argParser = ArgParser(allowTrailingOptions: true);
final formatter = DartFormatter(
  languageVersion: Version.parse('3.7.0'),
  pageWidth: 80,
);

void main(List<String> args) {
  defineOptions(_argParser);

  late final CliArguments parsedArgs;

  try {
    parsedArgs = parseArgsAndConfig(_argParser, args);
  } on CliArgumentException catch (e) {
    _usageError(e.message);
  } on CliHelpException {
    _printHelp();
  } on YamlException catch (e) {
    logger.e(e.toString());
    exit(66);
  }

  try {
    _run(parsedArgs);
  } on Object catch (e) {
    logger.e(e.toString());
    exit(65);
  }
}

void _run(CliArguments parsedArgs) {
  final stopwatch = Stopwatch()..start();

  final isRecursive = parsedArgs.recursive ?? kDefaultRecursive;
  final isVerbose = parsedArgs.verbose ?? kDefaultVerbose;

  if (isVerbose) {
    logger.setFilterLevel(Level.all);
  }

  final hasClassFile = parsedArgs.classFile != null;
  if (hasClassFile && !parsedArgs.classFile!.existsSync()) {
    parsedArgs.classFile!.createSync(recursive: true);
  } else if (hasClassFile) {
    logger.t(
        'Output file for a Flutter class already exists (${parsedArgs.classFile!.path}) - '
        'overwriting it');
  }

  if (!parsedArgs.fontFile.existsSync()) {
    parsedArgs.fontFile.createSync(recursive: true);
  } else {
    logger.t(
        'Output file for a font file already exists (${parsedArgs.fontFile.path}) - '
        'overwriting it');
  }

  final svgFileList = parsedArgs.svgDir
      .listSync(recursive: isRecursive)
      .where((e) => p.extension(e.path).toLowerCase() == '.svg')
      .toList();

  if (svgFileList.isEmpty) {
    logger.w(
        "The input directory doesn't contain any SVG file (${parsedArgs.svgDir.path}).");
  }

  // Modify this part to maintain folder structure information
  final svgMap = <String, Map<String, String>>{
    'root': {},
  };

  for (final f in svgFileList) {
    final relativePath = p.relative(f.path, from: parsedArgs.svgDir.path);
    final folders = p.split(p.dirname(relativePath));
    final fileName = p.basenameWithoutExtension(f.path);

    if (folders.length == 1 && folders[0] == '.') {
      // Root level SVG
      svgMap['root']![fileName] = File(f.path).readAsStringSync();
    } else {
      // Nested SVG
      final folderPath = folders.join('_');
      svgMap.putIfAbsent(folderPath, () => {});
      svgMap[folderPath]![fileName] = File(f.path).readAsStringSync();
    }
  }

  final otfResult = svgToOtf(
    svgMap: svgMap.values
        .fold<Map<String, String>>({}, (map, subMap) => map..addAll(subMap)),
    ignoreShapes: parsedArgs.ignoreShapes,
    normalize: parsedArgs.normalize,
    fontName: parsedArgs.fontName,
  );

  writeToFile(parsedArgs.fontFile.path, otfResult.font);

  if (parsedArgs.classFile == null) {
    logger.t('No output path for Flutter class was specified - '
        'skipping class generation.');
  } else {
    final fontFileName = p.basename(parsedArgs.fontFile.path);

    // Modify this to generate hierarchical classes
    var classString = generateFlutterClassHierarchy(
      glyphList: otfResult.glyphList,
      folderStructure: svgMap,
      fontFileName: fontFileName,
      fontFamily: otfResult.font.familyName,
      className: parsedArgs.className,
    );

    if (parsedArgs.format ?? kDefaultFormat) {
      try {
        logger.t('Formatting Flutter class generation.');
        classString = formatter.format(classString);
      } on Object catch (e) {
        logger.e(e.toString());
      }
    }

    parsedArgs.classFile!.writeAsStringSync(classString);
  }

  logger.i('Generated in ${stopwatch.elapsedMilliseconds}ms');
}

void _printHelp() {
  _printUsage();
  exit(exitCode);
}

void _usageError(String error) {
  _printUsage(error);
  exit(64);
}

void _printUsage([String? error]) {
  final message = error ?? _kAbout;

  stdout.write('''
$message

$_kUsage
${_argParser.usage}
''');
  exit(64);
}

const _kAbout =
    'Converts .svg icons to an OpenType font and generates Flutter-compatible class.';

const _kUsage = '''
Usage:   icon_font_generator <input-svg-dir> <output-font-file> [options]

Example: icon_font_generator assets/svg/ fonts/my_icons_font.otf --output-class-file=lib/my_icons.dart

Converts every .svg file from <input-svg-dir> directory to an OpenType font and writes it to <output-font-file> file.
If "--output-class-file" option is specified, Flutter-compatible class that contains identifiers for the icons is generated.
''';
