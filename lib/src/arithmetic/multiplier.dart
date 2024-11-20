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
  /// The input to the multiplier pin [a].
  @protected
  late final Logic a;

  /// The input to the multiplier pin [b].
  @protected
  late final Logic b;

  /// The multiplier treats operands and output as signed
  bool signed;

  /// The multiplication results of the multiplier.
  Logic get product;

  /// Take input [a] and input [b] and return the
  /// [product] of the multiplication result.
  Multiplier(Logic a, Logic b, {required this.signed, super.name}) {
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

  /// The multiplier treats operands and output as signed
  bool signed;

  /// The multiplication results of the multiply-accumulate.
  Logic get accumulate;

  /// Take input [a] and input [b], compute their
  /// product, add input [c] to produce the [accumulate] result.
  MultiplyAccumulate(Logic a, Logic b, Logic c,
      {required this.signed, super.name}) {
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
  /// [a] and [b] are the product terms and they can be different widths
  /// allowing for rectangular multiplication.
  ///
  /// [signed] parameter configures the multiplier as a signed multiplier
  /// (default is unsigned).
  ///
  /// Optional [selectSigned] allows for runtime configuration of signed
  /// or unsigned operation, overriding the [signed] static configuration.
  ///
  /// If [clk] is not null then a set of flops are used to latch the output
  /// after compression.  [reset] and [enable] are optional
  /// inputs to control these flops when [clk] is provided. If [clk] is null,
  /// the [ColumnCompressor] is built as a combinational tree of compressors.
  CompressionTreeMultiplier(super.a, super.b, int radix,
      {this.clk,
      this.reset,
      this.enable,
      Logic? selectSigned,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
          ppTree = KoggeStone.new,
      PartialProductGenerator Function(Logic, Logic, RadixEncoder,
              {required bool signed, Logic? selectSigned})
          ppGen = PartialProductGeneratorCompactRectSignExtension.new,
      bool use42Compressors = false,
      super.signed = false,
      super.name = 'compression_tree_multiplier'}) {
    final internalSelectSigned =
        (selectSigned != null) ? addInput('selectSigned', selectSigned) : null;
    final iClk = (clk != null) ? addInput('clk', clk!) : null;
    final iReset = (reset != null) ? addInput('reset', reset!) : null;
    final iEnable = (enable != null) ? addInput('enable', enable!) : null;

    final product = addOutput('product', width: a.width + b.width);
    final pp = ppGen(a, b, RadixEncoder(radix),
        selectSigned: internalSelectSigned, signed: signed);

    final compressor = ColumnCompressor(
        clk: iClk,
        reset: iReset,
        enable: iEnable,
        pp,
        use42Compressors: use42Compressors)
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
  /// [signed] parameter configures the multiplier as a signed multiplier
  /// (default is unsigned).
  ///
  /// Sign extension methodology is defined by the partial product generator
  /// supplied via [ppGen].
  ///
  /// Optional [selectSigned] allows for runtime configuration of signed
  /// or unsigned operation, overriding the [signed] static configuration.
  ///
  /// If[clk] is not null then a set of flops are used to latch the output
  /// after compression.  [reset] and [enable] are optional
  /// inputs to control these flops when [clk] is provided. If [clk] is null,
  /// the [ColumnCompressor] is built as a combinational tree of compressors.
  CompressionTreeMultiplyAccumulate(super.a, super.b, super.c, int radix,
      {this.clk,
      this.reset,
      this.enable,
      super.signed = false,
      Logic? selectSigned,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
          ppTree = KoggeStone.new,
      PartialProductGenerator Function(Logic, Logic, RadixEncoder,
              {required bool signed, Logic? selectSigned})
          ppGen = PartialProductGeneratorCompactRectSignExtension.new,
      bool use42Compressors = false,
      super.name = 'compression_tree_mac'}) {
    final internalSelectSigned =
        (selectSigned != null) ? addInput('selectSigned', selectSigned) : null;
    final iClk = (clk != null) ? addInput('clk', clk!) : null;
    final iReset = (reset != null) ? addInput('reset', reset!) : null;
    final iEnable = (enable != null) ? addInput('enable', enable!) : null;

    final accumulate = addOutput('accumulate', width: a.width + b.width + 1);
    final pp = ppGen(a, b, RadixEncoder(radix),
        selectSigned: internalSelectSigned, signed: signed);

    final lastLength =
        pp.partialProducts[pp.rows - 1].length + pp.rowShift[pp.rows - 1];

    final sign = mux(
        (internalSelectSigned != null)
            ? internalSelectSigned
            : (signed ? Const(1) : Const(0)),
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

    final compressor = ColumnCompressor(
        clk: iClk,
        reset: iReset,
        enable: iEnable,
        pp,
        use42Compressors: use42Compressors)
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

  /// Construct a MultiplyAccumulate that only multiplies to enable
  /// using the same tester with zero accumulate addend [c].
  MutiplyOnly(super.a, super.b, super.c,
      Multiplier Function(Logic a, Logic b, {Logic? selectSigned}) mulGen,
      {super.signed = false,
      Logic? selectSigned}) // Will be overrwridden by multiplyGenerator
      : super(
            name: 'Multiply Only: '
                '${mulGen.call(a, b, selectSigned: selectSigned).name}') {
    final Logic? internalSelectSigned;

    if (selectSigned != null) {
      internalSelectSigned = addInput('selectSigned', selectSigned);
    } else {
      internalSelectSigned = null;
    }
    final accumulate = addOutput('accumulate', width: a.width + b.width + 1);

    final multiply = mulGen(a, b, selectSigned: internalSelectSigned);
    signed = multiply.signed;

    accumulate <=
        mux(
            (internalSelectSigned != null)
                ? internalSelectSigned
                : (signed ? Const(1) : Const(0)),
            [multiply.product[multiply.product.width - 1], multiply.product]
                .swizzle(),
            multiply.product.zeroExtend(accumulate.width));
  }
}
