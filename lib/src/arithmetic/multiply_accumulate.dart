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
  late final StaticOrRuntimeParameter signedMultiplicandParameter;

  /// Configuration for signed multiplier [b].
  @protected
  late final StaticOrRuntimeParameter signedMultiplierParameter;

  /// Configuration for signed addend [c].
  @protected
  late final StaticOrRuntimeParameter signedAddendParameter;

  /// The MAC treats multiplicand [a] as always signed.
  @protected
  late bool signedMultiplicand;

  /// The MAC treats multiplier [b] as always signed.
  @protected
  late bool signedMultiplier;

  /// The MAC treats addend [c] as always signed.
  @protected
  late bool signedAddend;

  /// If not null, use this signal to select between signed and unsigned
  /// multiplicand [a].
  @protected
  Logic? get selectSignedMultiplicand =>
      signedMultiplicandParameter.tryRuntimeInput(this);

  /// If not null, use this signal to select between signed and unsigned
  /// multiplier [b]
  @protected
  Logic? get selectSignedMultiplier =>
      signedMultiplierParameter.tryRuntimeInput(this);

  /// If not null, use this signal to select between signed and unsigned
  /// multiplier [b]
  @protected
  Logic? get selectSignedAddend => signedAddendParameter.tryRuntimeInput(this);

  /// Logic that tells us [accumulate] is signed.
  @protected
  Logic get isAccumulateSigned => output('isAccumulateSigned');

  /// Take input [a] and input [b], compute their product, add input [c] to
  /// produce the [accumulate] result.
  ///
  /// The optional [signedMultiplicand] parameter configures the
  /// multiplicand [a] as a signed multiplicand (default is unsigned) or with a
  /// runtime configurable [selectSignedMultiplicand] input.
  ///
  /// The optional [signedMultiplier] parameter configures the multiplier
  /// [b] as a signed multiplier (default is unsigned) or with a runtime
  /// configurable [selectSignedMultiplier] input.
  ///
  /// The optional [signedAddend] parameter configures the addend [c] as a
  /// signed addend (default is unsigned) or with a runtime configurable
  /// [selectSignedAddend] input.
  MultiplyAccumulate(Logic a, Logic b, Logic c,
      {Logic? clk,
      Logic? reset,
      Logic? enable,
      dynamic signedMultiplicand,
      dynamic signedMultiplier,
      dynamic signedAddend,
      super.name = 'multiply_accumulate',
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
        StaticOrRuntimeParameter.ofDynamic(signedMultiplicand);
    signedMultiplierParameter =
        StaticOrRuntimeParameter.ofDynamic(signedMultiplier);
    signedAddendParameter = StaticOrRuntimeParameter.ofDynamic(signedAddend);

    signedMultiplicandParameter.getRuntimeInput(this);
    this.signedMultiplicand = signedMultiplicandParameter.staticConfig;

    signedMultiplierParameter.getRuntimeInput(this);
    this.signedMultiplier = signedMultiplierParameter.staticConfig;

    signedAddendParameter.getRuntimeInput(this);
    this.signedAddend = signedAddendParameter.staticConfig;
    addOutput('accumulate', width: a.width + b.width + 1);

    addOutput('isAccumulateSigned') <=
        signedMultiplicandParameter.getLogic(this) |
            signedMultiplierParameter.getLogic(this) |
            signedAddendParameter.getLogic(this);
  }

  /// This is a helper function that prints out the kind of addend (selected
  /// by a Logic or set statically).) This supplements the Multiplier functions
  /// that can be used for Multiplicand and Multiplier as they are statics:
  /// [Multiplier.signedMD] and [Multiplier.signedML].
  /// - UA: unsigned addend.
  /// - SA: signed addend.
  /// - SSA: dynamic selection of signed addend.
  static String signedAD(dynamic adConfig) =>
      ((adConfig is! StaticOrRuntimeParameter) | (adConfig == null))
          ? 'UA'
          : (adConfig as StaticOrRuntimeParameter).runtimeConfig != null
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
  CompressionTreeMultiplyAccumulate(super.a, super.b, super.c, int radix,
      {Logic? clk,
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
      super.name = 'compression_tree_mac'}) {
    final pp = PartialProduct(
      a,
      b,
      RadixEncoder(radix),
      selectSignedMultiplicand: selectSignedMultiplicand,
      signedMultiplicand: signedMultiplicand,
      selectSignedMultiplier: selectSignedMultiplier,
      signedMultiplier: signedMultiplier,
    );

    seGen(pp.array).signExtend();

    final lastRowLen =
        pp.array.partialProducts[pp.array.partialProducts.length - 1].length +
            pp.rowShift[pp.array.partialProducts.length - 1];

    final additinoalRowSign = mux(
        (selectSignedAddend != null)
            ? selectSignedAddend!
            : (signedAddend ? Const(1) : Const(0)),
        c[c.width - 1],
        Const(0));

    final additionalRow = [for (var i = 0; i < c.width; i++) c[i]];
    while (additionalRow.length < lastRowLen) {
      additionalRow.add(additinoalRowSign);
    }
    additionalRow
      ..add(~additinoalRowSign)
      ..add(Const(1));

    // For online evaluate in _ColumnCompressor to work, we need to
    // insert the row rather than append it.
    pp.array.partialProducts.insert(0, additionalRow);
    pp.rowShift.insert(0, 0);

    pp.generateOutputs();

    final compressor = ColumnCompressor(pp.rows, pp.rowShift,
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

  /// Construct a MultiplyAccumulate that only multiplies to enable
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
    // Here we need to copy the Config and make sure we access our module's
    // input by calling .logic(this) on the runtimeConfig.

    // TODO(desmonddak): try using tryRuntimeInput instead of getLogic.
    final multiply = mulGen(a, b,
        signedMultiplicand: StaticOrRuntimeParameter(
            name: 'selectSignedMultiplicand',
            runtimeConfig: signedMultiplicandParameter.runtimeConfig != null
                ? signedMultiplicandParameter.getLogic(this)
                : null,
            staticConfig: signedMultiplicandParameter.runtimeConfig == null
                ? signedMultiplicandParameter.staticConfig
                : null),
        signedMultiplier: StaticOrRuntimeParameter(
            name: 'selectSignedMultiplier',
            runtimeConfig: signedMultiplierParameter.runtimeConfig != null
                ? signedMultiplierParameter.getLogic(this)
                : null,
            staticConfig: signedMultiplierParameter.runtimeConfig == null
                ? signedMultiplierParameter.staticConfig
                : null));

    accumulate <=
        mux(
            // ignore: invalid_use_of_protected_member
            multiply.isProductSigned,
            multiply.product.signExtend(accumulate.width),
            multiply.product.zeroExtend(accumulate.width));
  }
}
