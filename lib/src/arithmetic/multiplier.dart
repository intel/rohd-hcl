// Copyright (C) 2023-2025 Intel Corporation
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
  /// The clk for pipelining the multiplication.
  @protected
  Logic? clk;

  /// Optional reset for configurable pipestaging.
  @protected
  Logic? reset;

  /// Optional enable for configurable pipestaging.
  @protected
  Logic? enable;

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
  /// If [clk] is not null then a set of flops are used to make the multiply
  /// a 2-cycle latency operation. [reset] and [enable] are optional
  /// inputs to control these flops when [clk] is provided.
  Multiplier(Logic a, Logic b,
      {Logic? clk,
      Logic? reset,
      Logic? enable,
      this.signedMultiplicand = false,
      this.signedMultiplier = false,
      Logic? selectSignedMultiplicand,
      Logic? selectSignedMultiplier,
      super.name = 'multiplier'}) {
    if (signedMultiplicand && (selectSignedMultiplicand != null)) {
      throw RohdHclException('multiplicand sign reconfiguration requires '
          'signedMultiplicand=false');
    }
    if (signedMultiplier && (selectSignedMultiplier != null)) {
      throw RohdHclException('sign reconfiguration requires signed=false');
    }
    this.clk = (clk != null) ? addInput('clk', clk) : null;
    this.reset = (reset != null) ? addInput('reset', reset) : null;
    this.enable = (enable != null) ? addInput('enable', enable) : null;
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

/// A class which wraps the native '*' operator so that it can be passed
/// into other modules as a parameter for using the native operation.
class NativeMultiplier extends Multiplier {
  /// The multiplication results of the multiplier.
  @override
  Logic get product => output('product');

  /// The width of input [a] and [b] must be the same.
  NativeMultiplier(super.a, super.b,
      {super.clk,
      super.reset,
      super.enable,
      super.signedMultiplicand = false,
      super.signedMultiplier = false,
      super.selectSignedMultiplicand,
      super.selectSignedMultiplier,
      super.name = 'native_multiplier'}) {
    if (a.width != b.width) {
      throw RohdHclException('inputs of a and b should have same width.');
    }
    final pW = a.width + b.width;
    final product = addOutput('product', width: pW);

    final Logic extendedMultiplicand;
    final Logic extendedMultiplier;
    if (selectSignedMultiplicand == null) {
      extendedMultiplicand =
          signedMultiplicand ? a.signExtend(pW) : a.zeroExtend(pW);
    } else {
      final len = a.width;
      final sign = a[len - 1];
      final extension = [
        for (var i = len; i < pW; i++)
          mux(selectSignedMultiplicand!, sign, Const(0))
      ];
      extendedMultiplicand = (a.elements + extension).rswizzle();
    }
    if (selectSignedMultiplier == null) {
      extendedMultiplier =
          (signedMultiplier ? b.signExtend(pW) : b.zeroExtend(pW))
              .named('extended_multiplier', naming: Naming.mergeable);
    } else {
      final len = b.width;
      final sign = b[len - 1];
      final extension = [
        for (var i = len; i < pW; i++)
          mux(selectSignedMultiplier!, sign, Const(0))
      ];
      extendedMultiplier = (b.elements + extension)
          .rswizzle()
          .named('extended_multiplier', naming: Naming.mergeable);
    }

    final internalProduct =
        (extendedMultiplicand * extendedMultiplier).named('internalProduct');
    product <= condFlop(clk, reset: reset, en: enable, internalProduct);
  }
}

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
      {Logic? clk,
      Logic? reset,
      Logic? enable,
      this.signedMultiplicand = false,
      this.signedMultiplier = false,
      this.signedAddend = false,
      Logic? selectSignedMultiplicand,
      Logic? selectSignedMultiplier,
      Logic? selectSignedAddend,
      super.name}) {
    this.clk = (clk != null) ? addInput('clk', clk) : null;
    this.reset = (reset != null) ? addInput('reset', reset) : null;
    this.enable = (enable != null) ? addInput('enable', enable) : null;
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

/// An implementation of an integer multiplier using compression trees.
class CompressionTreeMultiplier extends Multiplier {
  /// The final product of the multiplier module.
  @override
  Logic get product => output('product');

  /// Construct a compression tree integer multiplier with a given [radix]
  /// and an [Adder] generator functor [adderGen] for the final adder.
  ///
  /// Sign extension methodology is defined by the partial product generator
  /// supplied via [seGen].
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
  ///
  /// [use42Compressors] will combine 4:2, 3:2, and 2:2 compressors in building
  /// a compression tree.
  CompressionTreeMultiplier(super.a, super.b, int radix,
      {super.clk,
      super.reset,
      super.enable,
      super.signedMultiplicand = false,
      super.signedMultiplier = false,
      super.selectSignedMultiplicand,
      super.selectSignedMultiplier,
      Adder Function(Logic a, Logic b, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      PartialProductSignExtension Function(PartialProductGeneratorBase pp,
              {String name})
          seGen = CompactRectSignExtension.new,

      super.name = 'compression_tree_multiplier'}) {
// Should be done in base TODO(desmonddak):
    final product = addOutput('product', width: a.width + b.width);
    final pp = PartialProductGenerator(
      a,
      b,
      RadixEncoder(radix),
      selectSignedMultiplicand: selectSignedMultiplicand,
      signedMultiplicand: signedMultiplicand,
      selectSignedMultiplier: selectSignedMultiplier,
      signedMultiplier: signedMultiplier,
    );
    seGen(pp).signExtend();
    final compressor =
        ColumnCompressor(clk: clk, reset: reset, enable: enable, pp, use42Compressors: use42Compressors)
          ..compress();
    final adder = adderGen(compressor.extractRow(0), compressor.extractRow(1));

    product <= adder.sum.slice(a.width + b.width - 1, 0);
  }
}

/// An implementation of an integer multiply-accumulate using compression trees
class CompressionTreeMultiplyAccumulate extends MultiplyAccumulate {
  /// The final product of the multiplier module.
  @override
  Logic get accumulate => output('accumulate');

  /// Construct a compression tree integer multiply-add with a given [radix]
  /// and an [Adder] generator functor [adderGen] for the final adder.
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
  /// supplied via [seGen].
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
  /// If [clk] is not null then a set of flops are used to latch the output
  /// after compression.  [reset] and [enable] are optional
  /// inputs to control these flops when [clk] is provided. If [clk] is null,
  /// the [ColumnCompressor] is built as a combinational tree of compressors.
  ///
  /// [use42Compressors] will combine 4:2, 3:2, and 2:2 compressors in building
  /// a compression tree.
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
      Adder Function(Logic a, Logic b, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      PartialProductSignExtension Function(PartialProductGeneratorBase pp,
              {String name})
          seGen = CompactRectSignExtension.new,
             bool use42Compressors = false,

      super.name = 'compression_tree_mac'}) {
    final accumulate = addOutput('accumulate', width: a.width + b.width + 1);
    final pp = PartialProductGenerator(
      a,
      b,
      RadixEncoder(radix),
      selectSignedMultiplicand: selectSignedMultiplicand,
      signedMultiplicand: signedMultiplicand,
      selectSignedMultiplier: selectSignedMultiplier,
      signedMultiplier: signedMultiplier,
    );

    seGen(pp).signExtend();

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
        ColumnCompressor(clk: clk, reset: reset, enable: enable, pp, use42Compressors: use42Compressors)
          ..compress();
    final adder = adderGen(compressor.extractRow(0), compressor.extractRow(1));
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
