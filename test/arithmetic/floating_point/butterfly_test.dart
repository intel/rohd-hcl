// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:math';

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

  Complex add(Complex other) {
    return Complex(
      real: this.real + other.real,
      imaginary: this.imaginary + other.imaginary,
    );
  }

  Complex subtract(Complex other) {
    return Complex(
      real: this.real - other.real,
      imaginary: this.imaginary - other.imaginary,
    );
  }

  Complex multiply(Complex other) {
    return Complex(
      real: (this.real * other.real) - (this.imaginary * other.imaginary),
      imaginary: (this.real * other.imaginary) + (this.imaginary * other.real),
    );
  }

  @override
  String toString() {
    return '${real}${imaginary >= 0 ? '+' : ''}${imaginary}i';
  }
}

List<Complex> butterfly(Complex inA, Complex inB, Complex twiddleFactor) {
  final temp = twiddleFactor.multiply(inB);
  return [inA.subtract(temp), inA.add(temp)];
}

final epsilon = 1e-15;

void compareDouble(double actual, double expected) {
  assert(
    (actual - expected).abs() < epsilon,
    "actual ${actual}, expected ${expected}",
  );
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('butterfly unit test', () {
    final random = Random();
    for (var i = 0; i < 5; i++) {
      final a = Complex(
        real: random.nextDouble(),
        imaginary: random.nextDouble(),
      );
      final b = Complex(
        real: random.nextDouble(),
        imaginary: random.nextDouble(),
      );
      final twiddle = Complex(
        real: random.nextDouble(),
        imaginary: random.nextDouble(),
      );

      final aLogic = newComplex(a.real, a.imaginary);
      final bLogic = newComplex(b.real, b.imaginary);
      final twiddleLogic = newComplex(twiddle.real, twiddle.imaginary);

      final expected = butterfly(a, b, twiddle);

      final butterflyModule = Butterfly(
        inA: aLogic,
        inB: bLogic,
        twiddleFactor: twiddleLogic,
      );

      compareDouble(
        butterflyModule.outA.realPart.floatingPointValue.toDouble(),
        expected[0].real,
      );
      compareDouble(
        butterflyModule.outA.imaginaryPart.floatingPointValue.toDouble(),
        expected[0].imaginary,
      );
      compareDouble(
        butterflyModule.outB.realPart.floatingPointValue.toDouble(),
        expected[1].real,
      );
      compareDouble(
        butterflyModule.outB.imaginaryPart.floatingPointValue.toDouble(),
        expected[1].imaginary,
      );
    }
  });
}
