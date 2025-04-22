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
import 'package:rohd_hcl/src/arithmetic/multiplier_components/partial_product_sign_extend.dart';

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
      super.name,
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
    selectSignedMultiplicand = (selectSignedMultiplicand != null)
        ? addInput('selectSignedMultiplicand', selectSignedMultiplicand)
        : null;
    selectSignedMultiplier = (selectSignedMultiplier != null)
        ? addInput('selectSignedMultiplier', selectSignedMultiplier)
        : null;
    selectSignedAddend = (selectSignedAddend != null)
        ? addInput('selectSignedAddend', selectSignedAddend)
        : null;
    addOutput('accumulate', width: a.width + b.width + 1);

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

/// An implementation of an integer multiply-accumulate using compression trees
class CompressionTreeMultiplyAccumulate extends MultiplyAccumulate {
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
  /// the Column Compressor is built as a combinational tree of compressors.
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

    final compressor = ColumnCompressorModule(pp.rows, pp.rowShift,
        clk: clk, reset: reset, enable: enable)
      ..compress();
    final adder = adderGen(compressor.add0, compressor.add1);
    accumulate <= adder.sum.slice(a.width + b.width - 1 + 1, 0);
  }
}

/// A MultiplyAccumulate which ignores the [c] term and applies the
/// multiplier function
class MultiplyOnly extends MultiplyAccumulate {
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
    final multiply = mulGen(a, b,
        selectSignedMultiplicand: selectSignedMultiplicand,
        selectSignedMultiplier: selectSignedMultiplier);

    accumulate <=
        mux(
            // ignore: invalid_use_of_protected_member
            multiply.isProductSigned,
            multiply.product.signExtend(accumulate.width),
            multiply.product.zeroExtend(accumulate.width));
  }
}
