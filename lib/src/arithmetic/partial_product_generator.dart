// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// partial_product_generator.dart
// Partial Product matrix generation from Booth recoded multiplicand
//
// 2024 May 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/multiplier_lib.dart';

/// Methods for sign extending the [PartialProductGenerator]
enum SignExtension {
  /// No sign extension
  none,

  /// Brute force sign extend each row to the full width of the product
  brute,

  /// Extend using stop bits in each row (and an extra row for final sign)
  stop,

  /// Fold in last row sign bit (Mohanty, B.K., Choubey, A.)
  compact,

  /// Sign folding that works for rectangular partial products
  compactRect
}

/// A class that generates a set of partial products.  Essentially a set of
/// shifted rows of [Logic] addends generated by Booth recoding and
/// manipulated by sign extension, before being compressed
class PartialProductGenerator {
  /// Get the shift increment between neighboring product rows
  int get shift => selector.shift;

  /// The actual shift in each row. This value will be modified by the
  /// sign extension routine used when folding in a sign bit from another
  /// row
  final rowShift = <int>[];

  /// rows of partial products
  int get rows => partialProducts.length;

  /// The multiplicand term
  Logic get multiplicand => selector.multiplicand;

  /// The multiplier term
  Logic get multiplier => encoder.multiplier;

  /// Partial Products output. Generated by selector and extended by sign
  /// extension routines
  late final List<List<Logic>> partialProducts;

  /// Encoder for the full multiply operand
  late final MultiplierEncoder encoder;

  /// Selector for the multiplicand which uses the encoder to index into
  /// multiples of the multiplicand and generate partial products
  late final MultiplicandSelector selector;

  /// Operands are signed
  late bool signed = true;

  // Used to avoid sign extending more than once
  var _signExtended = false;

  /// Construct the partial product matrix
  PartialProductGenerator(
      Logic multiplicand, Logic multiplier, RadixEncoder radixEncoder,
      {this.signed = true,
      SignExtension signExtension = SignExtension.compactRect}) {
    encoder = MultiplierEncoder(multiplier, radixEncoder, signed: signed);
    selector =
        MultiplicandSelector(radixEncoder.radix, multiplicand, signed: signed);

    if (multiplicand.width < selector.shift) {
      throw RohdHclException('multiplicand width must be greater than '
          '${selector.shift}');
    }
    if (multiplier.width < (selector.shift + (signed ? 1 : 0))) {
      throw RohdHclException('multiplier width must be greater than '
          '${selector.shift + (signed ? 1 : 0)}');
    }
    _build();
    switch (signExtension) {
      case SignExtension.none:
        ;
      case SignExtension.brute:
        bruteForceSignExtend();
      case SignExtension.stop:
        signExtendWithStopBitsRect();
      case SignExtension.compact:
        signExtendCompact();
      case SignExtension.compactRect:
        signExtendCompactRect();
    }
  }

  /// Setup the partial products array (partialProducts and rowShift)
  void _build() {
    partialProducts = <List<Logic>>[];
    for (var row = 0; row < encoder.rows; row++) {
      partialProducts.add(List.generate(
          selector.width, (i) => selector.select(i, encoder.getEncoding(row))));
    }
    for (var row = 0; row < rows; row++) {
      rowShift.add(row * shift);
    }
  }

  /// Fully sign extend the PP array: useful for reference only
  void bruteForceSignExtend() {
    if (_signExtended) {
      throw RohdHclException('Partial Product array already sign-extended');
    }
    _signExtended = true;
    final signs = [for (var r = 0; r < rows; r++) encoder.getEncoding(r).sign];
    for (var row = 0; row < rows; row++) {
      final addend = partialProducts[row];
      final sign = signed ? addend.last : signs[row];
      addend.addAll(List.filled((rows - row) * shift, sign));
      if (row > 0) {
        addend
          ..insertAll(0, List.filled(shift - 1, Const(0)))
          ..insert(0, signs[row - 1]);
        rowShift[row] -= shift;
      }
    }
    // Insert carry bit in extra row
    partialProducts.add(List.generate(selector.width, (i) => Const(0)));
    partialProducts.last.insert(0, signs[rows - 2]);
    rowShift.add((rows - 2) * shift);
  }

  /// Sign extend the PP array using stop bits
  /// If possible, fold the final carry into another row (only when rectangular
  /// enough that carry bit lands outside another row).
  /// This technique can then be combined with a first-row extension technique
  /// for folding in the final carry.
  void signExtendWithStopBitsRect() {
    if (_signExtended) {
      throw RohdHclException('Partial Product array already sign-extended');
    }
    _signExtended = true;

    final finalCarryPos = shift * (rows - 1);
    final finalCarryRelPos = finalCarryPos - selector.width - shift;
    final finalCarryRow =
        ((encoder.multiplier.width > selector.multiplicand.width) &&
                (finalCarryRelPos > 0))
            ? (finalCarryRelPos / shift).floor()
            : 0;

    final signs = [for (var r = 0; r < rows; r++) encoder.getEncoding(r).sign];
    for (var row = 0; row < rows; row++) {
      final addend = partialProducts[row];
      final sign = signed ? addend.last : signs[row];
      if (row == 0) {
        if (signed) {
          addend.addAll(List.filled(shift - 1, sign)); // signed only?
        } else {
          addend.addAll(List.filled(shift, sign));
        }
        addend.add(~sign);
      } else {
        if (signed) {
          addend.last = ~sign;
        } else {
          addend.add(~sign);
        }
        addend
          ..addAll(List.filled(shift - 1, Const(1)))
          ..insertAll(0, List.filled(shift - 1, Const(0)))
          ..insert(0, signs[row - 1]);
        rowShift[row] -= shift;
      }
    }

    if (finalCarryRow > 0) {
      final extensionRow = partialProducts[finalCarryRow];
      extensionRow
        ..addAll(List.filled(
            finalCarryPos - (extensionRow.length + rowShift[finalCarryRow]),
            Const(0)))
        ..add(signs[rows - 1]);
    } else if (signed) {
      // Create an extra row to hold the final carry bit
      partialProducts
          .add(List.filled(selector.width, Const(0), growable: true));
      partialProducts.last.insert(0, signs[rows - 2]);
      rowShift.add((rows - 2) * shift);

      // Hack for radix-2
      if (shift == 1) {
        partialProducts.last.last = ~partialProducts.last.last;
      }
    }
  }

  void _addStopSignFlip(List<Logic> addend, Logic sign) {
    if (signed) {
      addend.last = ~addend.last;
    } else {
      addend.add(sign);
    }
  }

  void _addStopSign(List<Logic> addend, Logic sign) {
    if (signed) {
      addend.last = sign;
    } else {
      addend.add(sign);
    }
  }

  /// Sign extend the PP array using stop bits without adding a row.
  void signExtendCompact() {
    // An implementation of
    // Mohanty, B.K., Choubey, A. Efficient Design for Radix-8 Booth Multiplier
    // and Its Application in Lifting 2-D DWT. Circuits Syst Signal Process 36,
    // 1129–1149 (2017). https://doi.org/10.1007/s00034-016-0349-9
    if (_signExtended) {
      throw RohdHclException('Partial Product array already sign-extended');
    }
    _signExtended = true;

    final lastRow = rows - 1;
    final firstAddend = partialProducts[0];
    final lastAddend = partialProducts[lastRow];
    var alignRow0Sign = selector.width -
        shift * lastRow -
        ((shift > 1)
            ? 1
            : signed
                ? 1
                : 0);

    if (alignRow0Sign < 0) {
      alignRow0Sign = 0;
    }

    final signs = [for (var r = 0; r < rows; r++) encoder.getEncoding(r).sign];

    final propagate =
        List.generate(rows, (i) => List.filled(0, Logic(), growable: true));
    for (var row = 0; row < rows; row++) {
      propagate[row].add(signs[row]);
      for (var col = 0; col < 2 * (shift - 1); col++) {
        propagate[row].add(partialProducts[row][col]);
      }
      for (var col = 1; col < propagate[row].length; col++) {
        propagate[row][col] = propagate[row][col] & propagate[row][col - 1];
      }
    }
    final m =
        List.generate(rows, (i) => List.filled(0, Logic(), growable: true));
    for (var row = 0; row < rows; row++) {
      for (var c = 0; c < shift - 1; c++) {
        m[row].add(partialProducts[row][c] ^ propagate[row][c]);
      }
      m[row].addAll(List.filled(shift - 1, Logic()));
    }

    for (var i = shift - 1; i < m[lastRow].length; i++) {
      m[lastRow][i] = lastAddend[i] ^
          (i < alignRow0Sign ? propagate[lastRow][i] : Const(0));
    }

    final remainders = List.filled(rows, Logic());
    for (var row = 0; row < lastRow; row++) {
      remainders[row] = propagate[row][shift - 1];
    }
    remainders[lastRow] <= propagate[lastRow][alignRow0Sign];

    // Compute Sign extension for row==0
    final firstSign = signed ? firstAddend.last : signs[0];
    final q = [
      firstSign ^ remainders[lastRow],
      ~(firstSign & ~remainders[lastRow]),
    ];
    q.insertAll(1, List.filled(shift - 1, ~q[1]));

    for (var row = 0; row < rows; row++) {
      final addend = partialProducts[row];
      if (row > 0) {
        final mLimit = (row == lastRow) ? 2 * (shift - 1) : shift - 1;
        for (var i = 0; i < mLimit; i++) {
          addend[i] = m[row][i];
        }
        // Stop bits
        if (signed) {
          addend.last = ~addend.last;
        } else {
          addend.add(~signs[row]);
        }
        addend
          ..insert(0, remainders[row - 1])
          ..addAll(List.filled(shift - 1, Const(1)));
        rowShift[row] -= 1;
      } else {
        for (var i = 0; i < shift - 1; i++) {
          firstAddend[i] = m[0][i];
        }
        if (signed) {
          firstAddend.last = q[0];
        } else {
          firstAddend.add(q[0]);
        }
        firstAddend.addAll(q.getRange(1, q.length));
      }
    }
    if (shift == 1) {
      lastAddend.add(Const(1));
    }
  }

  /// Sign extend the PP array using stop bits without adding a row
  /// This routine works with different widths of multiplicand/multiplier,
  /// an extension of Mohanty, B.K., Choubey designed by
  /// Desmond A. Kirkpatrick
  void signExtendCompactRect() {
    if (_signExtended) {
      throw RohdHclException('Partial Product array already sign-extended');
    }
    _signExtended = true;

    final lastRow = rows - 1;
    final firstAddend = partialProducts[0];
    final lastAddend = partialProducts[lastRow];

    final firstRowQStart = selector.width - (signed ? 1 : 0);
    final lastRowSignPos = shift * lastRow;

    final align = firstRowQStart - lastRowSignPos;

    final signs = [for (var r = 0; r < rows; r++) encoder.getEncoding(r).sign];

    // Compute propgation info for folding sign bits into main rows
    final propagate =
        List.generate(rows, (i) => List.filled(0, Logic(), growable: true));

    for (var row = 0; row < rows; row++) {
      propagate[row].add(signs[row]);
      for (var col = 0; col < 2 * (shift - 1); col++) {
        propagate[row].add(partialProducts[row][col]);
      }
      // Last row has extend sign propagation to Q start
      if (row == lastRow) {
        var col = 2 * (shift - 1);
        while (propagate[lastRow].length <= align) {
          propagate[lastRow].add(partialProducts[row][col++]);
        }
      }
      // Now compute the propagation logic
      for (var col = 1; col < propagate[row].length; col++) {
        propagate[row][col] = propagate[row][col] & propagate[row][col - 1];
      }
    }

    // Compute 'm', the prefix of each row to carry the sign of the next row
    final m =
        List.generate(rows, (i) => List.filled(0, Logic(), growable: true));
    for (var row = 0; row < rows; row++) {
      for (var c = 0; c < shift - 1; c++) {
        m[row].add(partialProducts[row][c] ^ propagate[row][c]);
      }
      m[row].addAll(List.filled(shift - 1, Logic()));
    }
    while (m[lastRow].length < align) {
      m[lastRow].add(Logic());
    }
    for (var i = shift - 1; i < m[lastRow].length; i++) {
      m[lastRow][i] =
          lastAddend[i] ^ (i < align ? propagate[lastRow][i] : Const(0));
    }

    final remainders = List.filled(rows, Logic());
    for (var row = 0; row < lastRow; row++) {
      remainders[row] = propagate[row][shift - 1];
    }
    remainders[lastRow] = propagate[lastRow][align > 0 ? align : 0];

    // Merge 'm' into the LSBs of each addend
    for (var row = 0; row < rows; row++) {
      final addend = partialProducts[row];
      if (row > 0) {
        final mLimit = (row == lastRow) ? align : shift - 1;
        for (var i = 0; i < mLimit; i++) {
          addend[i] = m[row][i];
        }
        // Stop bits
        _addStopSignFlip(addend, ~signs[row]);
        addend
          ..insert(0, remainders[row - 1])
          ..addAll(List.filled(shift - 1, Const(1)));
        rowShift[row] -= 1;
      } else {
        // First row
        for (var i = 0; i < shift - 1; i++) {
          firstAddend[i] = m[0][i];
        }
      }
    }

    // Insert the lastRow sign:  Either in firstRow's Q if there is a
    // collision or in another row if it lands beyond the Q sign extension

    final firstSign = signed ? firstAddend.last : signs[0];
    final lastSign = remainders[lastRow];
    // Compute Sign extension MSBs for firstRow
    final qLen = shift + 1;
    final insertSignPos = (align > 0) ? 0 : -align;
    final q = List.filled(min(qLen, insertSignPos), firstSign, growable: true);
    if (insertSignPos < qLen) {
      // At sign insertion position
      q.add(firstSign ^ lastSign);
      if (insertSignPos == qLen - 1) {
        q[insertSignPos] = ~q[insertSignPos];
        q.add(~(firstSign | q[insertSignPos]));
      } else {
        q
          ..addAll(List.filled(qLen - insertSignPos - 2, firstSign & ~lastSign))
          ..add(~(firstSign & ~lastSign));
      }
    }

    if (-align >= q.length) {
      q.last = ~firstSign;
    }
    _addStopSign(firstAddend, q[0]);
    firstAddend.addAll(q.getRange(1, q.length));

    if (-align >= q.length) {
      final finalCarryRelPos =
          lastRowSignPos - selector.width - shift + (signed ? 1 : 0);
      final finalCarryRow = (finalCarryRelPos / shift).floor();
      final curRowLength =
          partialProducts[finalCarryRow].length + rowShift[finalCarryRow];

      partialProducts[finalCarryRow]
        ..addAll(List.filled(lastRowSignPos - curRowLength, Const(0)))
        ..add(remainders[lastRow]);
    }
    if (shift == 1) {
      lastAddend.add(Const(1));
    }
  }

  /// Return the actual largest width of all rows
  int maxWidth() {
    var maxW = 0;
    for (var row = 0; row < rows; row++) {
      final entry = partialProducts[row];
      if (entry.length + rowShift[row] > maxW) {
        maxW = entry.length + rowShift[row];
      }
    }
    return maxW;
  }

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
  @override
  String toString() {
    final str = StringBuffer();

    final maxW = maxWidth();
    final nonSignExtendedPad = _signExtended
        ? 0
        : shift > 2
            ? shift - 1
            : 1;
    // We will print encoding(1-hot multiples and sign) before each row
    final shortPrefix =
        '99 ${'M='.padRight(2 + selector.radix ~/ 2)}(99) S= : '.length +
            3 * nonSignExtendedPad;

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
          final multiple = encoding.multiples.value.firstOne() + 1;
          str.write('$rowStr M=${encoding.multiples.reversed.value.bitString}'
              '(${multiple.toString().padLeft(2)}) '
              'S=${encoding.sign.value.toInt()}: ');
        } else {
          str.write(' ' * shortPrefix);
        }
      } else {
        str.write(
            '$rowStr ${'M='.padRight(2 + selector.radix ~/ 2)}     S= : ');
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
    if (_signExtended) {
      str.write(' ($val)\n\n');
    }
    return str.toString();
  }
}
