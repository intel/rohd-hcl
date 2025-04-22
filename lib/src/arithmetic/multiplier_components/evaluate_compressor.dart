// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// addend_compressor.dart
// Column compression of partial prodcuts
//
// 2024 June 04
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/arithmetic.dart';

/// Debug routines for printing out ColumnCompressor during
/// simulation with live logic values
extension EvaluateLiveColumnCompressor on ColumnCompressorModule {
  /// Evaluate the (un)compressed partial product array
  /// [logic] =true will read the logic gate outputs at each level
  /// [printOut]=true will print out the array in the StringBuffer
  /// [extraSpace] add spacing for readability
  /// [header] add a header for the column position
  /// [prefix] add a prefix count of spaces
  (BigInt, StringBuffer) evaluate(
      {bool printOut = false,
      bool logic = false,
      bool header = true,
      int prefix = 1,
      int extraSpace = 5}) {
    final ts = StringBuffer();
    final rows = longestColumn();
    final width = maxWidth();
    var accum = BigInt.zero;

    for (var row = 0; row < rows; row++) {
      final rowLogic = <Logic>[];
      for (var col = columns.length - 1; col >= 0; col--) {
        final colList = columns[col].toList();
        if (row < colList.length) {
          rowLogic.insert(0, colList[row].logic);
        }
      }
      final rowBits = [for (final c in rowLogic) c.value].reversed.toList();
      // ignore: cascade_invocations
      rowBits.addAll(List.filled(rowShift[row], LogicValue.zero));
      final rowBitsExtend = rowBits.length < width
          ? rowBits.swizzle().zeroExtend(width)
          : rowBits.swizzle();
      final val = rowBitsExtend.toBigInt();
      accum += val;
      ts
        ..write(rowLogic.listString('',
            header: header & (row == 0),
            alignHigh: width,
            prefix: prefix,
            extraSpace: extraSpace,
            intValue: true,
            shift: rowShift[row]))
        ..write('\n');
    }

    final sum = Logic(width: width);
    // ignore: cascade_invocations
    sum.put(accum.toSigned(width));
    ts.write(sum.elements
        .listString('p', prefix: 1, extraSpace: extraSpace, intValue: true));

    return (sum.value.toBigInt().toSigned(width), ts);
  }

  /// Return a string representing the compression tree in its current state
  String representation() {
    final ts = StringBuffer();
    for (var row = 0; row < longestColumn(); row++) {
      for (var col = columns.length - 1; col >= 0; col--) {
        final colList = columns[col].toList();
        if (row < colList.length) {
          ts.write('\t${colList[row]}');
        } else {
          ts.write('\t');
        }
      }
      ts.write('\n');
    }
    return ts.toString();
  }
}
