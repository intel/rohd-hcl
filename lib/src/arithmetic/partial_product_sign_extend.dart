// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// partial_product_test_sign_extend.dart
// Partial Product Genereator sign extension methods.
//
// 2024 May 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

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

/// Used to test different sign extension methods
typedef PPGFunction = PartialProductGenerator Function(
    Logic a, Logic b, RadixEncoder radixEncoder,
    {Logic? selectSigned, bool signed});

/// Used to test different sign extension methods
PPGFunction curryPartialProductGenerator(SignExtension signExtension) =>
    (a, b, encoder, {selectSigned, signed = false}) => switch (signExtension) {
          SignExtension.none => PartialProductGeneratorNoSignExtension(
              a, b, encoder,
              signed: signed),
          SignExtension.brute => PartialProductGeneratorBruteSignExtension(
              a, b, encoder,
              selectSigned: selectSigned, signed: signed),
          SignExtension.stop => PartialProductGeneratorStopBitsSignExtension(
              a, b, encoder,
              selectSigned: selectSigned, signed: signed),
          SignExtension.compact => PartialProductGeneratorCompactSignExtension(
              a, b, encoder,
              signed: signed),
          SignExtension.compactRect =>
            PartialProductGeneratorCompactRectSignExtension(a, b, encoder,
                signed: signed),
        };

/// These other sign extensions are for asssisting with testing and debugging.
/// More robust and simpler sign extensions in case
/// complex sign extension routines obscure other bugs.

/// A Partial Product Generator using Brute Sign Extension
class PartialProductGeneratorBruteSignExtension
    extends PartialProductGenerator {
  /// Construct a brute-force sign extending Partial Product Generator
  PartialProductGeneratorBruteSignExtension(
      super.multiplicand, super.multiplier, super.radixEncoder,
      {super.signed, super.selectSigned});

  /// Fully sign extend the PP array: useful for reference only
  @override
  void signExtend() {
    if (signed && (selectSigned != null)) {
      throw RohdHclException('sign reconfiguration requires signed=false');
    }
    if (isSignExtended) {
      throw RohdHclException('Partial Product array already sign-extended');
    }
    isSignExtended = true;
    final signs = [for (var r = 0; r < rows; r++) encoder.getEncoding(r).sign];
    for (var row = 0; row < rows; row++) {
      final addend = partialProducts[row];
      // final sign = SignBit(signed ? addend.last : signs[row]);
      final Logic sign;
      if (selectSigned != null) {
        sign = mux(selectSigned!, addend.last, signs[row]);
      } else {
        sign = signed ? addend.last : signs[row];
      }
      addend.addAll(List.filled((rows - row) * shift, SignBit(sign)));
      if (row > 0) {
        addend
          ..insertAll(0, List.filled(shift - 1, Const(0)))
          ..insert(0, SignBit(signs[row - 1]));
        rowShift[row] -= shift;
      }
    }
    // Insert carry bit in extra row
    partialProducts.add(List.generate(selector.width, (i) => Const(0)));
    partialProducts.last.insert(0, SignBit(signs[rows - 2]));
    rowShift.add((rows - 2) * shift);
  }
}

/// A Partial Product Generator using Brute Sign Extension
class PartialProductGeneratorCompactSignExtension
    extends PartialProductGenerator {
  /// Construct a compact sign extending Partial Product Generator
  PartialProductGeneratorCompactSignExtension(
      super.multiplicand, super.multiplier, super.radixEncoder,
      {super.signed, super.selectSigned});

  /// Sign extend the PP array using stop bits without adding a row.
  @override
  void signExtend() {
    // An implementation of
    // Mohanty, B.K., Choubey, A. Efficient Design for Radix-8 Booth Multiplier
    // and Its Application in Lifting 2-D DWT. Circuits Syst Signal Process 36,
    // 1129–1149 (2017). https://doi.org/10.1007/s00034-016-0349-9
    if (signed && (selectSigned != null)) {
      throw RohdHclException('sign reconfiguration requires signed=false');
    }
    if (isSignExtended) {
      throw RohdHclException('Partial Product array already sign-extended');
    }
    isSignExtended = true;

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
    final firstSign = !signed ? signs[0] : firstAddend.last;
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
        addStopSignFlip(addend, SignBit(~signs[row], inverted: true));
        addend
          ..insert(0, remainders[row - 1])
          ..addAll(List.filled(shift - 1, Const(1)));
        rowShift[row] -= 1;
      } else {
        for (var i = 0; i < shift - 1; i++) {
          firstAddend[i] = m[0][i];
        }
        if (!signed) {
          firstAddend.add(q[0]);
        } else {
          firstAddend.last = q[0];
        }
        firstAddend.addAll(q.getRange(1, q.length));
      }
    }
    if (shift == 1) {
      lastAddend.add(Const(1));
    }
  }
}

/// A Partial Product Generator using Brute Sign Extension
class PartialProductGeneratorStopBitsSignExtension
    extends PartialProductGenerator {
  /// Construct a stop bits sign extending Partial Product Generator
  PartialProductGeneratorStopBitsSignExtension(
      super.multiplicand, super.multiplier, super.radixEncoder,
      {super.signed, super.selectSigned});

  /// Sign extend the PP array using stop bits.
  /// If possible, fold the final carry into another row (only when rectangular
  /// enough that carry bit lands outside another row).
  /// This technique can then be combined with a first-row extension technique
  /// for folding in the final carry.
  @override
  void signExtend() {
    if (signed && (selectSigned != null)) {
      throw RohdHclException('sign reconfiguration requires signed=false');
    }
    if (isSignExtended) {
      throw RohdHclException('Partial Product array already sign-extended');
    }
    isSignExtended = true;

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
      final Logic sign;
      if (selectSigned != null) {
        sign = mux(selectSigned!, addend.last, signs[row]);
      } else {
        sign = signed ? addend.last : signs[row];
      }
      if (row == 0) {
        if (!signed) {
          addend.addAll(List.filled(shift, SignBit(sign)));
        } else {
          addend.addAll(List.filled(shift - 1, SignBit(sign))); // signed only?
        }
        addend.add(SignBit(~sign, inverted: true));
      } else {
        addStopSign(addend, SignBit(~sign, inverted: true));
        addend
          ..addAll(List.filled(shift - 1, Const(1)))
          ..insertAll(0, List.filled(shift - 1, Const(0)))
          ..insert(0, SignBit(signs[row - 1]));
        rowShift[row] -= shift;
      }
    }

    if (finalCarryRow > 0) {
      final extensionRow = partialProducts[finalCarryRow];
      extensionRow
        ..addAll(List.filled(
            finalCarryPos - (extensionRow.length + rowShift[finalCarryRow]),
            Const(0)))
        ..add(SignBit(signs[rows - 1]));
    } else if (signed | (selectSigned != null)) {
      // Create an extra row to hold the final carry bit
      partialProducts
          .add(List.filled(selector.width, Const(0), growable: true));
      partialProducts.last.insert(0, SignBit(signs[rows - 2]));
      rowShift.add((rows - 2) * shift);

      // Hack for radix-2
      if (shift == 1) {
        partialProducts.last.last = ~partialProducts.last.last;
      }
    }
  }
}

/// A Partial Product Generator using Compact Rectangular Extension
class PartialProductGeneratorCompactRectSignExtension
    extends PartialProductGenerator {
  /// Construct a compact rect sign extending Partial Product Generator
  PartialProductGeneratorCompactRectSignExtension(
      super.multiplicand, super.multiplier, super.radixEncoder,
      {required super.signed, super.selectSigned});

  /// Sign extend the PP array using stop bits without adding a row
  /// This routine works with different widths of multiplicand/multiplier,
  /// an extension of Mohanty, B.K., Choubey designed by
  /// Desmond A. Kirkpatrick
  @override
  void signExtend() {
    if (signed && (selectSigned != null)) {
      throw RohdHclException('sign reconfiguration requires signed=false');
    }
    if (isSignExtended) {
      throw RohdHclException('Partial Product array already sign-extended');
    }
    isSignExtended = true;

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
      propagate[row].add(SignBit(signs[row]));
      for (var col = 0; col < 2 * (shift - 1); col++) {
        propagate[row].add(partialProducts[row][col]);
      }
      // Last row has extend sign propagation to Q start
      if (row == lastRow) {
        var col = 2 * (shift - 1);
        while (propagate[lastRow].length <= align) {
          propagate[lastRow].add(SignBit(partialProducts[row][col++]));
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
        addStopSignFlip(addend, SignBit(~signs[row], inverted: true));
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

    final firstSign = signed ? SignBit(firstAddend.last) : SignBit(signs[0]);
    final lastSign = SignBit(remainders[lastRow]);
    // Compute Sign extension MSBs for firstRow
    final qLen = shift + 1;
    final insertSignPos = (align > 0) ? 0 : -align;
    final q = List.filled(min(qLen, insertSignPos), firstSign, growable: true);
    if (insertSignPos < qLen) {
      // At sign insertion position
      q.add(SignBit(firstSign ^ lastSign));
      if (insertSignPos == qLen - 1) {
        q[insertSignPos] = SignBit(~q[insertSignPos], inverted: true);
        q.add(SignBit(~(firstSign | q[insertSignPos]), inverted: true));
      } else {
        q
          ..addAll(List.filled(
              qLen - insertSignPos - 2, SignBit(firstSign & ~lastSign)))
          ..add(SignBit(~(firstSign & ~lastSign), inverted: true));
      }
    }

    if (-align >= q.length) {
      q.last = SignBit(~firstSign, inverted: true);
    }
    addStopSign(firstAddend, q[0]);
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
}
