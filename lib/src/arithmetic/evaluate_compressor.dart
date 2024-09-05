// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// addend_compressor.dart
// Column compression of partial prodcuts
//
// 2024 June 04
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/multiplier_lib.dart';
import 'package:rohd_hcl/src/utils.dart';

/// Debug routines for printing out ColumnCompressor during
/// simulation with live logic values
extension EvaluateLiveColumnCompressor on ColumnCompressor {
  /// Evaluate the (un)compressed partial product array
  ///    logic=true will read the logic gate outputs at each level
  ///    printOut=true will print out the array in the StringBuffer
  (BigInt, StringBuffer) evaluate({bool printOut = false, bool logic = false}) {
    final ts = StringBuffer();
    final rows = longestColumn();
    final width = pp.maxWidth();

    var accum = BigInt.zero;
    for (var row = 0; row < rows; row++) {
      final rowBits = <LogicValue>[];
      for (var col = columns.length - 1; col >= 0; col--) {
        final colList = columns[col].toList();
        if (row < colList.length) {
          final value =
              logic ? colList[row].logic.value : (colList[row].evaluate());
          rowBits.add(value);
          if (printOut) {
            ts.write('\t${value.bitString}');
          }
        } else if (printOut) {
          ts.write('\t');
        }
      }
      rowBits.addAll(List.filled(pp.rowShift[row], LogicValue.zero));
      final val = rowBits.swizzle().zeroExtend(width).toBigInt();
      accum += val;
      if (printOut) {
        ts.write('\t${rowBits.swizzle().zeroExtend(width).bitString} ($val)');
        if (row == rows - 1) {
          ts.write(' Total=${accum.toSigned(width)}\n');
          stdout.write(ts);
        } else {
          ts.write('\n');
        }
      }
    }
    if (printOut) {
      // We need this to be able to debug, but git lint flunks print
      // print(ts);
    }
    return (accum.toSigned(width), ts);
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
