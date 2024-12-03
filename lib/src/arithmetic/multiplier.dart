// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// multiplier.dart
// Abstract class of of multiplier module implementation. All multiplier module
// need to inherit this module to ensure consistency.
//
// 2023 May 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/partial_product_sign_extend.dart';

/// An abstract class for all multiplier implementations.
abstract class Multiplier extends Module {
  /// The multiplicand input [a].
  @protected
  late final Logic a;

  /// The multiplier input [b].
  @protected
  late final Logic b;

  /// The multiplier treats input [a] always as a signed input.
  bool signedMultiplicand;

  /// The multiplier treats input [b] always as a signed input.
  bool signedMultiplier;

  /// If not null, use this signal to select between signed and unsigned
  /// multiplicand [a].
  late Logic? selectSignedMultiplicand;

  /// If not null, use this signal to select between signed and unsigned
  /// multiplier [b]
  late Logic? selectSignedMultiplier;

  /// The multiplication results of the multiplier.
  Logic get product;

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
      {required this.signedMultiplicand,
      required this.signedMultiplier,
      this.selectSignedMultiplicand,
      this.selectSignedMultiplier,
      super.name}) {
    this.a = addInput('a', a, width: a.width);
    this.b = addInput('b', b, width: b.width);
  }
}

/// An abstract class for all multiply accumulate implementations.
abstract class MultiplyAccumulate extends Module {
  /// The input to the multiplier pin [a].
  @protected
  late final Logic a;

  /// The input to the multiplier pin [b].
  @protected
  late final Logic b;

  /// The input to the addend pin [c].
  @protected
  late final Logic c;

  /// The MAC treats multiplicand [a] as always signed.
  bool signedMultiplicand;

  /// The MAC treats multiplier [b] as always signed.
  bool signedMultiplier;

  /// The MAC treats addend [c] as always signed.
  bool signedAddend;

  /// If not null, use this signal to select between signed and unsigned
  /// multiplicand [a].
  late Logic? selectSignedMultiplicand;

  /// If not null, use this signal to select between signed and unsigned
  /// multiplier [b]
  late Logic? selectSignedMultiplier;

  /// If not null, use this signal to select between signed and unsigned
  /// addend [c]
  late Logic? selectSignedAddend;

  /// The multiplication results of the multiply-accumulate.
  Logic get accumulate;

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
      {required this.signedMultiplicand,
      required this.signedMultiplier,
      required this.signedAddend,
      this.selectSignedMultiplicand,
      this.selectSignedMultiplier,
      this.selectSignedAddend,
      super.name}) {
    this.a = addInput('a', a, width: a.width);
    this.b = addInput('b', b, width: b.width);
    this.c = addInput('c', c, width: c.width);
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
    selectSignedMultiplicand = (selectSignedMultiplicand != null)
        ? addInput('selectSignedMultiplicand', selectSignedMultiplicand!)
        : null;
    selectSignedMultiplier = (selectSignedMultiplier != null)
        ? addInput('selectSignedMultiplier', selectSignedMultiplier!)
        : null;
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
  Logic? clk;

  /// Optional reset for configurable pipestage
  Logic? reset;

  /// Optional enable for configurable pipestage.
  Logic? enable;

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
      {this.clk,
      this.reset,
      this.enable,
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
    selectSignedMultiplicand = (selectSignedMultiplicand != null)
        ? addInput('selectSignedMultiplicand', selectSignedMultiplicand!)
        : null;
    selectSignedMultiplier = (selectSignedMultiplier != null)
        ? addInput('selectSignedMultiplier', selectSignedMultiplier!)
        : null;
    selectSignedAddend = (selectSignedAddend != null)
        ? addInput('selectSignedAddend', selectSignedAddend!)
        : null;
    final iClk = (clk != null) ? addInput('clk', clk!) : null;
    final iReset = (reset != null) ? addInput('reset', reset!) : null;
    final iEnable = (enable != null) ? addInput('enable', enable!) : null;

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
        ColumnCompressor(clk: iClk, reset: iReset, enable: iEnable, pp)
          ..compress();
    final adder = ParallelPrefixAdder(
        compressor.extractRow(0), compressor.extractRow(1),
        ppGen: ppTree);
    accumulate <= adder.sum.slice(a.width + b.width - 1 + 1, 0);
  }
}

/// A MultiplyAccumulate which ignores the [c] term and applies the
/// multiplier function
class MutiplyOnly extends MultiplyAccumulate {
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
  MutiplyOnly(
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
    if (selectSignedMultiplicand != null) {
      selectSignedMultiplicand =
          addInput('selectSignedMultiplicand', selectSignedMultiplicand!);
    }

    if (selectSignedMultiplier != null) {
      selectSignedMultiplier =
          addInput('selectSignedMultiplier', selectSignedMultiplier!);
    }
    if (selectSignedAddend != null) {
      selectSignedAddend = addInput('selectSignedAddend', selectSignedAddend!);
    }
    final accumulate = addOutput('accumulate', width: a.width + b.width + 1);

    final multiply = mulGen(a, b,
        selectSignedMultiplicand: selectSignedMultiplicand,
        selectSignedMultiplier: selectSignedMultiplier);
    final signed = multiply.signedMultiplicand | multiply.signedMultiplier;

    accumulate <=
        mux(
            (selectSignedMultiplier != null)
                ? selectSignedMultiplier!
                : (signed ? Const(1) : Const(0)),
            [multiply.product[multiply.product.width - 1], multiply.product]
                .swizzle(),
            multiply.product.zeroExtend(accumulate.width));
  }
}
