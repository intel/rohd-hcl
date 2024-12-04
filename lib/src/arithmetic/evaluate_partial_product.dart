// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// partial_product_generator.dart
// Partial Product matrix generation from Booth recoded multiplicand
//
// 2024 May 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// The following routines are useful only during testing
extension TestPartialProductSignage on PartialProductGenerator {
  /// Return true if multiplicand is truly signed (fixed or runtime)
  bool isSignedMultiplicand() => (selectSignedMultiplicand == null)
      ? signedMultiplicand
      : !selectSignedMultiplicand!.value.isZero;

  /// Return true if multiplier is truly signed (fixed or runtime)
  bool isSignedMultiplier() => (selectSignedMultiplier == null)
      ? signedMultiplier
      : !selectSignedMultiplier!.value.isZero;

  /// Return true if accumulate result is truly signed (fixed or runtime)
  bool isSignedResult() => isSignedMultiplicand() | isSignedMultiplier();
}

/// Debug routines for printing out partial product matrix during
/// simulation with live logic values
extension EvaluateLivePartialProduct on PartialProductGenerator {
  /// Accumulate the partial products and return as BigInt
  BigInt evaluate() {
    final maxW = maxWidth();
    var accum = BigInt.from(0);
    for (var row = 0; row < rows; row++) {
      final pp = partialProducts[row].rswizzle().value;
      final value = pp.zeroExtend(maxW) << rowShift[row];
      if (pp.isValid) {
        accum += value.toBigInt();
      }
    }
    final sum = LogicValue.ofBigInt(accum, maxW).toBigInt();
    return isSignedMultiplicand() | isSignedMultiplier()
        ? sum.toSigned(maxW)
        : sum;
  }

  /// Print out the partial product matrix
  /// [bitvector] = true will print out a compact bitvector to the right
  /// [value] = true will print out the value of each row as 'unsigned (signed)'
  String markdown({bool bitvector = false, bool value = true}) =>
      representation(markDown: true, bitvector: bitvector, value: value);

  /// Return a string representation of the partial product array.
  ///   S = Sign bit positive polarity = 1 final value)
  ///   s = Sign bit positive polarity = 0 final value)
  ///   I = Sign bit negative polarity = 1 final value)
  ///   i = Sign bit negative polarity = 0 (final value)
  ///   [bitvector] = true will print out a compact final bitvector array
  ///   [value] = true will print out the numerical value of the bitvector as
  ///  'unsigned (signed)
  String representation(
      {bool markDown = false, bool bitvector = false, bool value = true}) {
    final str = StringBuffer();
    const prefixCnt = 20;

    for (var row = 0; row < rows; row++) {
      final rowStr = row.toString().padLeft(2);
      final name = StringBuffer();
      if (row < encoder.rows) {
        final encoding = encoder.getEncoding(row);
        var multipleString = '';
        var signString = ' ';
        if (encoding.multiples.value.isValid) {
          final first = encoding.multiples.value.firstOne() ?? -1;
          final multiple = first + 1;
          multipleString = multiple.toString();
          signString = encoding.sign.value.toInt().toString();
        }
        name.write('$rowStr M='
            '${multipleString.padLeft(3)} '
            'S=$signString');
      }
      str
        ..write(partialProducts[row].listString(name.toString(),
            header: row == 0,
            alignHigh: maxWidth(),
            prefix: prefixCnt,
            shift: rowShift[row],
            markDown: markDown,
            intValue: true))
        ..write('\n');
    }
    // Need to be consistent with colWidth in LogicValueList.listString
    if (!markDown) {
      const extraSpace = 0;
      final colWidth =
          BigInt.from(maxWidth()).toString().length + 1 + extraSpace;
      str
        ..write('=' * (colWidth * maxWidth() + prefixCnt))
        ..write('\n');
    }
    final sum = Logic(width: maxWidth());
    // ignore: cascade_invocations
    sum.put(LogicValue.ofBigInt(evaluate(), maxWidth()));
    str.write(sum.elements.listString('product',
        prefix: prefixCnt,
        alignHigh: maxWidth(),
        markDown: markDown,
        intValue: true));
    return str.toString();
  }
}
