// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// dotproduct.dart
// A set of integer dot-product units.
//
// 2025 July 23
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:collection/collection.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A dot product module for integers.
class DotProductBase extends Module {
  /// The dot-product result [product].
  Logic get product => output('product');

  /// The multiplicands input [multiplicands].
  late final List<Logic> multiplicands;

  /// The multipliers input [multipliers].
  late final List<Logic> multipliers;

  /// Whether the multiplicands are signed.
  late final StaticOrRuntimeParameter signedMultiplicandParameter;

  /// Whether the multipliers are signed.
  late final StaticOrRuntimeParameter signedMultiplierParameter;

  /// Creates a new [DotProductBase] instance given a [List<Logic>] of
  /// [multiplicands] and a [List<Logic>] of [multipliers].  Currently widths of
  /// all operands must match.
  ///
  /// The optional [signedMultiplicand] parameter configures the [multiplicands]
  /// statically using a `bool` to indicate a signed multiplicand (default is
  /// `false`, or unsigned) or dynamically with a 1-bit [Logic] input. Passing
  /// something other null, `bool`, or [Logic] will result in a throw.
  ///
  /// The optional [signedMultiplier] parameter configures the [multipliers]
  /// statically using a `bool` to indicate a signed multiplier (default is
  /// `false`, or unsigned) or dynamically with a 1-bit [Logic] input.  Passing
  /// something other null, `bool`, or [Logic] will result in a throw.
  ///
  /// The output [product] will be [log2Ceil(multiplicands.length)] wider than
  /// the sum of the widths of one pair of products to accomadate the increasing
  /// accumulation value.
  DotProductBase(List<Logic> multiplicands, List<Logic> multipliers,
      {dynamic signedMultiplicand,
      dynamic signedMultiplier,
      super.name = 'dotproduct',
      super.reserveName = false,
      super.reserveDefinitionName = false,
      String? definitionName})
      : super(
            definitionName:
                definitionName ?? 'DotProduct_W${multipliers[0].width}_') {
    if (multipliers.length != multiplicands.length) {
      throw RohdHclException(
          'Number of multipliers and multiplicands must be equal.');
    }

    final candWidthMiss = multiplicands
        .mapIndexed((i, m) => m.width == multiplicands[i > 0 ? i - 1 : 0].width)
        .where((w) => w)
        .length;
    if (candWidthMiss < multiplicands.length) {
      throw RohdHclException('Multiplicands must all have the same width: '
          'index ${candWidthMiss - 1} vs index $candWidthMiss ');
    }
    // Enforce square products.
    final operandWidthMiss = multiplicands
        .mapIndexed((i, m) => m.width != multipliers[i].width)
        .where((w) => !w)
        .length;
    if (candWidthMiss < multiplicands.length) {
      throw RohdHclException('Multiplier and multiplicand at index '
          '$operandWidthMiss must have the same width.');
    }

    signedMultiplicandParameter =
        StaticOrRuntimeParameter.ofDynamic(signedMultiplicand);
    signedMultiplierParameter =
        StaticOrRuntimeParameter.ofDynamic(signedMultiplier);

    this.multiplicands = multiplicands
        .mapIndexed((i, multiplicand) => addInput(
            'multiplicand_$i', multiplicand,
            width: multiplicand.width))
        .toList();
    this.multipliers = multipliers
        .mapIndexed((i, multiplier) =>
            addInput('multiplier_$i', multiplier, width: multiplier.width))
        .toList();
  }
}

/// An integer dot product module using a [ColumnCompressor].
class CompressionTreeDotProduct extends DotProductBase {
  /// The [productRadix] parameter specifies the radix for use in
  /// partial-product generation of the multiplies. While a [ColumnCompressor]
  /// is used on the tall array of partial products, the final addition is
  /// accomplished using the specified [adderGen] (default is
  /// [NativeAdder.new]).
  CompressionTreeDotProduct(super.multiplicands, super.multipliers,
      {super.signedMultiplicand,
      super.signedMultiplier,
      int productRadix = 4,
      Adder Function(Logic a, Logic b, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      super.name = 'compression_tree_dotproduct',
      super.reserveName = false,
      super.reserveDefinitionName = false,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'CompTreeDotProduct_W${multipliers[0].width}_') {
    if (!MultiplicandSelector.allowedRadices.contains(productRadix)) {
      throw RohdHclException(
          'Radix must be in ${MultiplicandSelector.allowedRadices}.');
    }

    final ppGenerators = [
      for (var i = 0; i < multipliers.length; i++)
        PartialProductGenerator(
            multiplicands[i], multipliers[i], RadixEncoder(productRadix),
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
    // An artifact of sign extension creates 2 extra bits in the sum.
    final sum = adder.sum.slice(adder.sum.width - 3, 0);
    addOutput('product', width: sum.width) <= sum;
  }
}

/// General version of the [DotProductBase] module that uses provided
/// [Multiplier] and [Adder] functions to construct the dot product computation.
class GeneralDotProduct extends DotProductBase {
  /// Adder generator used in reduction tree for the final addition.
  final Adder Function(Logic a, Logic b, {Logic? carryIn, String name})
      adderGen;

  /// Construct a [GeneralDotProduct] with a [List] of [multiplicands] and
  /// [multipliers], a [multiplierGen] for constructing products, and an
  /// [adderGen] function to generate [Adder]s for use in a [ReductionTree] for
  /// the final addition of the products.
  GeneralDotProduct(super.multiplicands, super.multipliers,
      {super.signedMultiplicand,
      super.signedMultiplier,
      int treeRadix = 2,
      this.adderGen = NativeAdder.new,
      Multiplier Function(Logic a, Logic b,
              {Logic? clk,
              Logic? reset,
              Logic? enable,
              dynamic signedMultiplicand,
              dynamic signedMultiplier})
          multiplierGen = NativeMultiplier.new,
      super.name = 'dotproduct',
      super.reserveName = false,
      super.reserveDefinitionName = false,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'DotProductNative_W${multipliers[0].width}_') {
    final dotResults = [
      for (var i = 0; i < multipliers.length; i++)
        multiplierGen(multiplicands[i], multipliers[i],
                signedMultiplicand: signedMultiplicandParameter.getLogic(this),
                signedMultiplier: signedMultiplierParameter.getLogic(this))
            .product
    ];

    // TODO(desmonddak): add sign extension option for use with unsigned
    // multipliers and multiplicands.

    final prefixAdd = ReductionTree(dotResults, addReduceAdders,
        signExtend: true,
        radix: treeRadix,
        name: 'dotproduct_reduction_tree',
        definitionName: 'DotProductReductionTree_W${multiplicands[0].width}_'
            '${multipliers[0].width}_R$treeRadix');
    addOutput('product', width: prefixAdd.out.width) <= prefixAdd.out;
  }

  /// Reduction tree adder generator for the final addition.
  Logic addReduceAdders(List<Logic> inputs,
      {int? depth, Logic? control, String name = 'prefix'}) {
    if (inputs.length < 4) {
      return inputs.reduce((v, e) => v + e);
    } else {
      final add0 = adderGen(inputs[0], inputs[1], name: '${name}_add0');
      final add1 = adderGen(inputs[2], inputs[3], name: '${name}_add1');
      final addf =
          adderGen(add0.sum, add1.sum, name: '${name}_addf_${depth ?? 0}');
      return addf.sum;
    }
  }
}

// TODO(desmonddak): reduction tree needs dynamic sign extension control.
// TODO(desmonddak):  dynamic parameter:  we should be able to pass the
// null, bool, Logic() or the parameter itself to the constructor.
