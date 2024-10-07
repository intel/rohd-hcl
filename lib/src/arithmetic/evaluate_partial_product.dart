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

  /// Print out the partial product matrix.
  ///   S = Sign bit positive polarity = 1 final value)
  ///   s = Sign bit positive polarity = 0 final value)
  ///   I = Sign bit negative polarity = 1 final value)
  ///   i = Sign bit negative polarity = 0 (final value)
  ///   [bitvector] = true will print out a compact final bitvector array
  ///   [value] = true will print out the numerical value of the bitvector as
  ///  'unsigned (signed)
  String representation({bool bitvector = false, bool value = true}) {
    final str = StringBuffer();

    final maxW = maxWidth();
    final nonSignExtendedPad = isSignExtended
        ? 0
        : shift > 2
            ? shift - 1
            : 1;
    // We will print encoding(1-hot multiples and sign) before each row
    final shortPrefix = '99 ${'M='}99 S=  '.length + 3 * nonSignExtendedPad;

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
              'S=${encoding.sign.value.toInt()} ');
        } else {
          str.write(' ' * shortPrefix);
        }
      } else {
        str.write('$rowStr ${'M='}   S=  ');
      }
      final entry = partialProducts[row].reversed.toList();
      final prefixCnt =
          maxW - (entry.length + rowShift[row]) + nonSignExtendedPad;
      str.write('   ' * prefixCnt);
      for (var col = 0; col < entry.length; col++) {
        final bit = entry[col];
        if (bit is SignBit) {
          final val = bit.value.toInt();
          if (bit.inverted) {
            str.write(val == 0 ? 'i' : 'I');
          } else {
            str.write(val == 0 ? 's' : 'S');
          }
          str.write('  ');
        } else {
          str.write('${entry[col].value.bitString}  ');
        }
      }
      final suffixCnt = rowShift[row];
      final bitVal = entry.swizzle().value.zeroExtend(maxW) << suffixCnt;
      final intValue = bitVal.isValid ? bitVal.toBigInt() : BigInt.from(-1);
      str.write('   ' * suffixCnt);
      if (bitvector) {
        str.write(': ${bitVal.bitString}');
      }
      if (value) {
        str.write(' = ${bitVal.isValid ? intValue : "<invalid>"}'
            ' (${bitVal.isValid ? intValue.toSigned(maxW) : "<invalid>"})');
      }
      str.write('\n');
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
    if (bitvector) {
      str.write(': ${sum.bitString}');
    }
    if (value) {
      str.write(' = '
          '${val.toUnsigned(maxW)}');
      if (isSignExtended) {
        str.write(' ($val)');
      }
    }
    str.write('\n');
    return str.toString();
  }

  /// Print out the partial product matrix
  /// [bitvector] = true will print out a compact bitvector to the right
  /// [value] = true will print out the value of each row as 'unsigned (signed)'
  String markdown({bool bitvector = false, bool value = true}) {
    final str = StringBuffer();

    final maxW = maxWidth();
    // print bit position header
    str.write('| R | M | S');
    for (var i = maxW - 1; i >= 0; i--) {
      str.write('|  $i  ');
    }
    if (bitvector) {
      str.write('| bitvector ');
    }
    if (value) {
      str.write('| value');
    }
    str
      ..write('|\n')
      ..write('|:--:' * 3);
    for (var i = maxW - 1; i >= 0; i--) {
      str.write('|:--:');
    }
    str.write('|');
    if (bitvector) {
      str.write(':--|');
    }
    if (value) {
      str.write(':--|');
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
          str.write('|$rowStr| '
              '$multiple| '
              '${encoding.sign.value.toInt()}');
        } else {
          str.write('|||');
        }
      } else {
        str.write('|$rowStr ||');
      }
      final entry = partialProducts[row].reversed.toList();
      str.write('|' * (maxW - (entry.length + rowShift[row])));
      for (var col = 0; col < entry.length; col++) {
        final bit = entry[col];
        if (bit is SignBit) {
          if (bit.inverted) {
            str.write(r'|$\overline'
                '${entry[col].value.bitString}'
                r'$');
          } else {
            str.write(r'|$\underline' '${entry[col].value.bitString}' r'$');
          }
        } else {
          str.write('|${entry[col].value.bitString}');
        }
      }
      final suffixCnt = rowShift[row];
      final val = entry.swizzle().value.zeroExtend(maxW) << suffixCnt;
      final intValue = val.isValid ? val.toBigInt() : BigInt.from(-1);
      str.write('|' * suffixCnt);
      if (bitvector) {
        str.write('| ${val.bitString}');
      }
      if (value) {
        str.write('| ${val.isValid ? intValue : "<invalid>"}'
            ' (${val.isValid ? intValue.toSigned(maxW) : "<invalid>"})');
      }
      str.write('|\n');
    }
    // Compute and print binary representation from accumulated value
    // Later: we will compare with a compression tree result

    final sum = LogicValue.ofBigInt(evaluate(), maxW);
    // print out the sum as a MSB-first bitvector
    str.write('|||');
    for (final elem in [for (var i = 0; i < maxW; i++) sum[i]].reversed) {
      str.write('|${elem.toInt()} ');
    }
    if (bitvector) {
      str.write('| ${sum.bitString}');
    }
    if (value) {
      final val = evaluate();
      str.write('|${val.toUnsigned(maxW)}');
      if (isSignExtended) {
        str.write(' ($val)');
      }
    }
    str.write('|\n');
    return str.toString();
  }
}
