// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/signals/floating_point_logics/complex_floating_point_logic.dart';
import 'package:test/test.dart';

ComplexFloatingPoint newComplex(double real, double imaginary) {
  final realFP = FloatingPoint64();
  final imaginaryFP = FloatingPoint64();

  final realFPValue = FloatingPoint64Value.populator().ofDouble(real);
  final imaginaryFPValue = FloatingPoint64Value.populator().ofDouble(imaginary);

  realFP.put(realFPValue);
  imaginaryFP.put(imaginaryFPValue);

  final complex = ComplexFloatingPoint(
      exponentWidth: realFP.exponent.width,
      mantissaWidth: realFP.mantissa.width);
  complex.realPart <= realFP;
  complex.imaginaryPart <= imaginaryFP;

  return complex;
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('complex constructor', () {
    final complex = newComplex(1.23, 3.45);

    expect(complex.realPart.floatingPointValue.toDouble(), 1.23);
    expect(complex.imaginaryPart.floatingPointValue.toDouble(), 3.45);
  });

  test('complex addition', () {
    final a = newComplex(1, 0);
    final b = newComplex(0, -1);
    final c = a.adder(b);

    expect(c.realPart.floatingPointValue.toDouble(), 1.0);
    expect(b.imaginaryPart.floatingPointValue.toDouble(), -1.0);
  });

  test('complex multiplication', () {
    final a = newComplex(1, 2);
    final b = newComplex(-3, -4);
    final c = a.multiplier(b);

    expect(c.realPart.floatingPointValue.toDouble(), 5.0);
    expect(c.imaginaryPart.floatingPointValue.toDouble(), -10.0);
  });
}
