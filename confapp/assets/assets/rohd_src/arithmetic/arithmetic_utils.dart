// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// arithmetic_utils.dart
// Utlities for arithmetic visualization
//
// 2024 August 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Helper evaluation methods for printing aligned arithmetic bitvectors.
extension LogicList on List<Logic> {
  /// Print aligned bitvector with an optional header from [List<Logic>].
  /// [name] is printed at the LHS of the line, trimmed by [prefix].
  /// [prefix] is the distance from the margin bebore the vector is printed.
  /// [alignHigh] is highest column (MSB) to which to align
  /// [alignLow] will trim the vector below this bit position (LSB).
  /// [shift] will allow you to shift your list positions
  /// You can insert a separator [sepChar] at position [sepPos].
  /// A header can be printed by setting [header] to `true`.
  /// Markdown format can be produced by setting [markDown] to `true`.
  /// The output can have space by setting [extraSpace]
  /// if [intValue] is `true`, then the integer value (signed version in parens)
  /// will be printed at the end of the vector.
  String listString(String name,
      {int prefix = 10,
      int? alignHigh,
      int? sepPos,
      bool header = false,
      String sepChar = '*',
      int alignLow = 0,
      int extraSpace = 0,
      int shift = 0,
      bool intValue = false,
      bool markDown = false}) {
    final str = StringBuffer();
    final maxHigh = max(alignHigh ?? length, length);
    final minHigh = min(alignHigh ?? length, length) - shift;
    final colWidth = BigInt.from(maxHigh).toString().length + extraSpace;
    const hdrSep = '| ';
    const hdrSepStart = '| ';
    const hdrSepEnd = '|';

    if (markDown && sepChar.contains('|')) {
      throw RohdHclException('markDown cannot use | as a sepChar');
    }

    final highLimit = ((alignHigh ?? length) - length) + length - 1;

    if (header) {
      str.write(markDown ? '$hdrSepStart Name' : ' ' * prefix);

      for (var col = highLimit; col >= alignLow; col--) {
        final chars = BigInt.from(col).toString().length + extraSpace;
        if (sepPos != null && sepPos == col) {
          str
            ..write(markDown
                ? ' $hdrSep'
                : ' ' * (colWidth - chars + 1 + extraSpace))
            ..write('$col$sepChar')
            ..write(markDown ? ' $hdrSep' : '');
        } else if (sepPos != null && sepPos == col + 1) {
          if (sepPos == max(alignHigh ?? length, length)) {
            str
              ..write(sepChar)
              ..write(markDown ? ' $hdrSep' : ' ' * (colWidth - chars - 1));
          }
          str.write('${' ' * (colWidth - chars + extraSpace + 0)}$col');
        } else {
          str
            ..write(markDown
                ? ' $hdrSep'
                : ' ' * (colWidth - chars + 1 + extraSpace))
            ..write('$col');
        }
      }
      str
        ..write(intValue & markDown ? hdrSepEnd : '')
        ..write(markDown ? hdrSepEnd : '')
        ..write('\n');
      if (markDown) {
        str.write(markDown ? '|:--' : ' ' * prefix);
        for (var col = highLimit; col >= alignLow; col--) {
          str.write('|:--');
        }
        if (intValue) {
          str.write('-|:--');
        }
        str.write('-|\n');
      }
    }
    const dataSepStart = '|';
    const dataSep = '| ';
    const dataSepEnd = '|';
    final String strPrefix;
    strPrefix = markDown
        ? '$dataSepStart $name'
        : (name.length <= prefix)
            ? name.padRight(prefix)
            : name.substring(0, prefix);

    // Column calculations for overlapping vector with range
    final startCol = highLimit;
    final endCol = alignLow;
    final startPos = length + shift - 1;
    final endPos = shift;
    final startOvl = min(startCol, startPos);
    final endOvl = max(endCol, endPos);
    final startIdx = startOvl - shift;
    final endIdx = endOvl - shift;

    final emptyLeft = (startCol - max(alignLow - 1, startOvl)).toInt();
    final emptyRight = min(highLimit + 1, endPos) - endCol;
    str
      ..write(strPrefix)
      ..write((markDown ? dataSepStart : ' ' * (colWidth + 1)) * emptyLeft);

    for (var pos = startIdx; pos >= endIdx; pos--) {
      final bit = this[pos];
      final String v;
      if (bit is SignBit) {
        if (bit.value == LogicValue.zero) {
          v = markDown
              ? bit.inverted
                  ? r'$\overline 0$'
                  : r'$\underline 0$'
              : bit.inverted
                  ? 'i'
                  : 's';
        } else {
          v = markDown
              ? bit.inverted
                  ? r'$\overline 1$'
                  : r'$\underline 1$'
              : bit.inverted
                  ? 'I'
                  : 'S';
        }
      } else {
        v = this[pos].value.bitString;
      }
      if (sepPos != null && sepPos == pos) {
        str.write(
            markDown ? ' $dataSep$v $sepChar' : '${' ' * colWidth}$v$sepChar');
      } else if (sepPos != null && sepPos == pos + 1) {
        if (sepPos == minHigh) {
          str.write(sepChar);
        }
        str
          ..write(markDown ? ' $dataSep' : ' ' * (colWidth - 1))
          ..write(v);
      } else {
        str
          ..write(markDown ? ' $dataSep' : ' ' * colWidth)
          ..write(v);
      }
    }

    str.write(markDown ? dataSepStart : ' ' * emptyRight * (colWidth + 1));
    if (intValue) {
      final vec = (shift >= 0)
          ? this.rswizzle().zeroExtend(maxHigh) << shift
          : this.rswizzle().zeroExtend(maxHigh) >>> -shift;

      final vecC = vec.slice(highLimit, 0);
      final v = vecC.value.toBigInt().toUnsigned(maxHigh);
      final spacer =
          colWidth - ((sepPos != null) && (sepPos == endCol) ? 1 : 0);
      str
        ..write(markDown ? dataSep : '${' ' * spacer} = ')
        ..write('$v (${v.toSigned(maxHigh)})');
    }
    if (markDown) {
      str.write(' $dataSepEnd');
    }
    return str.toString();
  }
}
