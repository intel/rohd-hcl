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
  stopBits,

  /// Fold in last row sign bit (Mohanty, B.K., Choubey, A.)
  compact,

  /// Sign folding that works for rectangular partial products
  compactRect
}

/// Used to test different sign extension methods
typedef PPGFunction = PartialProductGenerator Function(
    Logic a, Logic b, RadixEncoder radixEncoder,
    {bool signedMultiplicand,
    Logic? selectSignedMultiplicand,
    bool signedMultiplier,
    Logic? selectSignedMultiplier});

/// Used to test different sign extension methods
PPGFunction curryPartialProductGenerator(SignExtension signExtension) =>
    switch (signExtension) {
      SignExtension.none => NewPartialProductGeneratorNoneSignExtension.new,
      SignExtension.brute => NewPartialProductGeneratorBruteSignExtension.new,
      SignExtension.stopBits =>
        NewPartialProductGeneratorStopBitsSignExtension.new,
      SignExtension.compact =>
        NewPartialProductGeneratorCompactSignExtension.new,
      SignExtension.compactRect =>
        NewPartialProductGeneratorCompactRectSignExtension.new,
    };

/// API for sign extension classes
abstract class PartialProductSignExtension {
  /// The partial product generator we are sign extending.
  final PartialProductGenerator ppg;

  /// multiplicand operand is always signed.
  final bool signedMultiplicand;

  /// multiplier operand is always signed.
  final bool signedMultiplier;

  /// If not null, use this signal to select between signed and unsigned
  /// multiplicand.
  final Logic? selectSignedMultiplicand;

  /// If not null, use this signal to select between signed and unsigned
  /// multiplier.
  final Logic? selectSignedMultiplier;

  /// in PPA
  int get rows => ppg.rows;

  /// in PPA
  List<int> get rowShift => ppg.rowShift;

  /// in PPA
  List<List<Logic>> get partialProducts => ppg.partialProducts;

  /// should be in ppa
  bool get isSignExtended => ppg.isSignExtended;
  set isSignExtended(bool set) {
    ppg.isSignExtended = set;
  }

  /// Could override in ppa
  int get shift => ppg.shift;

  /// Need signs[] API instead
  MultiplierEncoder get encoder => ppg.encoder; // signs getter

  // is multiplicand.width == entry.length?
  // width=> multiplicand.width + shift - 1;
  /// Only used to get width as above
  MultiplicandSelector get selector => ppg.selector; // selector.width accessed

  /// Sign Extension class that operates on a [PartialProductGenerator]
  /// and sign-extends the entries.
  PartialProductSignExtension(
    this.ppg, {
    this.signedMultiplicand = false,
    this.signedMultiplier = false,
    this.selectSignedMultiplicand,
    this.selectSignedMultiplier,
  }) {
    //
    if (signedMultiplier && (selectSignedMultiplier != null)) {
      throw RohdHclException('sign reconfiguration requires signed=false');
    }
    if (signedMultiplicand && (selectSignedMultiplicand != null)) {
      throw RohdHclException('multiplicand sign reconfiguration requires '
          'signedMultiplicand=false');
    }
  }

  /// Execute the sign extension, overridden to specialize.
  void signExtend();

  /// Helper function for sign extension routines:
  /// For signed operands, set the MSB to [sign], otherwise add this [sign] bit.
  void addStopSign(List<Logic> addend, SignBit sign) {
    if (!signedMultiplicand) {
      addend.add(sign);
    } else {
      addend.last = sign;
    }
  }

  /// Helper function for sign extension routines:
  /// For signed operands, flip the MSB, otherwise add this [sign] bit.
  void addStopSignFlip(List<Logic> addend, SignBit sign) {
    if (!signedMultiplicand) {
      if (selectSignedMultiplicand == null) {
        addend.add(sign);
      } else {
        addend.add(SignBit(mux(selectSignedMultiplicand!, ~addend.last, sign),
            inverted: selectSignedMultiplicand != null));
      }
    } else {
      addend.last = SignBit(~addend.last, inverted: true);
    }
  }
}

/// Used to test different sign extension methods
typedef SignExtensionFunction = PartialProductSignExtension Function(
    PartialProductGenerator ppg,
    {bool signedMultiplicand,
    bool signedMultiplier,
    Logic? selectSignedMultiplicand,
    Logic? selectSignedMultiplier});

/// Used to test different sign extension methods
SignExtensionFunction currysignExtensionFunction(SignExtension signExtension) =>
    switch (signExtension) {
      SignExtension.none => NoneSignExtension.new,
      SignExtension.brute => BruteSignExtension.new,
      SignExtension.stopBits => StopBitsSignExtension.new,
      SignExtension.compact => CompactSignExtension.new,
      SignExtension.compactRect => CompactRectSignExtension.new,
    };

/// These other sign extensions are for assisting with testing and debugging.
/// More robust and simpler sign extensions in case
/// complex sign extension routines obscure other bugs.
///
/// /// A Partial Product Generator using None Sign Extension
class NoneSignExtension extends PartialProductSignExtension {
  /// Construct a no sign-extension class.
  NoneSignExtension(
    super.ppg, {
    super.signedMultiplicand = false,
    super.signedMultiplier = false,
    super.selectSignedMultiplicand,
    super.selectSignedMultiplier,
  });

  /// Fully sign extend the PP array: useful for reference only
  @override
  void signExtend() {}
}

/// A wrapper class for [NoneSignExtension] we used
/// during refactoring to be compatible with old calls.
class NewPartialProductGeneratorNoneSignExtension
    extends PartialProductGenerator {
  /// The extension routine we will be using.
  late final PartialProductSignExtension extender;

  /// Construct a none sign extending Partial Product Generator
  NewPartialProductGeneratorNoneSignExtension(
      super.multiplicand, super.multiplier, super.radixEncoder,
      {super.signedMultiplicand,
      super.signedMultiplier,
      super.selectSignedMultiplicand,
      super.selectSignedMultiplier,
      super.name = 'none'}) {
    extender = BruteSignExtension(this,
        signedMultiplicand: signedMultiplicand,
        signedMultiplier: signedMultiplier,
        selectSignedMultiplicand: selectSignedMultiplicand,
        selectSignedMultiplier: selectSignedMultiplier);
    signExtend();
  }

  @override
  void signExtend() {
    extender.signExtend();
  }
}

/// These other sign extensions are for assisting with testing and debugging.
/// More robust and simpler sign extensions in case
/// complex sign extension routines obscure other bugs.

/// A Brute Sign Extension class.
class BruteSignExtension extends PartialProductSignExtension {
  /// Construct a brute-force sign extending Partial Product Generator
  BruteSignExtension(
    super.ppg, {
    super.signedMultiplicand = false,
    super.signedMultiplier = false,
    super.selectSignedMultiplicand,
    super.selectSignedMultiplier,
  });

  /// Fully sign extend the PP array: useful for reference only
  @override
  void signExtend() {
    if (signedMultiplicand && (selectSignedMultiplicand != null)) {
      throw RohdHclException('multiplicand sign reconfiguration requires '
          'signedMultiplicand=false');
    }
    if (isSignExtended) {
      throw RohdHclException('Partial Product array already sign-extended');
    }
    isSignExtended = true;
    final signs = [for (var r = 0; r < rows; r++) encoder.getEncoding(r).sign];
    for (var row = 0; row < rows; row++) {
      final addend = partialProducts[row];
      final Logic sign;
      if (selectSignedMultiplicand != null) {
        sign = mux(selectSignedMultiplicand!, addend.last, signs[row]);
      } else {
        sign = signedMultiplicand ? addend.last : signs[row];
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

/// A wrapper class for [BruteSignExtension] we used
/// during refactoring to be compatible with old calls.
class NewPartialProductGeneratorBruteSignExtension
    extends PartialProductGenerator {
  /// The extension routine we will be using.
  late final PartialProductSignExtension extender;

  /// Construct a compact rect sign extending Partial Product Generator
  NewPartialProductGeneratorBruteSignExtension(
      super.multiplicand, super.multiplier, super.radixEncoder,
      {super.signedMultiplicand,
      super.signedMultiplier,
      super.selectSignedMultiplicand,
      super.selectSignedMultiplier,
      super.name = 'brute'}) {
    extender = BruteSignExtension(this,
        signedMultiplicand: signedMultiplicand,
        signedMultiplier: signedMultiplier,
        selectSignedMultiplicand: selectSignedMultiplicand,
        selectSignedMultiplier: selectSignedMultiplier);
    signExtend();
  }

  @override
  void signExtend() {
    extender.signExtend();
  }
}

/// A Compact Sign Extension class.
class CompactSignExtension extends PartialProductSignExtension {
  /// Construct a compact sign extendsion class.
  CompactSignExtension(
    super.ppg, {
    super.signedMultiplicand = false,
    super.signedMultiplier = false,
    super.selectSignedMultiplicand,
    super.selectSignedMultiplier,
  });

  @override
  void signExtend() {
    // An implementation of
    // Mohanty, B.K., Choubey, A. Efficient Design for Radix-8 Booth Multiplier
    // and Its Application in Lifting 2-D DWT. Circuits Syst Signal Process 36,
    // 1129–1149 (2017). https://doi.org/10.1007/s00034-016-0349-9
    if (signedMultiplicand && (selectSignedMultiplicand != null)) {
      throw RohdHclException('multiplicand sign reconfiguration requires '
          'signedMultiplicand=false');
    }
    if (isSignExtended) {
      throw RohdHclException('Partial Product array already sign-extended');
    }
    isSignExtended = true;

    final lastRow = rows - 1;
    final firstAddend = partialProducts[0];
    final lastAddend = partialProducts[lastRow];

    final firstRowQStart = selector.width - (signedMultiplicand ? 1 : 0);
    final lastRowSignPos = shift * lastRow;
    final alignRow0Sign = firstRowQStart - lastRowSignPos;

    final signs = [for (var r = 0; r < rows; r++) encoder.getEncoding(r).sign];

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
        while (propagate[lastRow].length <= alignRow0Sign) {
          propagate[lastRow].add(SignBit(partialProducts[row][col++]));
        }
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
    while (m[lastRow].length < alignRow0Sign) {
      m[lastRow].add(Logic());
    }

    for (var i = shift - 1; i < m[lastRow].length; i++) {
      m[lastRow][i] = lastAddend[i] ^
          (i < alignRow0Sign ? propagate[lastRow][i] : Const(0));
    }

    final remainders = List.filled(rows, Logic());
    for (var row = 0; row < lastRow; row++) {
      remainders[row] = propagate[row][shift - 1];
    }
    remainders[lastRow] <= propagate[lastRow][max(alignRow0Sign, 0)];

    // Compute Sign extension for row==0
    final Logic firstSign;
    if (selectSignedMultiplicand == null) {
      firstSign =
          signedMultiplicand ? SignBit(firstAddend.last) : SignBit(signs[0]);
    } else {
      firstSign =
          SignBit(mux(selectSignedMultiplicand!, firstAddend.last, signs[0]));
    }
    final q = [
      firstSign ^ remainders[lastRow],
      ~(firstSign & ~remainders[lastRow]),
    ];
    q.insertAll(1, List.filled(shift - 1, ~q[1]));

    for (var row = 0; row < rows; row++) {
      final addend = partialProducts[row];
      if (row > 0) {
        final mLimit = (row == lastRow) ? alignRow0Sign : shift - 1;
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
        if (!signedMultiplicand) {
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

/// A wrapper class for [CompactSignExtension] we used
/// during refactoring to be compatible with old calls.
class NewPartialProductGeneratorCompactSignExtension
    extends PartialProductGenerator {
  /// The extension routine we will be using.
  late final PartialProductSignExtension extender;

  /// Construct a compact sign extending Partial Product Generator
  NewPartialProductGeneratorCompactSignExtension(
      super.multiplicand, super.multiplier, super.radixEncoder,
      {super.signedMultiplicand,
      super.signedMultiplier,
      super.selectSignedMultiplicand,
      super.selectSignedMultiplier,
      super.name = 'compact'}) {
    extender = CompactSignExtension(this,
        signedMultiplicand: signedMultiplicand,
        signedMultiplier: signedMultiplier,
        selectSignedMultiplicand: selectSignedMultiplicand,
        selectSignedMultiplier: selectSignedMultiplier);
    signExtend();
  }

  @override
  void signExtend() {
    extender.signExtend();
  }
}

/// A StopBits Sign Extension.
class StopBitsSignExtension extends PartialProductSignExtension {
  /// Construct a stop bits sign extendsion class.
  StopBitsSignExtension(
    super.ppg, {
    super.signedMultiplicand = false,
    super.signedMultiplier = false,
    super.selectSignedMultiplicand,
    super.selectSignedMultiplier,
  });

  /// Sign extend the PP array using stop bits.
  /// If possible, fold the final carry into another row (only when rectangular
  /// enough that carry bit lands outside another row).
  /// This technique can then be combined with a first-row extension technique
  /// for folding in the final carry.
  ///
  @override
  void signExtend() {
    if (signedMultiplicand && (selectSignedMultiplicand != null)) {
      throw RohdHclException('multiplicand sign reconfiguration requires '
          'signedMultiplicand=false');
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
      if (selectSignedMultiplicand != null) {
        sign = mux(selectSignedMultiplicand!, addend.last, signs[row]);
      } else {
        sign = signedMultiplicand ? addend.last : signs[row];
      }
      if (row == 0) {
        if (!signedMultiplicand) {
          addend.addAll(List.filled(shift, SignBit(sign)));
        } else {
          // either is signed?
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
    } else if (signedMultiplier | (selectSignedMultiplier != null)) {
      // Create an extra row to hold the final carry bit
      partialProducts
          .add(List.filled(selector.width, Const(0), growable: true));
      partialProducts.last.insert(0, SignBit(signs[rows - 2]));
      rowShift.add((rows - 2) * shift);

      // Hack for radix-2
      if (shift == 1) {
        addStopSignFlip(
            partialProducts.last, SignBit(Const(1), inverted: true));
      }
    }
  }
}

//

/// A wrapper class for [StopBitsSignExtension] we used
/// during refactoring to be compatible with old calls.
class NewPartialProductGeneratorStopBitsSignExtension
    extends PartialProductGenerator {
  /// The extension routine we will be using.
  late final PartialProductSignExtension extender;

  /// Construct a stop bits sign extending Partial Product Generator
  NewPartialProductGeneratorStopBitsSignExtension(
      super.multiplicand, super.multiplier, super.radixEncoder,
      {super.signedMultiplicand,
      super.signedMultiplier,
      super.selectSignedMultiplicand,
      super.selectSignedMultiplier,
      super.name = 'stop_bits'}) {
    extender = StopBitsSignExtension(this,
        signedMultiplicand: signedMultiplicand,
        signedMultiplier: signedMultiplier,
        selectSignedMultiplicand: selectSignedMultiplicand,
        selectSignedMultiplier: selectSignedMultiplier);
    signExtend();
  }

  @override
  void signExtend() {
    extender.signExtend();
  }
}

/// A wrapper class for CompactRectSignExtension we used
/// during refactoring to be compatible with old calls.
class NewPartialProductGeneratorCompactRectSignExtension
    extends PartialProductGenerator {
  /// The extension routine we will be using.
  late final PartialProductSignExtension extender;

  /// Construct a compact rect sign extending Partial Product Generator
  NewPartialProductGeneratorCompactRectSignExtension(
      super.multiplicand, super.multiplier, super.radixEncoder,
      {super.signedMultiplicand,
      super.signedMultiplier,
      super.selectSignedMultiplicand,
      super.selectSignedMultiplier,
      super.name = 'compact_rect'}) {
    extender = CompactRectSignExtension(this,
        signedMultiplicand: signedMultiplicand,
        signedMultiplier: signedMultiplier,
        selectSignedMultiplicand: selectSignedMultiplicand,
        selectSignedMultiplier: selectSignedMultiplier);
    signExtend();
  }

  @override
  void signExtend() {
    extender.signExtend();
  }
}

/// A Partial Product Generator using Compact Rectangular Extension
class CompactRectSignExtension extends PartialProductSignExtension {
  /// Sign extend the PP array using stop bits without adding a row
  /// This routine works with different widths of multiplicand/multiplier,
  /// an extension of Mohanty, B.K., Choubey designed by
  /// Desmond A. Kirkpatrick.
  CompactRectSignExtension(
    super.ppg, {
    super.signedMultiplicand = false,
    super.signedMultiplier = false,
    super.selectSignedMultiplicand,
    super.selectSignedMultiplier,
  });

  @override
  void signExtend() {
    if (isSignExtended) {
      throw RohdHclException('Partial Product array already sign-extended');
    }
    isSignExtended = true;

    final lastRow = rows - 1;
    final firstAddend = partialProducts[0];
    final lastAddend = partialProducts[lastRow];

    final firstRowQStart = selector.width - (signedMultiplicand ? 1 : 0);
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
    final Logic firstSign;
    if (selectSignedMultiplicand == null) {
      firstSign =
          signedMultiplicand ? SignBit(firstAddend.last) : SignBit(signs[0]);
    } else {
      firstSign =
          SignBit(mux(selectSignedMultiplicand!, firstAddend.last, signs[0]));
    }
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
    addStopSign(firstAddend, SignBit(q[0]));
    firstAddend.addAll(q.getRange(1, q.length));

    if (-align >= q.length) {
      final finalCarryRelPos = lastRowSignPos -
          selector.width -
          shift +
          (signedMultiplicand ? 1 : 0);
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
