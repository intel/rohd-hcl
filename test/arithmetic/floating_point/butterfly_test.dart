// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/floating_point/fft/butterfly.dart';
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

  test('butterfly unit test', () {
    final a = newComplex(1.0, 2.0);
    final b = newComplex(-3.0, -4.0);
    final twiddle = newComplex(1.0, 0.0);

    final butterfly = Butterfly(inA: a, inB: b, twiddleFactor: twiddle);

    expect(butterfly.outA.realPart.floatingPointValue.toDouble(), -2.0);
    expect(butterfly.outA.imaginaryPart.floatingPointValue.toDouble(), -2.0);
    expect(butterfly.outB.realPart.floatingPointValue.toDouble(), 4.0);
    expect(butterfly.outB.imaginaryPart.floatingPointValue.toDouble(), 6.0);
  });
}
