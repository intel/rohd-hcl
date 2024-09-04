// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// partial_product_test_sign_extend.dart
// Partial Product Genereator sign extension methods.
//
// 2024 May 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

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
typedef PPGFunction = PartialProductGenerator
    Function(Logic a, Logic b, RadixEncoder radixEncoder, {bool signed});

/// Used to test different sign extension methods
PPGFunction curryPartialProductGenerator(SignExtension signExtension) =>
    (a, b, encoder, {signed = false}) => switch (signExtension) {
          SignExtension.none => PartialProductGeneratorNoSignExtension(
              a, b, encoder,
              signed: signed),
          SignExtension.brute => PartialProductGeneratorBruteSignExtension(
              a, b, encoder,
              signed: signed),
          SignExtension.stop => PartialProductGeneratorStopBitsSignExtension(
              a, b, encoder,
              signed: signed),
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
      {required super.signed});

  /// Fully sign extend the PP array: useful for reference only
  @override
  void signExtend() {
    if (isSignExtended) {
      throw RohdHclException('Partial Product array already sign-extended');
    }
    isSignExtended = true;
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
}

/// A Partial Product Generator using Brute Sign Extension
class PartialProductGeneratorCompactSignExtension
    extends PartialProductGenerator {
  /// Construct a compact sign extending Partial Product Generator
  PartialProductGeneratorCompactSignExtension(
      super.multiplicand, super.multiplier, super.radixEncoder,
      {required super.signed});

  /// Sign extend the PP array using stop bits without adding a row.
  @override
  void signExtend() {
    // An implementation of
    // Mohanty, B.K., Choubey, A. Efficient Design for Radix-8 Booth Multiplier
    // and Its Application in Lifting 2-D DWT. Circuits Syst Signal Process 36,
    // 1129–1149 (2017). https://doi.org/10.1007/s00034-016-0349-9
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
}

/// A Partial Product Generator using Brute Sign Extension
class PartialProductGeneratorStopBitsSignExtension
    extends PartialProductGenerator {
  /// Construct a stop bits sign extending Partial Product Generator
  PartialProductGeneratorStopBitsSignExtension(
      super.multiplicand, super.multiplier, super.radixEncoder,
      {required super.signed});

  /// Sign extend the PP array using stop bits
  /// If possible, fold the final carry into another row (only when rectangular
  /// enough that carry bit lands outside another row).
  /// This technique can then be combined with a first-row extension technique
  /// for folding in the final carry.
  @override
  void signExtend() {
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
}
