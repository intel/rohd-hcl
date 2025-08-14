// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/signals/floating_point_logics/complex_floating_point_logic.dart';

ComplexFloatingPoint newComplex(double real, double imaginary) {
  final realFP = FloatingPoint64();
  final imaginaryFP = FloatingPoint64();

  final realFPValue = FloatingPoint64Value.populator().ofDouble(real);
  final imaginaryFPValue = FloatingPoint64Value.populator().ofDouble(imaginary);

  realFP.put(realFPValue);
  imaginaryFP.put(imaginaryFPValue);

  final complex = ComplexFloatingPoint(
    exponentWidth: realFP.exponent.width,
    mantissaWidth: realFP.mantissa.width,
  );
  complex.realPart <= realFP;
  complex.imaginaryPart <= imaginaryFP;

  return complex;
}

class Complex {
  double real;
  double imaginary;

  Complex({required this.real, required this.imaginary});

  Complex add(Complex other) => Complex(
      real: real + other.real,
      imaginary: imaginary + other.imaginary,
    );

  Complex subtract(Complex other) => Complex(
      real: real - other.real,
      imaginary: imaginary - other.imaginary,
    );

  Complex multiply(Complex other) => Complex(
      real: (real * other.real) - (imaginary * other.imaginary),
      imaginary: (real * other.imaginary) + (imaginary * other.real),
    );

  @override
  String toString() => '$real${imaginary >= 0 ? '+' : ''}${imaginary}i';
}

List<Complex> butterfly(Complex inA, Complex inB, Complex twiddleFactor) {
  final temp = twiddleFactor.multiply(inB);
  return [inA.subtract(temp), inA.add(temp)];
}

const epsilon = 1e-15;

void compareDouble(double actual, double expected) {
  assert(
    (actual - expected).abs() < epsilon,
    'actual $actual, expected $expected',
  );
}
