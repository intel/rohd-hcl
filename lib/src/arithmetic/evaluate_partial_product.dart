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
    return signed ? sum.toSigned(maxW) : sum;
  }

  /// Print out the partial product matrix
  String representation() {
    final str = StringBuffer();

    final maxW = maxWidth();
    final nonSignExtendedPad = isSignExtended
        ? 0
        : shift > 2
            ? shift - 1
            : 1;
    // We will print encoding(1-hot multiples and sign) before each row
    final shortPrefix = '99 ${'M='}99 S= : '.length + 3 * nonSignExtendedPad;

    // print bit position header
    str.write(' ' * shortPrefix);
    for (var i = maxW - 1; i >= 0; i--) {
      final bits = i > 9 ? 2 : 1;
      str
        ..write('$i')
        ..write(' ' * (3 - bits));
    }
    str.write('\n');
    // Partial product matrix:  rows of multiplicand multiples shift by
    //    rowshift[row]
    for (var row = 0; row < rows; row++) {
      final rowStr = (row < 10) ? '0$row' : '$row';
      if (row < encoder.rows) {
        final encoding = encoder.getEncoding(row);
        if (encoding.multiples.value.isValid) {
          final first = encoding.multiples.value.firstOne() ?? -1;
          final multiple = first + 1;
          str.write('$rowStr M='
              '${multiple.toString().padLeft(2)} '
              'S=${encoding.sign.value.toInt()}: ');
        } else {
          str.write(' ' * shortPrefix);
        }
      } else {
        str.write('$rowStr ${'M='}   S= : ');
      }
      final entry = partialProducts[row].reversed.toList();
      final prefixCnt =
          maxW - (entry.length + rowShift[row]) + nonSignExtendedPad;
      str.write('   ' * prefixCnt);
      for (var col = 0; col < entry.length; col++) {
        str.write('${entry[col].value.bitString}  ');
      }
      final suffixCnt = rowShift[row];
      final value = entry.swizzle().value.zeroExtend(maxW) << suffixCnt;
      final intValue = value.isValid ? value.toBigInt() : BigInt.from(-1);
      str
        ..write('   ' * suffixCnt)
        ..write(': ${value.bitString}')
        ..write(' = ${value.isValid ? intValue : "<invalid>"}'
            ' (${value.isValid ? intValue.toSigned(maxW) : "<invalid>"})\n');
    }
    // Compute and print binary representation from accumulated value
    // Later: we will compare with a compression tree result
    str
      ..write('=' * (shortPrefix + 3 * maxW))
      ..write('\n')
      ..write(' ' * shortPrefix);

    final sum = LogicValue.ofBigInt(evaluate(), maxW);
    // print out the sum as a MSB-first bitvector
    for (final elem in [for (var i = 0; i < maxW; i++) sum[i]].reversed) {
      str.write('${elem.toInt()}  ');
    }
    final val = evaluate();
    str.write(': ${sum.bitString} = '
        '${val.toUnsigned(maxW)}');
    if (isSignExtended) {
      str.write(' ($val)\n\n');
    }
    return str.toString();
  }

  /// Print out the partial product matrix
  String markdown() {
    final str = StringBuffer();

    final maxW = maxWidth();
    // print bit position header
    str.write('| R | M | S');
    for (var i = maxW - 1; i >= 0; i--) {
      str.write('|  $i  ');
    }
    str
      ..write('| bitvector | value|\n')
      ..write('|:--:' * 3);
    for (var i = maxW - 1; i >= 0; i--) {
      str.write('|:--:');
    }
    str.write('|:--: |:--:|\n');
    // Partial product matrix:  rows of multiplicand multiples shift by
    //    rowshift[row]
    for (var row = 0; row < rows; row++) {
      final rowStr = (row < 10) ? '0$row' : '$row';
      if (row < encoder.rows) {
        final encoding = encoder.getEncoding(row);
        if (encoding.multiples.value.isValid) {
          final first = encoding.multiples.value.firstOne() ?? -1;
          final multiple = first + 1;
          str.write('|$rowStr| '
              '$multiple| '
              '${encoding.sign.value.toInt()}');
        } else {
          str.write('|  |  |');
        }
      } else {
        str.write('|$rowStr | |');
      }
      final entry = partialProducts[row].reversed.toList();
      str.write('| ' * (maxW - (entry.length + rowShift[row])));
      for (var col = 0; col < entry.length; col++) {
        str.write('|${entry[col].value.bitString}');
      }
      final suffixCnt = rowShift[row];
      final value = entry.swizzle().value.zeroExtend(maxW) << suffixCnt;
      final intValue = value.isValid ? value.toBigInt() : BigInt.from(-1);
      str
        ..write('|   ' * suffixCnt)
        ..write('| ${value.bitString}')
        ..write('| ${value.isValid ? intValue : "<invalid>"}'
            ' (${value.isValid ? intValue.toSigned(maxW) : "<invalid>"})|\n');
    }
    // Compute and print binary representation from accumulated value
    // Later: we will compare with a compression tree result
    str.write('||\n');

    final sum = LogicValue.ofBigInt(evaluate(), maxW);
    // print out the sum as a MSB-first bitvector
    str.write('|||');
    for (final elem in [for (var i = 0; i < maxW; i++) sum[i]].reversed) {
      str.write('|${elem.toInt()} ');
    }
    final val = evaluate();
    str.write('| ${sum.bitString}| '
        '${val.toUnsigned(maxW)}');
    if (isSignExtended) {
      str.write(' ($val)');
    }
    str.write('|\n');
    return str.toString();
  }
}
