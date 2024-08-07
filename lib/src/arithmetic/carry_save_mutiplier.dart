// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// carry_save_multiplier.dart
// Implementation of pipeline multiplier module.
//
// 2023 May 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A binary multiplier using carry-save technique with pipelining.
///
/// Reduces calculation time and complexity by employing the carry save
/// multiplier, which splits numbers into smaller components and performs
/// partial multiplications on each component separately, storing the results
/// in a compact form. The pipeline enhances performance by breaking down the
/// multiplication process into sequential stages, allowing for concurrent
/// execution of multiple operations.
///
/// The latency of the carry save multiplier is the sum of the two inputs width
/// `a` and `b`.
class CarrySaveMultiplier extends Multiplier {
  /// The list of the sum from every pipeline stages.
  late final List<Logic> _sum;

  /// The list pf carry from every pipeline stages.
  late final List<Logic> _carry;

  /// The final product of the multiplier module.
  @override
  Logic get product => output('product');

  /// The [latency] of the carry save multiplier.
  int get latency => super.a.width + 1;

  /// The pipeline for [CarrySaveMultiplier].
  late final Pipeline _pipeline;

  /// Construct a [CarrySaveMultiplier] that multiply input [a] and input [b].
  CarrySaveMultiplier(super.a, super.b,
      {required Logic clk,
      required Logic reset,
      super.name = 'carry_save_multiplier'}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    final product = addOutput('product', width: a.width + b.width + 1);

    _sum = List.generate(a.width * 2, (index) => Logic(name: 'sum_$index'));
    _carry = List.generate(a.width * 2, (index) => Logic(name: 'carry_$index'));

    final rCarryA = Logic(name: 'rcarry_a', width: a.width);
    final rCarryB = Logic(name: 'rcarry_b', width: b.width);

    _pipeline = Pipeline(
      clk,
      stages: [
        ...List.generate(
          b.width,
          (row) => (p) {
            final columnAdder = <Conditional>[];
            final maxIndexA = (a.width - 1) + row;

            for (var column = maxIndexA; column >= row; column--) {
              final fullAdder = FullAdder(
                  a: column == maxIndexA || row == 0
                      ? Const(0)
                      : p.get(_sum[column]),
                  b: p.get(a)[column - row] & p.get(b)[row],
                  carryIn: row == 0 ? Const(0) : p.get(_carry[column - 1]));

              columnAdder
                ..add(p.get(_carry[column]) < fullAdder.carryOut)
                ..add(p.get(_sum[column]) < fullAdder.sum);
            }

            return columnAdder;
          },
        ),
        (p) => [
              p.get(rCarryA) <
                  <Logic>[
                    Const(0),
                    ...List.generate(a.width - 1,
                        (index) => p.get(_sum[(a.width + b.width - 2) - index]))
                  ].swizzle(),
              p.get(rCarryB) <
                  <Logic>[
                    ...List.generate(
                        a.width,
                        (index) =>
                            p.get(_carry[(a.width + b.width - 2) - index]))
                  ].swizzle()
            ],
      ],
      reset: reset,
      resetValues: {product: Const(0)},
    );

    final nBitAdder = RippleCarryAdder(
      _pipeline.get(rCarryA),
      _pipeline.get(rCarryB),
    );

    product <=
        <Logic>[
          ...List.generate(
            a.width + 1,
            (index) => nBitAdder.sum[(a.width) - index],
          ),
          ...List.generate(
            a.width,
            (index) => _pipeline.get(_sum[a.width - index - 1]),
          )
        ].swizzle();
  }
}
