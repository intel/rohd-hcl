// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_test.dart
// Tests of Floating Point stuff
//
// 2024 August 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

// ignore_for_file: avoid_print

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Helper evaluation methods for printing aligned arithmetic bitvectors.
extension NumericVector on LogicValue {
  /// Print aligned bitvector with an optional header.
  /// [name] is printed at the LHS of the line, trimmed by [prefix].
  /// [prefix] is the distance from the margin bebore the vector is printed.
  /// You can align with longer bitvectors by stating the length [alignHigh].
  /// [alignLow] will trim the vector below this bit position.
  /// You can insert a separator [sepChar] at position [sepPos].
  /// A header can be printed by setting [header] to true.
  /// Markdown format can be produced by setting [markDown] to true.
  String vecString(String name,
      {int prefix = 10,
      int? alignHigh,
      int? sepPos,
      bool header = false,
      String sepChar = '*',
      int alignLow = 0,
      bool markDown = false}) {
    final str = StringBuffer();
    final minHigh = min(alignHigh ?? width, width);
    final length = BigInt.from(minHigh).toString().length + 1;
    // ignore: cascade_invocations
    const hdrSep = '| ';
    const hdrSepStart = '| ';
    const hdrSepEnd = '|';

    final highLimit = ((alignHigh ?? width) - width) + width - 1;

    if (header) {
      str.write(markDown ? '$hdrSepStart Name' : ' ' * prefix);

      for (var col = highLimit; col >= alignLow; col--) {
        final chars = BigInt.from(col).toString().length + 1;
        if (sepPos != null && sepPos == col) {
          str
            ..write(markDown ? ' $hdrSep' : ' ' * (length - chars + 2))
            ..write('$col$sepChar')
            ..write(markDown ? ' $hdrSep' : '');
        } else if (sepPos != null && sepPos == col + 1) {
          if (sepPos == max(alignHigh ?? width, width)) {
            str
              ..write(sepChar)
              ..write(markDown ? ' $hdrSep' : ' ' * (length - chars - 1));
          }
          str.write('${' ' * (length - chars + 1)}$col');
        } else {
          str
            ..write(markDown ? ' $hdrSep' : ' ' * (length - chars + 2))
            ..write('$col');
        }
      }
      str.write(markDown ? ' $hdrSepEnd\n' : '\n');
      if (markDown) {
        str.write(markDown ? '|:--:' : ' ' * prefix);
        for (var col = highLimit; col >= alignLow; col--) {
          str.write('|:--');
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
    str
      ..write(strPrefix)
      ..write((markDown ? dataSep : ' ' * (length + 1)) *
          ((alignHigh ?? width) - width));
    for (var col = alignLow; col < minHigh; col++) {
      final pos = minHigh - 1 - col + alignLow;
      final v = this[pos].bitString;
      if (sepPos != null && sepPos == pos) {
        str.write(
            markDown ? ' $dataSep$v $sepChar' : '${' ' * length}$v$sepChar');
      } else if (sepPos != null && sepPos == pos + 1) {
        if (sepPos == minHigh) {
          str.write(sepChar);
        }
        str
          ..write(markDown ? ' $dataSep' : ' ' * (length - 1))
          ..write(v);
      } else {
        str
          ..write(markDown ? ' $dataSep' : ' ' * length)
          ..write(v);
      }
    }
    if (markDown) {
      str.write(' $dataSepEnd');
    }
    return str.toString();
  }
}

void main() {
  final lv0 = LogicValue.ofInt(42, 15);
  final lv1 = LogicValue.ofInt(117, 15);
  // No separator
  print(lv0.vecString('lv0', header: true));
  print(lv1.vecString('lv1_with_ridiculously_long_name'));
  // Separator
  print(lv0.vecString('lv0', sepPos: 8));
  print(lv1.vecString('lv1_with_ridiculously_long_name', sepPos: 8));
  print(lv1.vecString('lv1_with_ridiculously_long_name', sepPos: 8));
  // separator at double-digits
  print(lv0.vecString('lv0', sepPos: 12, alignHigh: 24, header: true));
  print(lv1.vecString('lv1_with_ridiculously_long_name',
      alignHigh: 24, sepPos: 12));
  // transition to single-digit separator
  print(lv0.vecString('lv0', sepPos: 10, alignHigh: 24, header: true));
  print(lv1.vecString('lv1_with_ridiculously_long_name',
      alignHigh: 24, sepPos: 10));
  print(lv0.vecString('lv0', sepPos: 9, alignHigh: 24, header: true));
  print(lv1.vecString('lv1_with_ridiculously_long_name',
      alignHigh: 24, sepPos: 9));
  // Single digit separator
  print(lv0.vecString('lv0', sepPos: 8, alignHigh: 24, header: true));
  print(lv1.vecString('lv1_with_ridiculously_long_name',
      alignHigh: 24, sepPos: 8));
  // Separator at zero
  print(lv0.vecString('lv0', sepPos: 0, alignHigh: 24, header: true));
  print(lv1.vecString('lv1_with_ridiculously_long_name',
      alignHigh: 24, sepPos: 0));
  final ref = FloatingPoint64Value.fromDouble(3.14159);
  print(ref);
  print(ref.mantissa
      .vecString('reference', alignLow: 31, header: true, sepPos: 52));
  print('');

  print(ref.mantissa.vecString('reference',
      alignLow: 31, header: true, sepPos: 48, markDown: true));
  print('');
  final lv2 = LogicValue.ofInt(42, 12);
  print(lv2.vecString('lv2', header: true, markDown: true));
  for (var i = lv2.width; i >= 0; i--) {
    print(lv2.vecString('lv2', sepPos: i, markDown: true));
  }
}
