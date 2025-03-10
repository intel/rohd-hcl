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
extension EvaluateLiveColumnCompressor on ColumnCompressor {
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
      int extraSpace = 0}) {
    final ts = StringBuffer();
    final rows = longestColumn();
    final width = pp.maxWidth();
    var accum = BigInt.zero;

    for (var row = 0; row < rows; row++) {
      final int shift;
      if (row >= pp.rows) {
        shift = pp.rowShift[pp.rows - 1];
      } else {
        shift = pp.rowShift[row];
      }
      final rowLogic = <Logic>[];
      for (var col = columns.length - 1; col >= 0; col--) {
        final colList = carryColumns[col].toList() + columns[col].toList();
        if (row < colList.length) {
          rowLogic.insert(0, colList[row].logic);
        } else if (col >= shift) {
          // rowLogic.insert(0, Const(0));
        }
      }
      final rowBits = [for (final c in rowLogic) c.value].reversed.toList()
        ..addAll(List.filled(shift, LogicValue.zero));
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
            shift: shift))
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
  String representation({bool evalLogic = false, bool useTabs = true}) {
    final ts = StringBuffer();

    final sep = useTabs ? '\t' : '  ';

    for (var row = 0; row < longestColumn(); row++) {
      ts.write(useTabs ? '' : ' ');
      for (var col = columns.length - 1; col >= 0; col--) {
        final colList = columns[col].toList() + carryColumns[col].toList();
        if (row < colList.length) {
          if (evalLogic) {
            ts.write('$sep${colList[row].logic.value.toInt()}');
          } else {
            ts.write('$sep${colList[row]}');
          }
        } else {
          ts.write(useTabs ? sep : '$sep ');
        }
      }
      ts.write('\n');
    }
    return ts.toString();
  }
}
