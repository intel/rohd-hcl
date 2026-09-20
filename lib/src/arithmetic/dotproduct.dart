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
  /// [multiplicands] and a [List<Logic>] of [multipliers].
  ///
  /// Every multiplicand must have one common width and every multiplier must
  /// have one common width. The multiplicand and multiplier widths may differ.
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
  /// the sum of one multiplicand width and one multiplier width to accommodate
  /// the increasing accumulation value.
  DotProductBase(List<Logic> multiplicands, List<Logic> multipliers,
      {dynamic signedMultiplicand,
      dynamic signedMultiplier,
      super.name = 'dotproduct',
      super.reserveName = false,
      super.reserveDefinitionName = false,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'DotProduct_L${multipliers.length}_'
                    'A${multiplicands[0].width}_B${multipliers[0].width}_'
                    '${Multiplier.signedMD(signedMultiplicand)}_'
                    '${Multiplier.signedML(signedMultiplier)}') {
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
          '${multiplicands.length - candWidthMiss} '
          "don't match preceding width.");
    }
    final multiplierWidthMiss = multipliers
        .mapIndexed((i, m) => m.width == multipliers[i > 0 ? i - 1 : 0].width)
        .where((w) => w)
        .length;
    if (multiplierWidthMiss < multipliers.length) {
      throw RohdHclException('Multipliers must all have the same width: '
          '${multipliers.length - multiplierWidthMiss} '
          "don't match preceding width.");
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
                'CompressionTreeDotProduct_L${multipliers.length}_'
                    'A${multiplicands[0].width}_B${multipliers[0].width}_'
                    'R${productRadix}_'
                    '${Multiplier.signedMD(signedMultiplicand)}_'
                    '${Multiplier.signedML(signedMultiplier)}') {
    if (multiplicands.first.width != multipliers.first.width) {
      throw RohdHclException(
        'CompressionTreeDotProduct requires equal multiplicand and '
        'multiplier widths.',
      );
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

  late final bool _signedProduct;
  late final Logic? _selectSignedProduct;

  /// Construct a [GeneralDotProduct] with a [List] of [multiplicands] and
  /// [multipliers], a [multiplierGen] for constructing products, and an
  /// [adderGen] function to generate [Adder]s for use in a [ReductionTree] for
  /// the final addition of the products.
  GeneralDotProduct(super.multiplicands, super.multipliers,
      {super.signedMultiplicand,
      super.signedMultiplier,
      int treeRadix = 2,
      String multiplierIdentity = 'native',
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
                'GeneralDotProduct_L${multipliers.length}_'
                    'A${multiplicands[0].width}_B${multipliers[0].width}_'
                    'R${treeRadix}_${multiplierIdentity}_'
                    '${Multiplier.signedMD(signedMultiplicand)}_'
                    '${Multiplier.signedML(signedMultiplier)}') {
    final hasRuntimeSign = signedMultiplicandParameter.runtimeConfig != null ||
        signedMultiplierParameter.runtimeConfig != null;
    _signedProduct = !hasRuntimeSign &&
        (signedMultiplicandParameter.staticConfig ||
            signedMultiplierParameter.staticConfig);
    _selectSignedProduct = hasRuntimeSign
        ? signedMultiplicandParameter.getLogic(this) |
            signedMultiplierParameter.getLogic(this)
        : null;

    final dotResults = [
      for (var i = 0; i < multipliers.length; i++)
        multiplierGen(multiplicands[i], multipliers[i],
                signedMultiplicand: signedMultiplicandParameter.isRuntime
                    ? signedMultiplicandParameter.getRuntimeInput(this)
                    : signedMultiplicandParameter.staticConfig,
                signedMultiplier: signedMultiplierParameter.isRuntime
                    ? signedMultiplierParameter.getRuntimeInput(this)
                    : signedMultiplierParameter.staticConfig)
            .product
    ];

    final prefixAdd = ReductionTreeGenerator(
      dotResults,
      addReduceAdders,
      signExtend: _selectSignedProduct ?? _signedProduct,
      control: _selectSignedProduct,
      radix: treeRadix,
    );
    addOutput('product', width: prefixAdd.out.width) <= prefixAdd.out;
  }

  /// Reduction tree adder generator for the final addition.
  Logic addReduceAdders(List<Logic> inputs,
      {int? depth, Logic? control, String name = 'prefix'}) {
    var level = inputs;
    var stage = 0;
    while (level.length > 1) {
      final nextLevel = <Logic>[];
      for (var i = 0; i < level.length; i += 2) {
        if (i + 1 == level.length) {
          nextLevel.add(level[i]);
          continue;
        }

        final inputWidth = level[i].width > level[i + 1].width
            ? level[i].width
            : level[i + 1].width;
        final resultWidth = inputWidth + 1;
        final a = _extendForSum(level[i], resultWidth, control);
        final b = _extendForSum(level[i + 1], resultWidth, control);
        final sum = adderGen(a, b, name: '${name}_s${stage}_add${i ~/ 2}').sum;
        nextLevel.add(sum.slice(resultWidth - 1, 0));
      }
      level = nextLevel;
      stage++;
    }
    return level.single;
  }

  Logic _extendForSum(Logic value, int width, Logic? control) => control == null
      ? _signedProduct
          ? value.signExtend(width)
          : value.zeroExtend(width)
      : mux(control, value.signExtend(width), value.zeroExtend(width));
}
