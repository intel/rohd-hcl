// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// finite_field_test.dart
// Finite-field module integration tests.
//
// 2026 November 14
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

int _multiply(int a, int b, int modulus) {
  var product = 0;
  for (var bit = 0; bit < 3; bit++) {
    if ((b & (1 << bit)) != 0) {
      product ^= a << bit;
    }
  }
  for (var bit = 4; bit >= 3; bit--) {
    if ((product & (1 << bit)) != 0) {
      product ^= modulus << (bit - 3);
    }
  }
  return product;
}

class _FieldHarness extends Module {
  _FieldHarness() {
    final input = addInput('data', Logic(width: 3), width: 3);
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    final firstProduct = GfConstantMultiplier(
      input,
      field: first,
      constant: first.elementFromInt(4),
    );
    final secondProduct = GfConstantMultiplier(
      input,
      field: second,
      constant: second.elementFromInt(4),
    );
    final inverse = GfInverse(input, field: first);
    final polynomial = GfPolynomialEvaluator(
      input,
      field: first,
      coefficients: [
        first.elementFromInt(2),
        first.elementFromInt(3),
        first.one,
      ],
    );
    addOutput('first', width: 3) <= firstProduct.result;
    addOutput('second', width: 3) <= secondProduct.result;
    addOutput('inverse', width: 3) <= inverse.result;
    addOutput('polynomial', width: 3) <= polynomial.result;
  }
}

void main() {
  tearDown(Simulator.reset);

  test('field modules compose and match independent arithmetic', () async {
    final dut = _FieldHarness();
    await dut.build();
    final vectors = [
      for (var input = 0; input < 8; input++)
        Vector({
          'data': input
        }, {
          'first': _multiply(input, 4, 11),
          'second': _multiply(input, 4, 13),
          'inverse': input == 0
              ? 0
              : List.generate(7, (i) => i + 1)
                  .firstWhere((value) => _multiply(input, value, 11) == 1),
          'polynomial': _multiply(_multiply(2, input, 11) ^ 3, input, 11) ^ 1,
        }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });
}
