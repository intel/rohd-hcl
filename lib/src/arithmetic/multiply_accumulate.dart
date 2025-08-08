// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// multiplier_accumulate.dart
// MultiplyAccumulate abstract class and implementations.
// (formerly part of multiply.dart)
//
// 2025 April 18
// Author:  Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

// TODO(desmonddak): add a multiply generator option to MAC
// TODO(desmonddak): add a variable width output as we did with fp multiply
// as well as a variable width accumulate input

/// An abstract class for all multiply accumulate implementations.
abstract class MultiplyAccumulate extends Module {
  /// The clk for pipelining the multiplication.
  @protected
  Logic? clk;

  /// Optional reset for configurable pipestaging.
  @protected
  Logic? reset;

  /// Optional enable for configurable pipestaging.
  @protected
  Logic? enable;

  /// The input to the multiplier pin [a].
  @protected
  Logic get a => input('a');

  /// The input to the multiplier pin [b].
  @protected
  Logic get b => input('b');

  /// The input to the addend pin [c].
  @protected
  Logic get c => input('c');

  /// The multiplication and addition or [accumulate] result.
  Logic get accumulate => output('accumulate');

  /// Configuration for signed multiplicand [a].
  @protected
  late final StaticOrDynamicParameter signedMultiplicandParameter;

  /// Configuration for signed multiplier [b].
  @protected
  late final StaticOrDynamicParameter signedMultiplierParameter;

  /// Configuration for signed addend [c].
  @protected
  late final StaticOrDynamicParameter signedAddendParameter;

  /// [Logic] that tells us [accumulate] is signed.
  @protected
  Logic get isAccumulateSigned => output('isAccumulateSigned');

  /// Take input [a] and input [b], compute their product, add input [c] to
  /// produce the [accumulate] result.
  ///
  /// The optional [signedMultiplicand] parameter configures the multiplicand
  /// [a] statically using a `bool` to indicate a signed multiplicand (default
  /// is `false`, or unsigned) or dynamically with a 1-bit [Logic] input.
  /// Passing something other than null, `bool`, or [Logic] will result in a
  /// throw.
  ///
  /// The optional [signedMultiplier] parameter configures the multiplier [b]
  /// statically using a `bool` to indicate a signed multiplier (default is
  /// `false`, or unsigned) or dynamically with a 1-bit [Logic] input.  Passing
  /// something other than null, `bool`, or [Logic] will result in a throw.
  ///
  /// The optional [signedAddend] parameter configures the multiplier [c]
  /// statically using a `bool` to indicate a signed addend (default is `false`,
  /// or unsigned) or dynamically with a 1-bit [Logic] input.  Passing something
  /// other null, `bool`, or [Logic] will result in a throw.
  MultiplyAccumulate(Logic a, Logic b, Logic c,
      {Logic? clk,
      Logic? reset,
      Logic? enable,
      dynamic signedMultiplicand,
      dynamic signedMultiplier,
      dynamic signedAddend,
      super.name = 'multiply_accumulate',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'MultiplyAccumulate_W${a.width}x${b.width}_'
                    'Acc${c.width}') {
    this.clk = (clk != null) ? addInput('clk', clk) : null;
    this.reset = (reset != null) ? addInput('reset', reset) : null;
    this.enable = (enable != null) ? addInput('enable', enable) : null;
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    c = addInput('c', c, width: c.width);

    signedMultiplicandParameter =
        StaticOrDynamicParameter.ofDynamic(signedMultiplicand);
    signedMultiplierParameter =
        StaticOrDynamicParameter.ofDynamic(signedMultiplier);
    signedAddendParameter = StaticOrDynamicParameter.ofDynamic(signedAddend);

    addOutput('accumulate', width: a.width + b.width + 1);

    addOutput('isAccumulateSigned') <=
        signedMultiplicandParameter.getLogic(this) |
            signedMultiplierParameter.getLogic(this) |
            signedAddendParameter.getLogic(this);
  }

  /// This is a helper function that prints out the kind of addend (selected by
  /// a [Logic] or set statically by a `bool`).) This supplements the
  /// [Multiplier] functions that can be used for multiplicand and multiplier as
  /// they are statics: [Multiplier.signedMD] and [Multiplier.signedML].
  /// - UA: unsigned addend.
  /// - SA: signed addend.
  /// - SSA: dynamic selection of signed addend.
  static String signedAD(dynamic adConfig) =>
      ((adConfig is! StaticOrDynamicParameter) | (adConfig == null))
          ? 'UA'
          : (adConfig as StaticOrDynamicParameter).dynamicConfig != null
              ? 'SSA'
              : adConfig.staticConfig
                  ? 'SA'
                  : 'UA';
}

/// An implementation of an integer multiply-accumulate using compression trees
class CompressionTreeMultiplyAccumulate extends MultiplyAccumulate {
  /// Construct a compression tree integer multiply-add with a given [radix]
  /// and an [Adder] generator functor [adderGen] for the final adder.
  ///
  /// [a] and [b] are the product terms, [c] is the accumulate term which
  /// must be the sum of the widths plus 1.
  ///
  /// Sign extension methodology is defined by the partial product generator
  /// supplied via [seGen].
  ///
  /// If [clk] is not null then a set of flops are used to latch the output
  /// after compression.  [reset] and [enable] are optional
  /// inputs to control these flops when [clk] is provided. If [clk] is null,
  /// the Column Compressor is built as a combinational tree of compressors.
  CompressionTreeMultiplyAccumulate(super.a, super.b, super.c,
      {int radix = 4,
      Logic? clk,
      Logic? reset,
      Logic? enable,
      super.signedMultiplicand,
      super.signedMultiplier,
      super.signedAddend,
      Adder Function(Logic a, Logic b, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      PartialProductSignExtension Function(PartialProductGeneratorBase pp,
              {String name})
          seGen = CompactRectSignExtension.new,
      super.name = 'compression_tree_mac',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'CompressionTreeMAC_W${a.width}x${b.width}_Acc${c.width}_'
                    '${MultiplyAccumulate.signedAD(signedAddend)}') {
    // Build the partial product generator.

    final ppg = PartialProductGenerator(a, b, RadixEncoder(radix),
        signedMultiplicand: super.signedMultiplicandParameter,
        signedMultiplier: super.signedMultiplierParameter);

    seGen(ppg).signExtend();

    final lastRowLen =
        ppg.partialProducts[ppg.partialProducts.length - 1].length +
            ppg.rowShift[ppg.partialProducts.length - 1];

    final additionalRowSign = mux(
        (signedAddendParameter.dynamicConfig != null)
            ? signedAddendParameter.dynamicConfig!
            : (signedAddendParameter.staticConfig ? Const(1) : Const(0)),
        c[c.width - 1],
        Const(0));

    final additionalRow = [for (var i = 0; i < c.width; i++) c[i]];
    while (additionalRow.length < lastRowLen) {
      additionalRow.add(additionalRowSign);
    }
    additionalRow
      ..add(~additionalRowSign)
      ..add(~additionalRowSign)
      ..add(Const(1));

    // For online evaluate in _ColumnCompressor to work, we need to
    // insert the row rather than append it.
    ppg.partialProducts.insert(0, additionalRow);
    ppg.rowShift.insert(0, 0);

    final ppgRows = [
      for (var row = 0; row < ppg.partialProducts.length; row++)
        ppg.partialProducts[row].rswizzle()
    ];

    final compressor = ColumnCompressor(ppgRows, ppg.rowShift,
        clk: clk, reset: reset, enable: enable);
    final adder = adderGen(compressor.add0, compressor.add1);
    accumulate <= adder.sum.slice(a.width + b.width - 1 + 1, 0);
  }
}

/// A subclass of [MultiplyAccumulate] which ignores the third ([c]) accumulate
/// term and applies the multiplier function.
@visibleForTesting
class MultiplyOnly extends MultiplyAccumulate {
  static String _genName(
          Multiplier Function(Logic a, Logic b,
                  {dynamic signedMultiplicand, dynamic signedMultiplier})
              fn,
          Logic a,
          Logic b,
          dynamic signedMultiplicand,
          dynamic signedMultiplier) =>
      fn(a, b,
              signedMultiplicand: signedMultiplicand,
              signedMultiplier: signedMultiplier)
          .name;

  /// Construct a [MultiplyAccumulate] that only multiplies to enable
  /// using the same tester with zero accumulate addend [c].
  MultiplyOnly(
    super.a,
    super.b,
    super.c,
    Multiplier Function(Logic a, Logic b,
            {dynamic signedMultiplicand, dynamic signedMultiplier})
        mulGen, {
    super.signedMultiplicand,
    super.signedMultiplier,
    super.signedAddend,
  }) // Will be overrwridden by multiplyGenerator
  : super(
            // ignore: prefer_interpolation_to_compose_strings
            name: 'multiply_only_' +
                _genName(mulGen, a, b, signedMultiplicand, signedMultiplier)) {
    final multiply = mulGen(a, b,
        signedMultiplicand: signedMultiplicandParameter.clone(this),
        signedMultiplier: signedMultiplierParameter.clone(this));

    accumulate <=
        mux(
            // ignore: invalid_use_of_protected_member
            multiply.isProductSigned,
            multiply.product.signExtend(accumulate.width),
            multiply.product.zeroExtend(accumulate.width));
  }
}
