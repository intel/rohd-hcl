// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/signals/complex_fixed_point_logic.dart';
import 'package:rohd_hcl/src/arithmetic/values/complex_fixed_point_value.dart';
import 'package:test/test.dart';

// void checkAdder(Adder adder, LogicValue av, LogicValue bv, LogicValue cv) {
//   final aB = av.toBigInt();
//   final bB = bv.toBigInt();
//   final cB = cv.toBigInt();
//   adder.a.put(av);
//   adder.b.put(bv);
//   final BigInt golden;
//   if (adder.hasCarryIn) {
//     adder.carryIn!.put(cv);
//     golden = aB + bB + cB;
//   } else {
//     golden = aB + bB;
//   }
//   expect(adder.sum.value.toBigInt(), equals(golden));
// }
//
// void testAdderRandomIter(int n, int nSamples, Adder adder) {
//   test('random ci: ${adder.name}_W${n}_I$nSamples', () async {
//     for (var i = 0; i < nSamples; i++) {
//       final aa = Random().nextLogicValue(width: n);
//       final bb = Random().nextLogicValue(width: n);
//       final cc = Random().nextLogicValue(width: 1);
//       checkAdder(adder, aa, bb, cc);
//     }
//   });
// }
//
// void testAdderExhaustiveIter(int n, Adder mod) {
//   test(
//       'exhaustive cin: ${mod.name}_W$n'
//       '_G${mod.name}', () async {
//     for (var aa = 0; aa < (1 << n); aa++) {
//       for (var bb = 0; bb < (1 << n); bb++) {
//         for (var cc = 0; cc < 2; cc++) {
//           final av = LogicValue.of(BigInt.from(aa), width: n);
//           final bv = LogicValue.of(BigInt.from(bb), width: n);
//           final cv = Random().nextLogicValue(width: 1);
//
//           checkAdder(mod, av, bv, cv);
//         }
//       }
//     }
//   });
// }
//
// void testAdderRandom(
//     int n, int nSamples, Adder Function(Logic a, Logic b, {Logic? carryIn}) fn,
//     {bool testCarryIn = true}) {
//   testAdderRandomIter(
//       n,
//       nSamples,
//       fn(Logic(name: 'a', width: n), Logic(name: 'b', width: n),
//           carryIn: testCarryIn ? Logic(name: 'c') : null));
// }
//
// void testAdderExhaustive(
//     int n, Adder Function(Logic a, Logic b, {Logic? carryIn}) fn,
//     {bool testCarryIn = true}) {
//   testAdderExhaustiveIter(
//       n,
//       fn(Logic(name: 'a', width: n), Logic(name: 'b', width: n),
//           carryIn: testCarryIn ? Logic(name: 'c') : null));
// }

void checkMultiply(int integerBits, int fractionalBits, double a, double b,
    double c, double d) {
  final aFixedPointValue = FixedPointValue.ofDouble(a,
      signed: true, m: integerBits, n: fractionalBits);
  final bFixedPointValue = FixedPointValue.ofDouble(b,
      signed: true, m: integerBits, n: fractionalBits);
  final cFixedPointValue = FixedPointValue.ofDouble(c,
      signed: true, m: integerBits, n: fractionalBits);
  final dFixedPointValue = FixedPointValue.ofDouble(d,
      signed: true, m: integerBits, n: fractionalBits);

  final ab = ComplexFixedPoint(
      signed: true, integerBits: integerBits, fractionalBits: fractionalBits);
  final cd = ComplexFixedPoint(
      signed: true, integerBits: integerBits, fractionalBits: fractionalBits);

  ab.put(ComplexFixedPointValue(
      realPart: aFixedPointValue, imaginaryPart: bFixedPointValue));
  cd.put(ComplexFixedPointValue(
      realPart: cFixedPointValue, imaginaryPart: dFixedPointValue));

  final result = ComplexFixedPoint.of(ab * cd,
      signed: true, integerBits: integerBits, fractionalBits: fractionalBits);

  final resultRealPart = result.realPart().fixedPointValue.toDouble();
  final resultImaginaryPart = result.imaginaryPart().fixedPointValue.toDouble();

  expect(5.0, resultRealPart);
  expect(-10.0, resultImaginaryPart);
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('singleton', () {
    checkMultiply(8, 8, 1.0, 2.0, -3.0, -4.0);
  });
}
