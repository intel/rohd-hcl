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

// Exercise the deprecated bit-vector compatibility APIs.
// ignore_for_file: deprecated_member_use_from_same_package

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
    final firstInput = GfLogic.of(input, field: first);
    final secondInput = GfLogic.of(input, field: second);
    final firstProduct = GfConstantMultiplier.typed(
      firstInput,
      constant: first.elementFromInt(4),
    );
    final secondProduct = GfConstantMultiplier.typed(
      secondInput,
      constant: second.elementFromInt(4),
    );
    final inverse = GfInverse.typed(firstInput);
    final polynomial = GfPolynomialEvaluator.typed(
      firstInput,
      coefficients: [
        first.elementFromInt(2),
        first.elementFromInt(3),
        first.one,
      ],
    );
    addOutput('first', width: 3) <= firstProduct.gfResult;
    addOutput('second', width: 3) <= secondProduct.gfResult;
    addOutput('inverse', width: 3) <= inverse.gfResult;
    addOutput('polynomial', width: 3) <= polynomial.gfResult;
    addOutput('typed', width: 3) <=
        firstProduct.gfResult + inverse.gfResult + polynomial.gfResult;
    addOutput('plain_plus_one', width: 3) <=
        firstProduct.result + Const(1, width: 3);
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
          'typed': _multiply(input, 4, 11) ^
              (input == 0
                  ? 0
                  : List.generate(7, (i) => i + 1).firstWhere(
                      (value) => _multiply(input, value, 11) == 1)) ^
              (_multiply(_multiply(2, input, 11) ^ 3, input, 11) ^ 1),
          'plain_plus_one': (_multiply(input, 4, 11) + 1) & 7,
        }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('field-typed results reject different fields', () {
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    final a = GfInverse.typed(GfLogic(first));
    final b = GfInverse.typed(GfLogic(second));
    expect(a.result, isNot(isA<GfLogic>()));
    expect(a.input('dataIn'), isA<GfLogic>());
    expect(a.gfResult, same(a.output('result')));
    expect(a.gfResult.field, first);
    expect(() => a.gfResult + b.gfResult, throwsA(isA<RohdHclException>()));
  });

  test('legacy field constructors retain plain results', () async {
    final field =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final inverse = GfInverse(Logic(width: 3), field: field);
    final multiplier = GfConstantMultiplier(Logic(width: 3),
        field: field, constant: field.elementFromInt(4));
    final polynomial = GfPolynomialEvaluator(Logic(width: 3),
        field: field, coefficients: [field.one, field.one]);
    expect(inverse.result, isNot(isA<GfLogic>()));
    expect(multiplier.result, isNot(isA<GfLogic>()));
    expect(polynomial.result, isNot(isA<GfLogic>()));
    expect(inverse.result, same(inverse.output('result')));
    expect(multiplier.result, same(multiplier.output('result')));
    expect(polynomial.result, same(polynomial.output('result')));
    expect(inverse.input('dataIn'), isNot(isA<GfLogic>()));
    for (final (module, expected) in [
      (inverse, 5),
      (multiplier, 3),
      (polynomial, 3),
    ]) {
      await module.build();
      await SimCompare.checkFunctionalVector(module, [
        Vector({'dataIn': 2}, {'result': expected}),
      ]);
      await Simulator.reset();
    }
  });
}
