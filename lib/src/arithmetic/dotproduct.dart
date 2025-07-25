// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// dotproduct.dart
// An integer dot-product unit.
//
// 2025 July 23
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A dot product module for integers.
class DotProduct extends Module {
  /// The dot-product result [product].
  Logic get product => output('product');

  /// Creates a new [DotProduct] instance given a [List<Logic>] of
  /// [multiplicands] and a [List<Logic>] of [multipliers] and computing their
  /// dot-product.  Currently widths of all operands must match.
  ///
  /// The optional [signedMultiplicand] parameter configures the [multiplicands]
  /// statically using a bool to indicate a signed multiplicand (default is
  /// false, or unsigned) or dynamically with a 1-bit [Logic] input. Passing
  /// something other null, bool, or [Logic] will result in a throw.
  ///
  ///
  /// The optional [signedMultiplier] parameter configures the [multipliers]
  /// statically using a bool to indicate a signed multiplier (default is false,
  /// or unsigned) or dynamically with a 1-bit [Logic] input.  Passing something
  /// other null, bool, or [Logic] will result in a throw.
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
    for (var i = 1; i < multipliers.length; i++) {
      if (multipliers[i - 1].width != multipliers[i].width) {
        throw RohdHclException('Multipliers must all have the same width: '
            'index ${i - 1} vs index $i ');
      }
    }
    // Enforce square products.
    for (var i = 0; i < multipliers.length; i++) {
      if (multipliers[i].width != multiplicands[i].width) {
        throw RohdHclException('Multiplier and multiplicand at index $i '
            'must have the same width.');
      }
    }
    if (radix != 2 && radix != 4 && radix != 8 && radix != 16) {
      throw RohdHclException('Radix must be 2, 4, 8, or 16.');
    }

    final signedMultiplicandParameter =
        StaticOrRuntimeParameter.ofDynamic(signedMultiplicand);
    final signedMultiplierParameter =
        StaticOrRuntimeParameter.ofDynamic(signedMultiplier);

    multiplicands = [
      for (final multiplicand in multiplicands)
        addInput(
            'multiplicand_${multiplicands.indexOf(multiplicand)}', multiplicand,
            width: multiplicand.width)
    ];
    multipliers = [
      for (final multiplier in multipliers)
        addInput('multiplier_${multipliers.indexOf(multiplier)}', multiplier,
            width: multiplier.width)
    ];

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
    final sum = adder.sum.slice(adder.sum.width - 3, 0);
    addOutput('product', width: sum.width) <= sum;
  }
}
