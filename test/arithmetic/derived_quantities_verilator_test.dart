// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// derived_quantities_verilator_test.dart
// One Verilator compilation of the small combinational components whose
// own tests compare ROHD with Icarus Verilog.
//
// 2026 November 25
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

import '../verilator_test_utils.dart';

/// The overflow-detecting adder and multiplier at each of their result
/// widths, [CeilDivide], and [Log2Ceil], on shared operands.
///
/// Compiling a design for Verilator takes some twenty seconds however small
/// it is, so these are compiled together rather than one test each.
class _DerivedQuantities extends Module {
  /// The widths of sum to produce from operands of [width] bits.
  static List<int> sumWidths(int width) => [width, width + 1];

  /// The widths of product to produce from operands of [width] bits.
  static List<int> productWidths(int width) => [width, 2 * width];

  _DerivedQuantities(Logic a, Logic b) : super(name: 'derived_quantities') {
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    for (final width in sumWidths(a.width)) {
      final adder = UnsignedAddWithOverflow(a, b, sumWidth: width);
      addOutput('sum$width', width: width) <= adder.sum;
      addOutput('sumOverflow$width') <= adder.overflow;
    }
    for (final width in productWidths(a.width)) {
      final multiplier = UnsignedMulWithOverflow(a, b, productWidth: width);
      addOutput('product$width', width: width) <= multiplier.product;
      addOutput('productOverflow$width') <= multiplier.overflow;
    }
    addOutput('quotient', width: a.width) <= CeilDivide(a, b).quotient;
    final log = Log2Ceil(a).log;
    addOutput('log', width: log.width) <= log;
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('overflow detection, CeilDivide and Log2Ceil agree in Verilator',
      () async {
    const width = 4;
    final dut = _DerivedQuantities(
        Logic(name: 'a', width: width), Logic(name: 'b', width: width));
    await dut.build();

    // The operands the components' own tests use: zeros, identity, all
    // ones, carry and overflow boundaries, powers of two and their
    // neighbours, and divisors that do and do not leave a remainder.
    const values = [0, 1, 2, 3, 4, 5, 7, 8, 9, 15];
    final vectors = [
      for (final x in values)
        for (final y in values)
          Vector({
            'a': x,
            'b': y
          }, {
            for (final sum in _DerivedQuantities.sumWidths(width)) ...{
              'sum$sum': (x + y) & ((1 << sum) - 1),
              'sumOverflow$sum': (x + y) >> sum == 0 ? 0 : 1,
            },
            for (final product in _DerivedQuantities.productWidths(width)) ...{
              'product$product': (x * y) & ((1 << product) - 1),
              'productOverflow$product': (x * y) >> product == 0 ? 0 : 1,
            },
            // Division by zero is unspecified.
            if (y != 0) 'quotient': (x + y - 1) ~/ y,
            'log': x <= 1 ? 0 : (x - 1).bitLength,
          })
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    checkVerilatorVector(dut, vectors);
  });
}
