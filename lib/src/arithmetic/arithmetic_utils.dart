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
    final length =
        BigInt.from(min(alignHigh ?? width, width)).toString().length + 1;
    // ignore: cascade_invocations
    if (header) {
      str.write(markDown ? '| Name' : ' ' * prefix);

      for (var col = ((alignHigh ?? width) - width) + width - 1;
          col >= alignLow;
          col--) {
        final chars = BigInt.from(col).toString().length + 1;
        if (sepPos != null && sepPos == col) {
          str
            ..write(markDown ? ' | ' : ' ' * (length - chars + 2))
            ..write('$col$sepChar')
            ..write(markDown ? ' | ' : '');
        } else if (sepPos != null && sepPos == col + 1) {
          if (sepPos == max(alignHigh ?? width, width)) {
            str
              ..write(sepChar)
              ..write(markDown ? ' | ' : ' ' * (length - chars - 1));
          }
          str.write('${' ' * (length - chars + 1)}$col');
        } else {
          // untested
          str
            ..write(markDown ? ' | ' : ' ' * (length - chars + 2))
            ..write('$col');
        }
      }
      str.write(markDown ? ' |\n' : '\n');
      if (markDown) {
        str.write(markDown ? '|:--:' : ' ' * prefix);

        for (var col = ((alignHigh ?? width) - width) + width - 1;
            col >= alignLow;
            col--) {
          str.write('|:--');
        }
        str.write('-|\n');
      }
    }
    final String strPrefix;
    strPrefix = markDown
        ? name
        : (name.length <= prefix)
            ? name.padRight(prefix)
            : name.substring(0, prefix);

    str
      ..write(strPrefix)
      ..write((markDown ? '|' : ' ' * (length + 1)) *
          ((alignHigh ?? width) - width));
    for (var col = alignLow; col < min(alignHigh ?? width, width); col++) {
      final pos = min(alignHigh ?? width, width) - 1 - col + alignLow;
      final chars = BigInt.from(pos).toString().length + 1;
      final v = this[pos].bitString;
      if (sepPos != null && sepPos == pos) {
        if (markDown) {
          str.write(' | $v $sepChar');
        } else {
          str.write('${' ' * length}$v$sepChar');
        }
      } else if (sepPos != null && sepPos == pos + 1) {
        if (sepPos == min(alignHigh ?? width, width)) {
          str.write(sepChar);
        }
        if (markDown) {
          str.write(' | ');
        } else {
          str.write(' ' * (length - 1));
        }
        str.write(v);
      } else {
        if (markDown) {
          str.write(' | ');
        } else {
          str.write(' ' * length);
        }
        str.write(v);
      }
    }
    if (markDown) {
      str.write(' |');
    }
    return str.toString();
  }
}
