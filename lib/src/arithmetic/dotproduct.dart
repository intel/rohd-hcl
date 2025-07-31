// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// dotproduct.dart
// An integer dot-product unit.
//
// 2025 July 23
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:collection/collection.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A dot product module for integers.
class DotProduct extends Module {
  /// The dot-product result [product].
  Logic get product => output('product');

  /// Creates a new [DotProduct] instance given a [List<Logic>] of
  /// [multiplicands] and a [List<Logic>] of [multipliers], computing their
  /// dot-product.  Currently widths of all operands must match.
  ///
  /// The [radix] parameter specifies the radix for use in partial-product
  /// generation of the multiplies. While a [ColumnCompressor] is used on the
  /// tall array of partial products, the final addition is accomplished using
  /// the specified [adderGen] (default is [NativeAdder.new]).
  ///
  /// The optional [signedMultiplicand] parameter configures the [multiplicands]
  /// statically using a `bool` to indicate a signed multiplicand (default is
  /// `false`, or unsigned) or dynamically with a 1-bit [Logic] input. Passing
  /// something other null, `bool`, or [Logic] will result in a throw.
  ///
  ///
  /// The optional [signedMultiplier] parameter configures the [multipliers]
  /// statically using a `bool` to indicate a signed multiplier (default is
  /// `false`, or unsigned) or dynamically with a 1-bit [Logic] input.  Passing
  /// something other null, `bool`, or [Logic] will result in a throw.
  ///
  /// The output [product] will be [log2Ceil(multiplicands.length)] wider than
  /// the sum of the widths of one pair of products to accomadate the increasing
  /// accumulation value.
  DotProduct(List<Logic> multiplicands, List<Logic> multipliers,
      {int radix = 4,
      dynamic signedMultiplicand,
      dynamic signedMultiplier,
      Adder Function(Logic a, Logic b, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      super.name = 'dotproduct',
      super.reserveName = false,
      super.reserveDefinitionName = false,
      String? definitionName})
      : super(
            definitionName:
                definitionName ?? 'DotProduct_W{$multipliers[0].width}_') {
    if (multipliers.length != multiplicands.length) {
      throw RohdHclException(
          'Number of multipliers and multiplicands must be equal.');
    }
    final candWidthMiss = multiplicands
        .mapIndexed((i, m) => (i > 0) & (m.width == multiplicands[i - 1].width))
        .where((w) => w)
        .length;
    if (candWidthMiss < multiplicands.length) {
      throw RohdHclException('Multiplicands must all have the same width: '
          'index ${candWidthMiss - 1} vs index $candWidthMiss ');
    }
    // Enforce square products.
    final operandWidthMiss = multiplicands
        .mapIndexed((i, m) => m.width == multipliers[i].width)
        .where((w) => w)
        .length;
    if (candWidthMiss < multiplicands.length) {
      throw RohdHclException('Multiplier and multiplicand at index '
          '$operandWidthMiss must have the same width.');
    }
    if (!MultiplicandSelector.allowedRadices.contains(radix)) {
      throw RohdHclException(
          'Radix must be in ${MultiplicandSelector.allowedRadices}.');
    }

    final signedMultiplicandParameter =
        StaticOrRuntimeParameter.ofDynamic(signedMultiplicand);
    final signedMultiplierParameter =
        StaticOrRuntimeParameter.ofDynamic(signedMultiplier);

    multiplicands = multiplicands
        .mapIndexed((i, multiplicand) => addInput(
            'multiplicand_$i', multiplicand,
            width: multiplicand.width))
        .toList();
    multipliers = multipliers
        .mapIndexed((i, multiplier) =>
            addInput('multiplier_$i', multiplier, width: multiplier.width))
        .toList();

    final ppGenerators = [
      for (var i = 0; i < multipliers.length; i++)
        PartialProductGenerator(
            multiplicands[i], multipliers[i], RadixEncoder(radix),
            signedMultiplicand: signedMultiplicandParameter.staticConfig,
            signedMultiplier: signedMultiplierParameter.staticConfig,
            selectSignedMultiplicand:
                signedMultiplicandParameter.getRuntimeInput(this),
            selectSignedMultiplier:
                signedMultiplierParameter.getRuntimeInput(this))
    ];
    for (final ppG in ppGenerators) {
      StopBitsSignExtension(ppG).signExtend();
    }

    final ppg = ppGenerators.reduce((ppg, ppgNext) {
      ppg.partialProducts.addAll(ppgNext.partialProducts);
      ppg.rowShift.addAll(ppgNext.rowShift);
      return ppg;
    });
    final vec = [
      for (var row = 0; row < ppg.rows; row++)
        ppg.partialProducts[row].rswizzle()
    ];
    final columnCompressor = ColumnCompressor(vec, ppg.rowShift);
    final adder = adderGen(columnCompressor.add0, columnCompressor.add1);
    // An artifact of sign extension creates 2 extra bits in the sum
    final sum = adder.sum.slice(adder.sum.width - 3, 0);
    addOutput('product', width: sum.width) <= sum;
  }
}
