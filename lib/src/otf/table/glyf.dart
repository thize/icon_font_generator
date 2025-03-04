import 'dart:math' as math;
import 'dart:typed_data';

import '../../../icon_font_generator.dart';
import '../../common/generic_glyph.dart';
import '../../utils/otf.dart';
import '../debugger.dart';
import 'abstract.dart';
import 'glyph/header.dart';
import 'glyph/simple.dart';
import 'loca.dart';
import 'table_record_entry.dart';

class GlyphDataTable extends FontTable {
  GlyphDataTable(
    TableRecordEntry? entry,
    this.glyphList,
  ) : super.fromTableRecordEntry(entry);

  factory GlyphDataTable.fromByteData(ByteData byteData, TableRecordEntry entry,
      IndexToLocationTable locationTable, int numGlyphs) {
    final glyphList = <SimpleGlyph>[];

    for (var i = 0; i < numGlyphs; i++) {
      final headerOffset = entry.offset + locationTable.glyphOffsets[i];
      final nextHeaderOffset = entry.offset + locationTable.glyphOffsets[i + 1];
      final isEmpty = headerOffset == nextHeaderOffset;

      final header = GlyphHeader.fromByteData(byteData, headerOffset);

      if (header.isComposite) {
        debugUnsupportedFeature(
            'Composite glyph (glyph header offset $headerOffset)');
      } else {
        final glyph = isEmpty
            ? SimpleGlyph.empty()
            : SimpleGlyph.fromByteData(byteData, header, headerOffset);
        glyphList.add(glyph);
      }
    }

    return GlyphDataTable(entry, glyphList);
  }

  factory GlyphDataTable.fromGlyphs(List<GenericGlyph> glyphList) {
    final glyphListCopy = glyphList.map((e) => e.copy());

    for (final glyph in glyphListCopy) {
      for (final outline in glyph.outlines) {
        if (!outline.hasQuadCurves) {
          // Convert cubic curves to quadratic curves
          _cubicToQuadratic(outline);
        }

        outline.compactImplicitPoints();
      }
    }

    final simpleGlyphList =
        glyphListCopy.map((e) => e.toSimpleTrueTypeGlyph()).toList();

    return GlyphDataTable(null, simpleGlyphList);
  }

  /// Converts cubic Bézier curves to quadratic ones in the given outline.
  ///
  /// This uses a simple approximation method that minimizes the maximum error
  /// between the original cubic curve and the resulting quadratic curve.
  static void _cubicToQuadratic(Outline outline) {
    if (outline.hasQuadCurves) {
      return; // Already has quadratic curves
    }

    // Decompact any implicit points if needed
    if (outline.hasCompactCurves) {
      outline.decompactImplicitPoints();
    }

    final pointList = outline.pointList;
    final isOnCurveList = outline.isOnCurveList;

    // We'll build new lists as we process the outline
    final newPointList = <math.Point<num>>[];
    final newIsOnCurveList = <bool>[];

    // Add the first point
    if (pointList.isNotEmpty) {
      newPointList.add(pointList.first);
      newIsOnCurveList.add(isOnCurveList.first);
    }

    // Process each segment
    for (var i = 1; i < pointList.length; i++) {
      if (isOnCurveList[i]) {
        // On-curve point - just add it
        newPointList.add(pointList[i]);
        newIsOnCurveList.add(true);
      } else if (!isOnCurveList[i] &&
          i + 2 < pointList.length &&
          !isOnCurveList[i + 1]) {
        // Found a cubic segment (two off-curve points followed by an on-curve point)
        final p0 = newPointList.last;
        final p1 = pointList[i]; // First control point
        final p2 = pointList[i + 1]; // Second control point
        final p3 = pointList[i + 2]; // End point

        // Calculate the quadratic control point that best approximates the cubic curve
        // Using the formula: q = (3*(p1+p2) - (p0+p3)) / 4
        final qx = (3 * (p1.x + p2.x) - (p0.x + p3.x)) / 4;
        final qy = (3 * (p1.y + p2.y) - (p0.y + p3.y)) / 4;
        final q = math.Point<num>(qx, qy);

        // Add the quadratic control point and the end point
        newPointList.add(q);
        newIsOnCurveList.add(false); // Off-curve control point

        newPointList.add(p3);
        newIsOnCurveList.add(true); // On-curve end point

        // Skip the processed points
        i += 2;
      } else {
        // Single off-curve point - treat as quadratic control point
        newPointList.add(pointList[i]);
        newIsOnCurveList.add(false);
      }
    }

    // Replace the outline's points with our new approximated quadratic curve
    outline.pointList
      ..clear()
      ..addAll(newPointList);

    outline.isOnCurveList
      ..clear()
      ..addAll(newIsOnCurveList);

    // Update the outline's curve type
    outline.decompactImplicitPoints();
    // outline.hasQuadCurves = true;
  }

  final List<SimpleGlyph> glyphList;

  @override
  int get size =>
      glyphList.fold<int>(0, (p, v) => p + getPaddedTableSize(v.size));

  int get maxPoints =>
      glyphList.fold<int>(0, (p, g) => math.max(p, g.pointList.length));

  int get maxContours =>
      glyphList.fold<int>(0, (p, g) => math.max(p, g.header.numberOfContours));

  int get maxSizeOfInstructions =>
      glyphList.fold<int>(0, (p, g) => math.max(p, g.instructions.length));

  @override
  void encodeToBinary(ByteData byteData) {
    var offset = 0;

    for (final glyph in glyphList) {
      if (glyph.isEmpty) {
        continue;
      }

      glyph.encodeToBinary(byteData.sublistView(offset, glyph.size));
      offset += getPaddedTableSize(glyph.size);
    }
  }
}
