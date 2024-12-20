// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// multiplier.dart
// Abstract class of of multiplier module implementation. All multiplier module
// need to inherit this module to ensure consistency.
//
// 2023 May 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>, Desmond Kirkpatrick
// <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/partial_product_sign_extend.dart';

/// An abstract class for all multiplier implementations.
abstract class Multiplier extends Module {
  /// The multiplicand input [a].
  @protected
  Logic get a => input('a');

  /// The multiplier input [b].
  @protected
  Logic get b => input('b');

  /// The multiplier treats input [a] always as a signed input.
  @protected
  final bool signedMultiplicand;

  /// The multiplier treats input [b] always as a signed input.
  @protected
  final bool signedMultiplier;

  /// If not null, use this signal to select between signed and unsigned
  /// multiplicand [a].
  @protected
  Logic? get selectSignedMultiplicand => tryInput('selectSignedMultiplicand');

  /// If not null, use this signal to select between signed and unsigned
  /// multiplier [b]
  @protected
  Logic? get selectSignedMultiplier => tryInput('selectSignedMultiplier');

  /// The multiplication results of the multiplier.
  Logic get product;

  /// Logic that tells us [product] is signed.
  @protected
  Logic get isProductSigned => output('isProductSigned');

  /// Take input [a] and input [b] and return the
  /// [product] of the multiplication result.
  ///
  /// [signedMultiplicand] parameter configures the multiplicand [a] as a signed
  /// multiplier (default is unsigned).
  ///
  /// [signedMultiplier] parameter configures the multiplier [b] as a signed
  /// multiplier (default is unsigned).
  ///
  /// Optional [selectSignedMultiplicand] allows for runtime configuration of
  /// signed or unsigned operation, overriding the [signedMultiplicand] static
  /// configuration.
  ///
  /// Optional [selectSignedMultiplier] allows for runtime configuration of
  /// signed or unsigned operation, overriding the [signedMultiplier] static
  /// configuration.
  Multiplier(Logic a, Logic b,
      {this.signedMultiplicand = false,
      this.signedMultiplier = false,
      Logic? selectSignedMultiplicand,
      Logic? selectSignedMultiplier,
      super.name}) {
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);

    selectSignedMultiplicand = (selectSignedMultiplicand != null)
        ? addInput('selectSignedMultiplicand', selectSignedMultiplicand)
        : null;
    selectSignedMultiplier = (selectSignedMultiplier != null)
        ? addInput('selectSignedMultiplier', selectSignedMultiplier)
        : null;

    addOutput('isProductSigned') <=
        (signedMultiplicand | signedMultiplier ? Const(1) : Const(0)) |
            ((selectSignedMultiplicand != null)
                ? selectSignedMultiplicand
                : Const(0)) |
            ((selectSignedMultiplier != null)
                ? selectSignedMultiplier
                : Const(0));
  }
}

/// An abstract class for all multiply accumulate implementations.
abstract class MultiplyAccumulate extends Module {
  /// The input to the multiplier pin [a].
  @protected
  Logic get a => input('a');

  /// The input to the multiplier pin [b].
  @protected
  Logic get b => input('b');

  /// The input to the addend pin [c].
  @protected
  Logic get c => input('c');

  /// The MAC treats multiplicand [a] as always signed.
  @protected
  final bool signedMultiplicand;

  /// The MAC treats multiplier [b] as always signed.
  @protected
  final bool signedMultiplier;

  /// The MAC treats addend [c] as always signed.
  @protected
  final bool signedAddend;

  /// If not null, use this signal to select between signed and unsigned
  /// multiplicand [a].
  @protected
  Logic? get selectSignedMultiplicand => tryInput('selectSignedMultiplicand');

  /// If not null, use this signal to select between signed and unsigned
  /// multiplier [b]
  @protected
  Logic? get selectSignedMultiplier => tryInput('selectSignedMultiplier');

  /// If not null, use this signal to select between signed and unsigned
  /// addend [c]
  @protected
  Logic? get selectSignedAddend => tryInput('selectSignedAddend');

  /// The multiplication and addition or [accumulate] result.
  Logic get accumulate;

  /// Logic that tells us [accumulate] is signed.
  @protected
  Logic get isAccumulateSigned => output('isAccumulateSigned');

  /// Take input [a] and input [b], compute their
  /// product, add input [c] to produce the [accumulate] result.
  ///
  /// Optional [selectSignedMultiplicand] allows for runtime configuration of
  /// signed or unsigned operation, overriding the [signedMultiplicand] static
  /// configuration.
  ///
  /// Optional [selectSignedMultiplier] allows for runtime configuration of
  /// signed or unsigned operation, overriding the [signedMultiplier] static
  /// configuration.
  ///
  /// Optional [selectSignedAddend] allows for runtime configuration of
  /// signed or unsigned operation, overriding the [signedAddend] static
  /// configuration.
  MultiplyAccumulate(Logic a, Logic b, Logic c,
      {this.signedMultiplicand = false,
      this.signedMultiplier = false,
      this.signedAddend = false,
      Logic? selectSignedMultiplicand,
      Logic? selectSignedMultiplier,
      Logic? selectSignedAddend,
      super.name}) {
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    c = addInput('c', c, width: c.width);
    selectSignedMultiplicand = (selectSignedMultiplicand != null)
        ? addInput('selectSignedMultiplicand', selectSignedMultiplicand)
        : null;
    selectSignedMultiplier = (selectSignedMultiplier != null)
        ? addInput('selectSignedMultiplier', selectSignedMultiplier)
        : null;
    selectSignedAddend = (selectSignedAddend != null)
        ? addInput('selectSignedAddend', selectSignedAddend)
        : null;
    addOutput('isAccumulateSigned') <=
        (signedMultiplicand | signedMultiplier | signedAddend
                ? Const(1)
                : Const(0)) |
            ((selectSignedMultiplicand != null)
                ? selectSignedMultiplicand
                : Const(0)) |
            ((selectSignedMultiplier != null)
                ? selectSignedMultiplier
                : Const(0)) |
            ((selectSignedAddend != null) ? selectSignedAddend : Const(0));
  }
}

/// An implementation of an integer multiplier using compression trees
class CompressionTreeMultiplier extends Multiplier {
  /// The clk for the pipelined version of column compression.
  Logic? clk;

  /// Optional reset for configurable pipestage
  Logic? reset;

  /// Optional enable for configurable pipestage.
  Logic? enable;

  /// The final product of the multiplier module.
  @override
  Logic get product => output('product');

  /// Construct a compression tree integer multiplier with a given [radix]
  /// and prefix tree functor [ppTree] for the compressor and final adder.
  ///
  /// Sign extension methodology is defined by the partial product generator
  /// supplied via [ppGen].
  ///
  /// [a] multiplicand and [b] multiplier are the product terms and they can
  /// be different widths allowing for rectangular multiplication.
  ///
  /// [signedMultiplicand] parameter configures the multiplicand [a] as a signed
  /// multiplier (default is unsigned).
  ///
  /// [signedMultiplier] parameter configures the multiplier [b] as a signed
  /// multiplier (default is unsigned).
  ///
  /// Optional [selectSignedMultiplicand] allows for runtime configuration of
  /// signed or unsigned operation, overriding the [signedMultiplicand] static
  /// configuration.
  ///
  /// Optional [selectSignedMultiplier] allows for runtime configuration of
  /// signed or unsigned operation, overriding the [signedMultiplier] static
  /// configuration.
  ///
  /// If [clk] is not null then a set of flops are used to latch the output
  /// after compression.  [reset] and [enable] are optional
  /// inputs to control these flops when [clk] is provided. If [clk] is null,
  /// the [ColumnCompressor] is built as a combinational tree of compressors.
  CompressionTreeMultiplier(super.a, super.b, int radix,
      {this.clk,
      this.reset,
      this.enable,
      super.signedMultiplicand = false,
      super.signedMultiplier = false,
      super.selectSignedMultiplicand,
      super.selectSignedMultiplier,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
          ppTree = KoggeStone.new,
      PartialProductGenerator Function(Logic, Logic, RadixEncoder,
              {required bool signedMultiplier,
              required bool signedMultiplicand,
              Logic? selectSignedMultiplier,
              Logic? selectSignedMultiplicand})
          ppGen = PartialProductGeneratorCompactRectSignExtension.new,
      super.name = 'compression_tree_multiplier'}) {
    clk = (clk != null) ? addInput('clk', clk!) : null;
    reset = (reset != null) ? addInput('reset', reset!) : null;
    enable = (enable != null) ? addInput('enable', enable!) : null;

    final product = addOutput('product', width: a.width + b.width);
    final pp = ppGen(
      a,
      b,
      RadixEncoder(radix),
      selectSignedMultiplicand: selectSignedMultiplicand,
      signedMultiplicand: signedMultiplicand,
      selectSignedMultiplier: selectSignedMultiplier,
      signedMultiplier: signedMultiplier,
    );

    final compressor =
        ColumnCompressor(clk: clk, reset: reset, enable: enable, pp)
          ..compress();
    final adder = ParallelPrefixAdder(
        compressor.extractRow(0), compressor.extractRow(1),
        ppGen: ppTree);
    product <= adder.sum.slice(a.width + b.width - 1, 0);
  }
}

/// An implementation of an integer multiply-accumulate using compression trees
class CompressionTreeMultiplyAccumulate extends MultiplyAccumulate {
  /// The clk for the pipelined version of column compression.
  @protected
  Logic? get clk => tryInput('clk');

  /// Optional reset for configurable pipestage
  @protected
  Logic? get reset => tryInput('reset');

  /// Optional enable for configurable pipestage.
  @protected
  Logic? get enable => tryInput('enable');

  /// The final product of the multiplier module.
  @override
  Logic get accumulate => output('accumulate');

  /// Construct a compression tree integer multiply-add with a given [radix]
  /// and prefix tree functor [ppTree] for the compressor and final adder.
  ///
  /// [a] and [b] are the product terms, [c] is the accumulate term which
  /// must be the sum of the widths plus 1.
  ///
  /// [signedMultiplicand] parameter configures the multiplicand [a] as
  /// always signed (default is unsigned).
  ///
  /// [signedMultiplier] parameter configures the multiplier [b] as
  /// always signed (default is unsigned).
  ///
  /// [signedAddend] parameter configures the addend [c] as
  /// always signed (default is unsigned).
  ///
  /// Sign extension methodology is defined by the partial product generator
  /// supplied via [ppGen].
  ///
  /// Optional [selectSignedMultiplicand] allows for runtime configuration of
  /// signed or unsigned operation, overriding the [signedMultiplicand] static
  /// configuration.
  ///
  /// Optional [selectSignedMultiplier] allows for runtime configuration of
  /// signed or unsigned operation, overriding the [signedMultiplier] static
  /// configuration.
  ///
  /// Optional [selectSignedAddend] allows for runtime configuration of
  /// signed or unsigned operation, overriding the [signedAddend] static
  /// configuration.
  ///
  /// If[clk] is not null then a set of flops are used to latch the output
  /// after compression.  [reset] and [enable] are optional
  /// inputs to control these flops when [clk] is provided. If [clk] is null,
  /// the [ColumnCompressor] is built as a combinational tree of compressors.
  CompressionTreeMultiplyAccumulate(super.a, super.b, super.c, int radix,
      {Logic? clk,
      Logic? reset,
      Logic? enable,
      super.signedMultiplicand = false,
      super.signedMultiplier = false,
      super.signedAddend = false,
      super.selectSignedMultiplicand,
      super.selectSignedMultiplier,
      super.selectSignedAddend,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
          ppTree = KoggeStone.new,
      PartialProductGenerator Function(Logic, Logic, RadixEncoder,
              {required bool signedMultiplier,
              required bool signedMultiplicand,
              Logic? selectSignedMultiplier,
              Logic? selectSignedMultiplicand})
          ppGen = PartialProductGeneratorCompactRectSignExtension.new,
      super.name = 'compression_tree_mac'}) {
    clk = (clk != null) ? addInput('clk', clk) : null;
    reset = (reset != null) ? addInput('reset', reset) : null;
    enable = (enable != null) ? addInput('enable', enable) : null;

    final accumulate = addOutput('accumulate', width: a.width + b.width + 1);
    final pp = ppGen(
      a,
      b,
      RadixEncoder(radix),
      selectSignedMultiplicand: selectSignedMultiplicand,
      signedMultiplicand: signedMultiplicand,
      selectSignedMultiplier: selectSignedMultiplier,
      signedMultiplier: signedMultiplier,
    );

    final lastLength =
        pp.partialProducts[pp.rows - 1].length + pp.rowShift[pp.rows - 1];

    final sign = mux(
        (selectSignedAddend != null)
            ? selectSignedAddend!
            : (signedAddend ? Const(1) : Const(0)),
        c[c.width - 1],
        Const(0));
    final l = [for (var i = 0; i < c.width; i++) c[i]];
    while (l.length < lastLength) {
      l.add(sign);
    }
    l
      ..add(~sign)
      ..add(Const(1));

    // For online evaluate in _ColumnCompressor to work, we need to
    // insert the row rather than append it.
    pp.partialProducts.insert(0, l);
    pp.rowShift.insert(0, 0);

    final compressor =
        ColumnCompressor(clk: clk, reset: reset, enable: enable, pp)
          ..compress();
    final adder = ParallelPrefixAdder(
        compressor.extractRow(0), compressor.extractRow(1),
        ppGen: ppTree);
    accumulate <= adder.sum.slice(a.width + b.width - 1 + 1, 0);
  }
}

/// A MultiplyAccumulate which ignores the [c] term and applies the
/// multiplier function
class MultiplyOnly extends MultiplyAccumulate {
  @override
  Logic get accumulate => output('accumulate');

  static String _genName(
          Multiplier Function(Logic a, Logic b,
                  {Logic? selectSignedMultiplicand,
                  Logic? selectSignedMultiplier})
              fn,
          Logic a,
          Logic b,
          Logic? selectSignedMultiplicand,
          Logic? selectSignedMultiplier) =>
      fn(a, b,
              selectSignedMultiplicand: selectSignedMultiplicand,
              selectSignedMultiplier: selectSignedMultiplier)
          .name;

  /// Construct a MultiplyAccumulate that only multiplies to enable
  /// using the same tester with zero accumulate addend [c].
  MultiplyOnly(
    super.a,
    super.b,
    super.c,
    Multiplier Function(Logic a, Logic b,
            {Logic? selectSignedMultiplicand, Logic? selectSignedMultiplier})
        mulGen, {
    super.signedMultiplicand = false,
    super.signedMultiplier = false,
    super.signedAddend = false,
    super.selectSignedMultiplicand,
    super.selectSignedMultiplier,
    super.selectSignedAddend,
  }) // Will be overrwridden by multiplyGenerator
  : super(
            // ignore: prefer_interpolation_to_compose_strings
            name: 'Multiply Only: ' +
                _genName(mulGen, a, b, selectSignedMultiplicand,
                    selectSignedMultiplier)) {
    final accumulate = addOutput('accumulate', width: a.width + b.width + 1);

    final multiply = mulGen(a, b,
        selectSignedMultiplicand: selectSignedMultiplicand,
        selectSignedMultiplier: selectSignedMultiplier);

    accumulate <=
        mux(
            multiply.isProductSigned,
            multiply.product.signExtend(accumulate.width),
            multiply.product.zeroExtend(accumulate.width));
  }
}
