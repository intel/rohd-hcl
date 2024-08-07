// Copyright (C) 2023 Intel Corporation
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
import 'package:rohd_hcl/src/arithmetic/booth.dart';
import 'package:rohd_hcl/src/arithmetic/compressor.dart';

/// An abstract class for all multiplier implementations.
abstract class Multiplier extends Module {
  /// The input to the multiplier pin [a].
  @protected
  late final Logic a;

  /// The input to the multiplier pin [b].
  @protected
  late final Logic b;

  /// The multiplier treats operands and output as signed
  bool get signed => _signed;

  @protected
  bool _signed = false;

  /// The multiplication results of the multiplier.
  Logic get product;

  /// Take input [a] and input [b] and return the
  /// [product] of the multiplication result.
  Multiplier(Logic a, Logic b, {bool signed = false, super.name}) {
    if (a.width != b.width) {
      throw RohdHclException('inputs of a and b should have same width.');
    }
    _signed = signed;
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
  bool get signed => _signed;

  @protected
  bool _signed = false;

  /// The multiplication results of the multiply-accumulate.
  Logic get accumulate;

  /// Take input [a] and input [b], compute their
  /// product, add input [c] to produce the [accumulate] result.
  MultiplyAccumulate(Logic a, Logic b, Logic c,
      {bool signed = false, super.name}) {
    if (a.width != b.width) {
      throw RohdHclException('inputs of a and b should have same width.');
    }
    _signed = signed;
    this.a = addInput('a', a, width: a.width);
    this.b = addInput('b', b, width: b.width);
    this.c = addInput('c', c, width: c.width);
  }
}

/// An implementation of an integer multiplier using compression trees
class CompressionTreeMultiplier extends Multiplier {
  /// The final product of the multiplier module.
  @override
  Logic get product => output('product');

  /// Construct a compression tree integer multipler with
  ///   a given radix and final adder functor
  CompressionTreeMultiplier(super.a, super.b, int radix,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic)) ppTree,
      {super.signed = false})
      : super(
            name: 'Compression Tree Multiplier: '
                'R${radix}_${ppTree.call([
              Logic()
            ], (a, b) => Logic()).runtimeType}') {
    final product = addOutput('product', width: a.width + b.width);

    final pp =
        PartialProductGenerator(a, b, RadixEncoder(radix), signed: signed);
    // ignore: cascade_invocations
    pp.signExtendCompact();
    final compressor = ColumnCompressor(pp);
    // ignore: cascade_invocations
    compressor.compress();
    final adder = ParallelPrefixAdder(
        compressor.extractRow(0), compressor.extractRow(1), ppTree);
    product <= adder.out.slice(a.width + b.width - 1, 0);
  }
}

/// An implementation of an integer multiply accumulate using compression trees
class CompressionTreeMultiplyAccumulate extends MultiplyAccumulate {
  /// The final product of the multiplier module.
  @override
  Logic get accumulate => output('accumulate');

  /// Construct a compression tree integer multipler with
  ///   a given radix and final adder functor
  CompressionTreeMultiplyAccumulate(super.a, super.b, super.c, int radix,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic)) ppTree,
      {bool signed = false})
      : super(
            name: 'Compression Tree Multiplier: '
                'R${radix}_${ppTree.call([Logic()], (a, b) => Logic()).name}') {
    final accumulate = addOutput('accumulate', width: a.width + b.width + 1);
    _signed = signed;

    final pp =
        PartialProductGenerator(a, b, RadixEncoder(radix), signed: signed);
    // ignore: cascade_invocations
    pp.signExtendCompact();

    // Evaluate works only because the compressed rows have the same shape
    // So the rowshift is valid.
    // But this requires that we prefix the PP with the addend (not add) to
    // keep the evaluate routine working.

    // TODO(desmonddak): This sign extension method for the additional
    //  addend may only work with signExtendCompact.

    final lastLength =
        pp.partialProducts[pp.rows - 1].length + pp.rowShift[pp.rows - 1];

    final sign = signed ? c[c.width - 1] : Const(0);
    final l = [for (var i = 0; i < c.width; i++) c[i]];
    while (l.length < lastLength) {
      l.add(sign);
    }
    l
      ..add(~sign)
      ..add(Const(1));

    pp.partialProducts.insert(0, l);
    pp.rowShift.insert(0, 0);

    // TODO(desmonddak): probably cleaner to add row at end, but
    // compressor fails to properly handle, so we need to debug
    // pp.partialProducts.add(l);
    // pp.rowShift.add(0);
    final compressor = ColumnCompressor(pp);
    // ignore: cascade_invocations
    compressor.compress();

    final adder = ParallelPrefixAdder(
        compressor.extractRow(0), compressor.extractRow(1), ppTree);
    accumulate <= adder.out.slice(a.width + b.width, 0);
  }
}

/// A MultiplyAccumulate which ignores the [c] term and applies the
/// multiplier function
class MultiplyOnly extends MultiplyAccumulate {
  @override
  Logic get accumulate => output('accumulate');

  /// Construct a MultiplyAccumulate that only multiplies to enable
  /// using the same tester with zero addend.
  MultiplyOnly(super.a, super.b, super.c,
      Multiplier Function(Logic a, Logic b) multiplyGenerator)
      : super(name: 'Multiply Only: ${multiplyGenerator.call(a, b).name}') {
    final accumulate = addOutput('accumulate', width: a.width + b.width + 1);

    final multiply = multiplyGenerator(a, b);
    _signed = multiply.signed;

    accumulate <=
        (signed
            ? [multiply.product[multiply.product.width - 1], multiply.product]
                .swizzle()
            : multiply.product.zeroExtend(accumulate.width));
  }
}
