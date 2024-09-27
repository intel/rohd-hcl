// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_test.dart
// Tests of Floating Point stuff
//
// 2024 August 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

// ignore_for_file: avoid_print

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Helper evaluation methods for printing aligned arithmetic bitvectors.
extension NumericVector on LogicValue {
  /// Print aligned bitvector with an optional header.
  /// [name] is printed at the LHS of the line, trimmed by [prefix].
  /// [prefix] is the distance from the margin bebore the vector is printed.
  /// You can align with longer bitvectors by stating the length [align].
  /// You can insert a separator [sepChar] at position [sep].
  /// A header can be printed by setting [header] to true.
  String vecString(String name,
      {int prefix = 10,
      int? align,
      int? sep,
      bool header = false,
      String sepChar = '|',
      int lowLimit = 0}) {
    final str = StringBuffer();
    // ignore: cascade_invocations
    if (header) {
      str.write(' ' * prefix);

      for (var col = ((align ?? width) - width) + width - 1;
          col >= lowLimit;
          col--) {
        final bits = col > 9 ? 2 : 1;
        if (sep != null && sep == col) {
          str.write(' ' * (2 - bits));
          if (col > 10 || col == lowLimit) {
            str.write(' $col$sepChar');
          } else {
            str.write(' $col $sepChar');
          }
        } else if (sep != null && sep == col + 1) {
          if (sep == width) {
            str
              ..write(sepChar)
              ..write(' ' * (2 - bits));
          }
          str.write('$col');
        } else {
          str
            ..write(' ' * (2 - bits))
            ..write(' $col');
        }
      }
      str.write('\n');
    }
    final String strPrefix;
    strPrefix = (name.length <= prefix)
        ? name.padRight(prefix)
        : name.substring(0, prefix);
    str
      ..write(strPrefix)
      ..write('   ' * ((align ?? width) - width));
    for (var col = lowLimit; col < width; col++) {
      final pos = width - 1 - col + lowLimit;
      final v = this[pos].bitString;
      if (sep != null && sep == pos) {
        str.write(
            ((pos > 10) | (pos == 0)) ? '  $v$sepChar ' : '  $v $sepChar');
      } else if (sep != null && sep == pos + 1) {
        if (sep == width) {
          str.write('$sepChar ');
        }
        str.write(v);
      } else {
        str.write('  $v');
      }
    }
    return str.toString();
  }
}

// void main() {
//   final lv0 = LogicValue.ofInt(42, 15);
//   final lv1 = LogicValue.ofInt(117, 15);
//   // No separator
//   print(lv0.vecString('lv0', header: true));
//   print(lv1.vecString('lv1_with_ridiculously_long_name'));
//   // Separator
//   print(lv0.vecString('lv0', sep: 8));
//   print(lv1.vecString('lv1_with_ridiculously_long_name', sep: 8));
//   print(lv1.vecString('lv1_with_ridiculously_long_name', sep: 8));
//   // separator at double-digits
//   print(lv0.vecString('lv0', sep: 12, align: 24, header: true));
//   print(lv1.vecString('lv1_with_ridiculously_long_name', align: 24, sep: 12));
//   // transition to single-digit separator
//   print(lv0.vecString('lv0', sep: 10, align: 24, header: true));
//   print(lv1.vecString('lv1_with_ridiculously_long_name', align: 24, sep: 10));
//   print(lv0.vecString('lv0', sep: 9, align: 24, header: true));
//   print(lv1.vecString('lv1_with_ridiculously_long_name', align: 24, sep: 9));
//   // Single digit separator
//   print(lv0.vecString('lv0', sep: 8, align: 24, header: true));
//   print(lv1.vecString('lv1_with_ridiculously_long_name', align: 24, sep: 8));
//   // Separator at zero
//   print(lv0.vecString('lv0', sep: 0, align: 24, header: true));
//   print(lv1.vecString('lv1_with_ridiculously_long_name', align: 24, sep: 0));
//   final ref = FloatingPoint64Value.fromDouble(3.14159);
//   print(ref);
//   print(
//       ref.mantissa.vecString('reference', lowLimit: 31, header: true, sep: 52));
//   print(
//       ref.mantissa.vecString('reference', lowLimit: 31, header: true, sep: 48));

//   final lv2 = LogicValue.ofInt(42, 8);
//   print(lv2.vecString('lv2', header: true));
//   for (var i = lv2.width; i >= 0; i--) {
//     print(lv2.vecString('lv2', sep: i));
//   }
// }
