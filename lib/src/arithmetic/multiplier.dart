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
import 'package:rohd_hcl/src/arithmetic/multiplier_components/partial_product_sign_extend.dart';

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

  /// The multiplication result [product].
  Logic get product => output('product');

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
      super.name = 'multiplier',
      String? definitionName})
      : super(
            definitionName:
                definitionName ?? 'Multiplier_W${a.width}x${b.width}') {
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
    // Should be done in base TODO(desmonddak):
    addOutput('product', width: a.width + b.width);

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
  /// The width of input [a] and [b] must be the same.
  NativeMultiplier(super.a, super.b,
      {super.clk,
      super.reset,
      super.enable,
      super.signedMultiplicand = false,
      super.signedMultiplier = false,
      super.selectSignedMultiplicand,
      super.selectSignedMultiplier,
      super.name = 'native_multiplier'})
      : super(definitionName: 'NativeMultiplier_W${a.width}') {
    if (a.width != b.width) {
      throw RohdHclException('inputs of a and b should have same width.');
    }
    final pW = a.width + b.width;

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

/// An implementation of an integer multiplier using compression trees.
class CompressionTreeMultiplier extends Multiplier {
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
      super.name = 'compression_tree_multiplier'})
      : super(
            definitionName: 'CompressionTreeMultiplier_W${a.width}x'
                '${b.width}_'
                '${signedMultiplicand ? 'SD_' : ''}'
                '${signedMultiplier ? 'SM_' : ''}'
                '${selectSignedMultiplicand != null ? 'SSD_' : ''}'
                '${selectSignedMultiplier != null ? 'SSM_' : ''}'
                'with${adderGen(a, b).definitionName}') {
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

    pp.generateOutputs();

    final compressor = ColumnCompressorModule(pp.rows, pp.rowShift,
        clk: clk, reset: reset, enable: enable)
      ..compress();
    final adder = adderGen(compressor.add0, compressor.add1);
    product <= adder.sum.slice(a.width + b.width - 1, 0);
  }
}
