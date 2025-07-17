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

  /// Configuration for signed multiplicand [a].
  @protected
  late final StaticOrDynamicParameter signedMultiplicandParameter;

  /// Configuration for signed multiplier [b].
  @protected
  late final StaticOrDynamicParameter signedMultiplierParameter;

  /// [Logic] that tells us [product] is signed.
  @protected
  Logic get isProductSigned => output('isProductSigned');

  /// Take input [a] and input [b] and return the [product] of the
  /// multiplication result.
  ///
  /// The optional [signedMultiplicand] parameter configures the multiplicand
  /// [a] statically using a bool to indicate a signed multiplicand (default is
  /// false, or unsigned) or dynamically with a 1-bit [Logic] input. Passing
  /// something other null, bool, or [Logic] will result in a throw.
  ///
  ///
  /// The optional [signedMultiplier] parameter configures the multiplier [b]
  /// statically using a bool to indicate a signed multiplier (default is false,
  /// or unsigned) or dynamically with a 1-bit [Logic] input.  Passing
  /// something other null, bool, or [Logic] will result in a throw.
  ///
  /// If [clk] is not null then a set of flops are used to make the multiply a
  /// 2-cycle latency operation. [reset] and [enable] are optional inputs to
  /// control these flops when [clk] is provided.
  Multiplier(Logic a, Logic b,
      {Logic? clk,
      Logic? reset,
      Logic? enable,
      dynamic signedMultiplicand,
      dynamic signedMultiplier,
      super.name = 'multiplier',
      String? definitionName})
      : super(
            definitionName: definitionName ??
                '${b.width}_$signedMD(signedMultiplicand)}_'
                    '$signedML(signedMultiplier)}') {
    this.clk = (clk != null) ? addInput('clk', clk) : null;
    this.reset = (reset != null) ? addInput('reset', reset) : null;
    this.enable = (enable != null) ? addInput('enable', enable) : null;
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);

    // We clone parameters in case they contain [Logic] signals that must be
    // added as inputs to the current module.
    signedMultiplicandParameter =
        StaticOrDynamicParameter.ofDynamic(signedMultiplicand).clone(this);
    signedMultiplierParameter =
        StaticOrDynamicParameter.ofDynamic(signedMultiplier).clone(this);

    addOutput('product', width: a.width + b.width);
    addOutput('isProductSigned') <=
        signedMultiplicandParameter.getLogic(this) |
            signedMultiplierParameter.getLogic(this);
  }

  /// This is a helper function that prints out the kind of multiplicand
  /// (selected by a [Logic] or set statically via [bool]).
  /// - UD: unsigned multiplicand.
  /// - SD: signed multiplicand.
  /// - SSD: dynamic selection of signed multiplicand.
  static String signedMD(dynamic mdConfig) =>
      ((mdConfig is! StaticOrDynamicParameter) | (mdConfig == null))
          ? 'UD'
          : ((mdConfig as StaticOrDynamicParameter).dynamicConfig != null)
              ? 'SSD'
              : mdConfig.staticConfig
                  ? 'SD'
                  : 'UD';

  /// This is a helper function that prints out the kind of multiplier (selected
  /// by a [Logic] or set statically via [bool]).)
  /// - UM: unsigned multiplier.
  /// - SM: signed multiplier.
  /// - SSM: dynamic selection of signed multiplier.
  static String signedML(dynamic mlConfig) =>
      ((mlConfig is! StaticOrDynamicParameter) | (mlConfig == null))
          ? 'UM'
          : (mlConfig as StaticOrDynamicParameter).dynamicConfig != null
              ? 'SSM'
              : mlConfig.staticConfig
                  ? 'SM'
                  : 'UM';
}

/// A class which wraps the native '*' operator so that it support our
/// [Multiplier] interface. This is useful for passing the native multiplier
/// into other modules as a parameter for using the native operation.
class NativeMultiplier extends Multiplier {
  /// The width of input [a] and [b] must be the same.
  NativeMultiplier(super.a, super.b,
      {super.clk,
      super.reset,
      super.enable,
      super.signedMultiplicand,
      super.signedMultiplier,
      super.name = 'native_multiplier'})
      : super(
            definitionName: 'NativeMultiplier_W${a.width}x'
                '${b.width}_${Multiplier.signedMD(signedMultiplicand)}_'
                '${Multiplier.signedML(signedMultiplier)}') {
    if (a.width != b.width) {
      throw RohdHclException('inputs of a and b should have same width.');
    }
    final pW = a.width + b.width;

    final Logic extendedMultiplicand;
    final Logic extendedMultiplier;
    if (signedMultiplicandParameter.dynamicConfig == null) {
      extendedMultiplicand = signedMultiplicandParameter.staticConfig
          ? a.signExtend(pW)
          : a.zeroExtend(pW);
    } else {
      final len = a.width;
      final sign = a[len - 1];
      final extension = [
        for (var i = len; i < pW; i++)
          mux(signedMultiplicandParameter.dynamicConfig!, sign, Const(0))
      ];
      extendedMultiplicand = (a.elements + extension).rswizzle();
    }
    if (signedMultiplierParameter.dynamicConfig == null) {
      extendedMultiplier = (signedMultiplierParameter.staticConfig
              ? b.signExtend(pW)
              : b.zeroExtend(pW))
          .named('extended_multiplier', naming: Naming.mergeable);
    } else {
      final len = b.width;
      final sign = b[len - 1];
      final extension = [
        for (var i = len; i < pW; i++)
          mux(signedMultiplierParameter.dynamicConfig!, sign, Const(0))
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
  /// supplied via [signExtensionGen].
  ///
  /// If [clk] is not null then a set of flops are used to latch the output
  /// after compression.  [reset] and [enable] are optional
  /// inputs to control these flops when [clk] is provided. If [clk] is null,
  /// the Column Compressor is built as a combinational tree of compressors.
  CompressionTreeMultiplier(super.a, super.b,
      {int radix = 4,
      super.clk,
      super.reset,
      super.enable,
      super.signedMultiplicand,
      super.signedMultiplier,
      Adder Function(Logic a, Logic b, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      PartialProductSignExtension Function(PartialProductGeneratorBase pp,
              {String name})
          signExtensionGen = CompactRectSignExtension.new,
      super.name = 'compression_tree_multiplier'})
      : super(
            definitionName: 'CompressionTreeMultiplier_W${a.width}x'
                '${b.width}_${Multiplier.signedMD(signedMultiplicand)}_'
                '${Multiplier.signedML(signedMultiplier)}_'
                'with${adderGen(a, a).definitionName}') {
    final pp = PartialProduct(a, b, RadixEncoder(radix),
        signedMultiplicand: signedMultiplicandParameter,
        signedMultiplier: signedMultiplierParameter,
        name: 'comp_partial_product');

    signExtensionGen(pp.array).signExtend();

    pp.generateOutputs();

    final compressor = ColumnCompressor(pp.rows, pp.rowShift,
        clk: clk, reset: reset, enable: enable);
    final adder = adderGen(compressor.add0, compressor.add1);
    product <= adder.sum.slice(a.width + b.width - 1, 0);
  }
}
