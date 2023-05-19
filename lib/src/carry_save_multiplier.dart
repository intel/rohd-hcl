// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// carry_save_multiplier.dart
// Implementation of pipeline multiplier module.
//
// 2023 May 19
// Author: Yao Jing Quek <yao.jing.quek@intel.com>
//

import 'package:rohd/rohd.dart';

/// A simple full-adder with inputs `a` and `b` to be added with a `carryIn`.
class FullAdder extends Module {
  /// The result [sum] from [FullAdder].
  Logic get sum => output('sum');

  /// The result [cOut] from [FullAdder].
  Logic get cOut => output('carry_out');

  /// Constructs a [FullAdder] with value [a], [b] and [carryIn].
  FullAdder({
    required Logic a,
    required Logic b,
    required Logic carryIn,
    super.name = 'full_adder',
  }) {
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    carryIn = addInput('carry_in', carryIn, width: carryIn.width);

    final carryOut = addOutput('carry_out');
    final sum = addOutput('sum');

    final and1 = carryIn & (a ^ b);
    final and2 = b & a;

    sum <= (a ^ b) ^ carryIn;
    carryOut <= and1 | and2;
  }
}

/// An [RippleCarryAdder] that perform addition.
class RippleCarryAdder extends Module {
  /// The List of results returned from the [FullAdder].
  final _sum = <Logic>[];

  /// The final result of the NBitAdder.
  LogicValue get sumRes => _sum.rswizzle().value;

  /// Constructs an n-bit adder based on inputs [a] and [b].
  RippleCarryAdder(Logic a, Logic b) : super(name: 'ripple_carry_adder') {
    Logic carry = Const(0);

    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    carry = addInput('carry_in', carry, width: carry.width);

    final n = a.width;
    FullAdder? res;

    assert(a.width == b.width, 'a and b should have same width.');

    for (var i = 0; i < n; i++) {
      res = FullAdder(a: a[i], b: b[i], carryIn: carry);

      carry = res.cOut;
      _sum.add(res.sum);
    }

    _sum.add(carry);
  }
}

/// A multiplier module that are able to get the product of two values.
class CarrySaveMultiplier extends Module {
  /// The list of the sum from every pipeline stages.
  final List<Logic> _sum =
      List.generate(8, (index) => Logic(name: 'sum_$index'));

  /// The list pf carry from every pipeline stages.
  final List<Logic> _carry =
      List.generate(8, (index) => Logic(name: 'carry_$index'));

  /// The final product of the multiplier module.
  Logic get product => output('product');

  /// The pipeline for [CarrySaveMultiplier].
  late final Pipeline pipeline;

  /// Construct a [CarrySaveMultiplier] that multiply [a] and
  /// [b].
  CarrySaveMultiplier(Logic a, Logic b, Logic clk, Logic reset,
      {super.name = 'carry_save_multiplier'}) {
    // Declare Input Node
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    final product = addOutput('product', width: a.width + b.width + 1);

    final rCarryA = Logic(name: 'rcarry_a', width: a.width);
    final rCarryB = Logic(name: 'rcarry_b', width: b.width);

    pipeline = Pipeline(
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
                ..add(p.get(_carry[column]) < fullAdder.cOut)
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
      pipeline.get(rCarryA),
      pipeline.get(rCarryB),
    );

    product <=
        <Logic>[
          ...List.generate(
            a.width + 1,
            (index) => nBitAdder._sum[(a.width) - index],
          ),
          ...List.generate(
            a.width,
            (index) => pipeline.get(_sum[a.width - index - 1]),
          )
        ].swizzle();
  }
}
