// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// partial_product_generator.dart
// Partial Product matrix generation from Booth recoded multiplicand
//
// 2024 May 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Store a Signbit as Logic
class SignBit extends Logic {
  /// This is an inverted sign bit
  bool inverted = false;

  /// Construct a sign bit to store
  SignBit(Logic inl, {this.inverted = false}) : super(name: inl.name) {
    this <= inl;
  }
}

/// A [PartialProductArray] is a class that holds a set of partial products
/// for manipulation by [PartialProductGenerator] and [ColumnCompressor].
abstract class PartialProductArray {
  /// name used for PartialProductGenerators
  final String name;

  /// Construct a basic List<List<Logic> to hold an array of partial products
  /// as well as a rowShift array to hold the row shifts.
  PartialProductArray({this.name = 'ppa'});

  /// The actual shift in each row. This value will be modified by the
  /// sign extension routine used when folding in a sign bit from another
  /// row
  final rowShift = <int>[];

  /// Partial Products output. Generated by selector and extended by sign
  /// extension routines
  late final List<List<Logic>> partialProducts;

  /// rows of partial products
  int get rows => partialProducts.length;

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

  /// Return the Logic at the absolute position ([row], [col]).
  Logic getAbsolute(int row, int col) {
    final product = partialProducts[row];
    while (product.length <= col) {
      product.add(Const(0));
    }
    return partialProducts[row][col - rowShift[row]];
  }

  /// Return the List<Logic> at the
  /// absolute position ([row], List<int> [columns].
  List<Logic> getAbsoluteAll(int row, List<int> columns) {
    final product = partialProducts[row];
    final relMax = columns.reduce(max);
    final absMax = relMax - rowShift[row];
    while (product.length <= absMax) {
      product.add(Const(0));
    }
    return [for (final c in columns) partialProducts[row][c - rowShift[row]]];
  }

  /// Set the Logic at absolute position ([row], [col]) to [val].
  void setAbsolute(int row, int col, Logic val) {
    final product = partialProducts[row];
    final i = col - rowShift[row];
    if (product.length > i) {
      product[i] = val;
    } else {
      while (product.length < i) {
        product.add(Const(0));
      }
      partialProducts[row].add(val);
    }
  }

  /// Mux the Logic at absolute position ([row], [col]) conditionally by
  /// [condition] to [val].
  void muxAbsolute(int row, int col, Logic condition, Logic val) {
    final product = partialProducts[row];
    final i = col - rowShift[row];
    if (product.length > i) {
      if (val is SignBit || product[i] is SignBit) {
        var inv = false;
        if (val is SignBit) {
          inv = val.inverted;
        }
        if (product[i] is SignBit) {
          inv = (product[i] as SignBit).inverted;
        }
        product[i] = SignBit(mux(condition, val, product[i]), inverted: inv);
      } else {
        product[i] = mux(condition, val, product[i]);
      }
    } else {
      while (product.length < i) {
        product.add(Const(0));
      }
      partialProducts[row].add(val);
    }
  }

  /// Set the range at absolute position ([row], [col]) to [list].
  void setAbsoluteAll(int row, int col, List<Logic> list) {
    var i = col - rowShift[row];
    final product = partialProducts[row];
    for (final val in list) {
      if (product.length > i) {
        product[i++] = val;
      } else {
        while (product.length < i) {
          product.add(Const(0));
        }
        product.add(val);
        i++;
      }
    }
  }

  /// Mux the range of values into the row starting at absolute position
  ///  ([row], [col]) using [condition] to select the new value
  void muxAbsoluteAll(int row, int col, Logic condition, List<Logic> list) {
    var i = col - rowShift[row];
    final product = partialProducts[row];
    for (final val in list) {
      if (product.length > i) {
        if (val is SignBit || product[i] is SignBit) {
          var inv = false;
          if (val is SignBit) {
            inv = val.inverted;
          }
          if (product[i] is SignBit) {
            inv = (product[i] as SignBit).inverted;
          }
          product[i] = SignBit(mux(condition, val, product[i]), inverted: inv);
        } else {
          product[i] = mux(condition, val, product[i]);
        }
        i++;
      } else {
        while (product.length < i) {
          product.add(Const(0));
        }
        if (val is SignBit) {
          product.add(
              SignBit(mux(condition, val, Const(0)), inverted: val.inverted));
        } else {
          product.add(mux(condition, val, Const(0)));
        }
        i++;
      }
    }
  }

  /// Set a Logic [val] at the absolute position ([row], [col])
  void insertAbsolute(int row, int col, Logic val) =>
      partialProducts[row].insert(col - rowShift[row], val);

  /// Set the values of the row, starting at absolute position ([row], [col])
  /// to the [list] of values
  void insertAbsoluteAll(int row, int col, List<Logic> list) =>
      partialProducts[row].insertAll(col - rowShift[row], list);
}

/// A [PartialProductGenerator] class that generates a set of partial products.
///  Essentially a set of
/// shifted rows of [Logic] addends generated by Booth recoding and
/// manipulated by sign extension, before being compressed
abstract class PartialProductGenerator extends PartialProductArray {
  /// Get the shift increment between neighboring product rows
  int get shift => selector.shift;

  /// The multiplicand term
  Logic get multiplicand => selector.multiplicand;

  /// The multiplier term
  Logic get multiplier => encoder.multiplier;

  /// Encoder for the full multiply operand
  late final MultiplierEncoder encoder;

  /// Selector for the multiplicand which uses the encoder to index into
  /// multiples of the multiplicand and generate partial products
  late final MultiplicandSelector selector;

  /// [multiplicand] operand is always signed
  final bool signedMultiplicand;

  /// [multiplier] operand is always signed
  final bool signedMultiplier;

  /// Used to avoid sign extending more than once
  bool isSignExtended = false;

  /// If not null, use this signal to select between signed and unsigned
  /// [multiplicand].
  final Logic? selectSignedMultiplicand;

  /// If not null, use this signal to select between signed and unsigned
  /// [multiplier].
  final Logic? selectSignedMultiplier;

  /// Construct a [PartialProductGenerator] -- the partial product matrix.
  ///
  /// [signedMultiplier] generates a fixed signed encoder versus using
  /// [selectSignedMultiplier] which is a runtime sign selection [Logic]
  /// in which case [signedMultiplier] must be false.
  PartialProductGenerator(
      Logic multiplicand, Logic multiplier, RadixEncoder radixEncoder,
      {this.signedMultiplicand = false,
      this.signedMultiplier = false,
      this.selectSignedMultiplicand,
      this.selectSignedMultiplier,
      super.name = 'ppg'}) {
    if (signedMultiplier && (selectSignedMultiplier != null)) {
      throw RohdHclException('sign reconfiguration requires signed=false');
    }
    if (signedMultiplicand && (selectSignedMultiplicand != null)) {
      throw RohdHclException('multiplicand sign reconfiguration requires '
          'signedMultiplicand=false');
    }
    encoder = MultiplierEncoder(multiplier, radixEncoder,
        signedMultiplier: signedMultiplier,
        selectSignedMultiplier: selectSignedMultiplier);
    selector = MultiplicandSelector(radixEncoder.radix, multiplicand,
        signedMultiplicand: signedMultiplicand,
        selectSignedMultiplicand: selectSignedMultiplicand);

    if (multiplicand.width < selector.shift) {
      throw RohdHclException('multiplicand width must be greater than '
          'or equal to ${selector.shift}');
    }
    if (multiplier.width < (selector.shift + (signedMultiplier ? 1 : 0))) {
      throw RohdHclException('multiplier width must be greater than '
          'or equal to ${selector.shift + (signedMultiplier ? 1 : 0)}');
    }
    _build();
  }

  /// Perform sign extension (defined in child classes)
  @protected
  void signExtend();

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
