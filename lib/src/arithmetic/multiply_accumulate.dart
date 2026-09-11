// Copyright (C) 2023-2026 Intel Corporation
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

// `GenericMultiplyAccumulate` composes any `Multiplier` generator with an
// `adderGen`. Its flexibility may cost efficiency compared with the fused
// compression tree in `CompressionTreeMultiplyAccumulate`.
//
// `outputWidth` truncates or extends the natural full-precision result.
//
// Wide `c` inputs can lose precision inside `CompressionTreeMultiplyAccumulate`
// beyond the natural result width. `GenericMultiplyAccumulate` supports them
// by extending the product and `c` before its separate addition.

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

  /// [Logic] that tells us [accumulate] is signed.
  @protected
  Logic get isAccumulateSigned => output('isAccumulateSigned');

  /// Take input [a] and input [b], compute their product, add input [c] to
  /// produce the [accumulate] result.
  ///
  /// The optional [signedMultiplicand] parameter configures the The optional
  /// [signedMultiplicand] parameter configures the multiplicand [a] statically
  /// using a `bool` as a signed multiplicand (default is `false`, or unsigned)
  /// or dynamically with a 1-bit [Logic] [selectSignedMultiplicand] input. You
  /// can pass either a `bool` (for static configuration) or a [Logic]
  /// (dynamically configuring the type handled) with a signal to this
  /// parameter, otherwise this constructor will throw.
  ///
  /// The optional [signedMultiplier] parameter configures the multiplier [b]
  /// statically using a `bool` as a signed multiplier (default is `false`, or
  /// unsigned) or dynamically with a 1-bit [Logic] [selectSignedMultiplier]
  /// input. You can pass either a `bool` (for static configuration) or a
  /// [Logic] (dynamically configuring the type handled with a signal) to this
  /// parameter, otherwise this constructor will throw.
  ///
  /// The optional [signedAddend] parameter configures the addend [c] as a
  /// signed addend (default is unsigned) or with a runtime configurable
  /// [selectSignedAddend] input.
  ///
  /// The optional [signedAddend] parameter configures the multiplicand [c]
  /// statically using a `bool` as a signed multiplicand (default is `false`, or
  /// unsigned) or dynamically with a 1-bit [Logic] [selectSignedAddend] input.
  /// You can pass either a `bool`(for static configuration) or a [Logic]
  /// (dynamically configuring the type handled) with a signal to this
  /// parameter, otherwise this constructor will throw.
  ///
  /// The optional [outputWidth] parameter configures the width of
  /// [accumulate]. If not provided, [accumulate] is the natural
  /// full-precision width `a.width + b.width + 1`. If [outputWidth] is
  /// narrower, the natural result is truncated to the low [outputWidth]
  /// bits. If [outputWidth] is wider, the natural result is sign- or
  /// zero-extended based on [isAccumulateSigned].
  MultiplyAccumulate(Logic a, Logic b, Logic c,
      {Logic? clk,
      Logic? reset,
      Logic? enable,
      dynamic signedMultiplicand,
      dynamic signedMultiplier,
      dynamic signedAddend,
      int? outputWidth,
      super.name = 'multiply_accumulate',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'MultiplyAccumulate_W${a.width}x${b.width}_'
                    'Acc${c.width}') {
    if (outputWidth != null && outputWidth <= 0) {
      throw RohdHclException(
          'outputWidth must be positive when provided, got $outputWidth.');
    }

    this.clk = (clk != null) ? addInput('clk', clk) : null;
    this.reset = (reset != null) ? addInput('reset', reset) : null;
    this.enable = (enable != null) ? addInput('enable', enable) : null;
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    c = addInput('c', c, width: c.width);

    signedMultiplicandParameter =
        StaticOrRuntimeParameter.ofDynamic(signedMultiplicand);
    this.signedMultiplicand = signedMultiplicandParameter.staticConfig;
    signedMultiplierParameter =
        StaticOrRuntimeParameter.ofDynamic(signedMultiplier);
    this.signedMultiplier = signedMultiplierParameter.staticConfig;
    signedAddendParameter = StaticOrRuntimeParameter.ofDynamic(signedAddend);
    this.signedAddend = signedAddendParameter.staticConfig;

    addOutput('accumulate', width: outputWidth ?? (a.width + b.width + 1));

    addOutput('isAccumulateSigned') <=
        signedMultiplicandParameter.getLogic(this) |
            signedMultiplierParameter.getLogic(this) |
            signedAddendParameter.getLogic(this);
  }

  /// Reshapes [naturalResult] (the full-precision, natural-width
  /// multiply-accumulate result) to fit this module's [accumulate] output
  /// width.
  ///
  /// If [accumulate] is the same width as [naturalResult], it is returned
  /// unchanged. If [accumulate] is narrower, [naturalResult] is truncated to
  /// the low `accumulate.width` bits. If [accumulate] is wider,
  /// [naturalResult] is sign- or zero-extended based on [signed] (which
  /// defaults to the runtime [isAccumulateSigned] signal).
  @protected
  Logic fitAccumulateWidth(Logic naturalResult, {Logic? signed}) {
    if (accumulate.width == naturalResult.width) {
      return naturalResult;
    }
    if (accumulate.width < naturalResult.width) {
      return naturalResult.slice(accumulate.width - 1, 0);
    }
    return mux(
        signed ?? isAccumulateSigned,
        naturalResult.signExtend(accumulate.width),
        naturalResult.zeroExtend(accumulate.width));
  }

  /// This is a helper function that prints out the kind of addend (selected by
  /// a [Logic] or set statically by a `bool`).) This supplements the
  /// [Multiplier] functions that can be used for multiplicand and multiplier as
  /// they are statics: [Multiplier.signedMD] and [Multiplier.signedML].
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
  ///
  /// The optional [outputWidth] parameter configures the width of
  /// [accumulate], as described in [MultiplyAccumulate].
  CompressionTreeMultiplyAccumulate(super.a, super.b, super.c,
      {int radix = 4,
      Logic? clk,
      Logic? reset,
      Logic? enable,
      super.signedMultiplicand,
      super.signedMultiplier,
      super.signedAddend,
      super.outputWidth,
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
    final ppg = PartialProductGenerator(
      a,
      b,
      RadixEncoder(radix),
      selectSignedMultiplicand: selectSignedMultiplicand,
      signedMultiplicand: signedMultiplicand,
      selectSignedMultiplier: selectSignedMultiplier,
      signedMultiplier: signedMultiplier,
    );

    seGen(ppg).signExtend();

    final lastRowLen =
        ppg.partialProducts[ppg.partialProducts.length - 1].length +
            ppg.rowShift[ppg.partialProducts.length - 1];

    final additionalRowSign = mux(
        (selectSignedAddend != null)
            ? selectSignedAddend!
            : (signedAddend ? Const(1) : Const(0)),
        c[c.width - 1],
        Const(0));

    final additionalRow = [for (var i = 0; i < c.width; i++) c[i]];
    while (additionalRow.length < lastRowLen) {
      additionalRow.add(additionalRowSign);
    }
    additionalRow
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
    accumulate <=
        fitAccumulateWidth(adder.sum.slice(a.width + b.width - 1 + 1, 0));
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
  ///
  /// The optional [outputWidth] parameter configures the width of
  /// [accumulate], as described in [MultiplyAccumulate].
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
    super.outputWidth,
  }) // Will be overrwridden by multiplyGenerator
  : super(
            // ignore: prefer_interpolation_to_compose_strings
            name: 'multiply_only_' +
                _genName(mulGen, a, b, signedMultiplicand, signedMultiplier)) {
    // Copy the configuration using this module's internal runtime input.
    final multiply = mulGen(a, b,
        signedMultiplicand: StaticOrRuntimeParameter(
            name: 'selectSignedMultiplicand',
            runtimeConfig: signedMultiplicandParameter.tryRuntimeInput(this),
            staticConfig: signedMultiplicandParameter.runtimeConfig == null
                ? signedMultiplicandParameter.staticConfig
                : null),
        signedMultiplier: StaticOrRuntimeParameter(
            name: 'selectSignedMultiplier',
            runtimeConfig: signedMultiplierParameter.tryRuntimeInput(this),
            staticConfig: signedMultiplierParameter.runtimeConfig == null
                ? signedMultiplierParameter.staticConfig
                : null));

    accumulate <=
        // ignore: invalid_use_of_protected_member
        fitAccumulateWidth(multiply.product, signed: multiply.isProductSigned);
  }
}

/// A [MultiplyAccumulate] that accepts an arbitrary [Multiplier] generator
/// `mulGen` to compute the product of [a] and [b], then genuinely adds [c]
/// to produce [accumulate] using an [Adder] generator `adderGen` -- the same
/// pluggable-generator convention already used for the final adder inside
/// [CompressionTreeMultiplyAccumulate] and [CompressionTreeMultiplier].
///
/// Unlike [CompressionTreeMultiplyAccumulate] (which fuses multiplication
/// and accumulation into a single compression tree for area/timing
/// efficiency), this class decouples them: it builds whatever [Multiplier]
/// `mulGen` produces (e.g. [NativeMultiplier], a [CompressionTreeMultiplier]
/// with any radix/sign-extension/adder configuration, or a custom
/// [Multiplier] subclass), then adds [c] to the result with a separately
/// generated `adderGen` adder. This trades some efficiency (multiplication
/// and accumulation are no longer fused into one tree) for the flexibility
/// of an arbitrary, pluggable multiplication strategy.
class GenericMultiplyAccumulate extends MultiplyAccumulate {
  /// Construct a [MultiplyAccumulate] that multiplies [a] and [b] using
  /// [mulGen], then adds [c] using [adderGen] to produce [accumulate].
  ///
  /// If [clk] is not null then a flop latches the final sum. [reset] and
  /// [enable] are optional inputs to control that flop when [clk] is
  /// provided.
  ///
  /// The optional [outputWidth] parameter configures the width of
  /// [accumulate], as described in [MultiplyAccumulate].
  GenericMultiplyAccumulate(
    super.a,
    super.b,
    super.c,
    Multiplier Function(Logic a, Logic b,
            {dynamic signedMultiplicand, dynamic signedMultiplier})
        mulGen, {
    Adder Function(Logic a, Logic b, {Logic? carryIn}) adderGen =
        NativeAdder.new,
    super.clk,
    super.reset,
    super.enable,
    super.signedMultiplicand,
    super.signedMultiplier,
    super.signedAddend,
    super.outputWidth,
    super.name = 'generic_multiply_accumulate',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
            definitionName: definitionName ??
                'GenericMultiplyAccumulate_W${a.width}x${b.width}_'
                    'Acc${c.width}') {
    // Copy the configuration using this module's internal runtime input.
    final multiply = mulGen(a, b,
        signedMultiplicand: StaticOrRuntimeParameter(
            name: 'selectSignedMultiplicand',
            runtimeConfig: signedMultiplicandParameter.tryRuntimeInput(this),
            staticConfig: signedMultiplicandParameter.runtimeConfig == null
                ? signedMultiplicandParameter.staticConfig
                : null),
        signedMultiplier: StaticOrRuntimeParameter(
            name: 'selectSignedMultiplier',
            runtimeConfig: signedMultiplierParameter.tryRuntimeInput(this),
            staticConfig: signedMultiplierParameter.runtimeConfig == null
                ? signedMultiplierParameter.staticConfig
                : null));

    final product = multiply.product;
    // ignore: invalid_use_of_protected_member
    final productSigned = multiply.isProductSigned;
    final addendSigned = selectSignedAddend ?? Const(signedAddend ? 1 : 0);

    // Extend both operands to a common width (with one extra bit of
    // headroom so the true mathematical sum can never overflow that width)
    // before adding, using each operand's own sign indicator so unsigned
    // values are zero-extended and signed values are correctly sign-extended.
    final commonWidth = (product.width < c.width ? c.width : product.width) + 1;
    final extendedProduct = mux(productSigned, product.signExtend(commonWidth),
            product.zeroExtend(commonWidth))
        .named('extendedProduct');
    final extendedAddend =
        mux(addendSigned, c.signExtend(commonWidth), c.zeroExtend(commonWidth))
            .named('extendedAddend');

    // [Adder] always appends its own extra output bit for an *unsigned*
    // carry-out. Since [commonWidth] already provides enough headroom that
    // the true sum cannot overflow it, that carry-out is always 0 here, so
    // it's dropped: the low `commonWidth` bits alone are the correct
    // two's-complement (or unsigned) result at that width. This matters
    // because passing the raw, wider `adder.sum` (whose extra top bit is a
    // carry flag, not a sign bit) into `fitAccumulateWidth`'s sign-extension
    // logic would corrupt negative results when widening further.
    final adder = adderGen(extendedProduct, extendedAddend);
    final naturalResult =
        adder.sum.slice(commonWidth - 1, 0).named('naturalResult');
    final rawResult = condFlop(clk, naturalResult, reset: reset, en: enable)
        .named('rawResult');
    final rawIsAccumulateSigned =
        condFlop(clk, isAccumulateSigned, reset: reset, en: enable)
            .named('rawIsAccumulateSigned');

    accumulate <= fitAccumulateWidth(rawResult, signed: rawIsAccumulateSigned);
  }
}
