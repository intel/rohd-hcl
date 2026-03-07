// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/floating_point/fft/butterfly.dart';
import 'package:test/test.dart';
import 'fft_utils.dart';

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
