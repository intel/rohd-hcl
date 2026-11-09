// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// static_or_runtime_parameter_test.dart
// Tests for naming of runtime configuration parameters
//
// 2026 September 21
// Author: Shubham Padkonde <shubhampadkonde12@gmail.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  group('unnamed runtime parameters get distinct input names', () {
    test('on a CompressionTreeMultiplier', () async {
      final mod = CompressionTreeMultiplier(Logic(width: 8), Logic(width: 8),
          signedMultiplicand: StaticOrRuntimeParameter.fromLogic(Logic(),
              fallbackName: 'signedMultiplicand'),
          signedMultiplier: StaticOrRuntimeParameter.fromLogic(Logic(),
              fallbackName: 'signedMultiplier'));
      await mod.build();

      expect(mod.inputs.keys,
          containsAll(['signedMultiplicand', 'signedMultiplier']));
    });

    test('on a MultiplyAccumulate', () async {
      final mod = CompressionTreeMultiplyAccumulate(
          Logic(width: 8), Logic(width: 8), Logic(width: 8),
          signedMultiplicand: StaticOrRuntimeParameter.fromLogic(Logic(),
              fallbackName: 'signedMultiplicand'),
          signedMultiplier: StaticOrRuntimeParameter.fromLogic(Logic(),
              fallbackName: 'signedMultiplier'),
          signedAddend: StaticOrRuntimeParameter.fromLogic(Logic(),
              fallbackName: 'signedAddend'));
      await mod.build();

      expect(
          mod.inputs.keys,
          containsAll(
              ['signedMultiplicand', 'signedMultiplier', 'signedAddend']));
    });
  });

  test('a named runtime parameter keeps its own name', () async {
    final mod = CompressionTreeMultiplier(Logic(width: 8), Logic(width: 8),
        signedMultiplicand: StaticOrRuntimeParameter.fromLogic(
            Logic(name: 'isSignedA'),
            fallbackName: 'signedMultiplicand'),
        signedMultiplier: StaticOrRuntimeParameter.fromLogic(
            Logic(name: 'isSignedB'),
            fallbackName: 'signedMultiplier'));
    await mod.build();

    expect(mod.inputs.keys, containsAll(['isSignedA', 'isSignedB']));
    expect(mod.inputs.keys, isNot(contains('signedMultiplicand')));
  });

  test('unnamed multiplier controls change independently', () async {
    final a = Logic(width: 3)..put(7);
    final b = Logic(width: 3)..put(6);
    final signedA = Logic();
    final signedB = Logic();
    final multiplier = CompressionTreeMultiplier(a, b,
        signedMultiplicand: StaticOrRuntimeParameter.fromLogic(signedA,
            fallbackName: 'signedMultiplicand'),
        signedMultiplier: StaticOrRuntimeParameter.fromLogic(signedB,
            fallbackName: 'signedMultiplier'));
    await multiplier.build();

    for (final signA in [false, true]) {
      for (final signB in [false, true]) {
        signedA.put(signA ? 1 : 0);
        signedB.put(signB ? 1 : 0);
        final expected = BigInt.from(7).toCondSigned(3, signed: signA) *
            BigInt.from(6).toCondSigned(3, signed: signB);
        expect(multiplier.product.value.toBigInt(),
            expected.toUnsigned(multiplier.product.width),
            reason: 'signedA=$signA signedB=$signB');
      }
    }
  });

  test('unnamed MAC controls change independently', () async {
    final a = Logic(width: 3)..put(7);
    final b = Logic(width: 3)..put(6);
    final c = Logic(width: 6)..put(63);
    final signedA = Logic();
    final signedB = Logic();
    final signedC = Logic();
    final mac = CompressionTreeMultiplyAccumulate(a, b, c,
        signedMultiplicand: StaticOrRuntimeParameter.fromLogic(signedA,
            fallbackName: 'signedMultiplicand'),
        signedMultiplier: StaticOrRuntimeParameter.fromLogic(signedB,
            fallbackName: 'signedMultiplier'),
        signedAddend: StaticOrRuntimeParameter.fromLogic(signedC,
            fallbackName: 'signedAddend'));
    await mac.build();

    for (final signA in [false, true]) {
      for (final signB in [false, true]) {
        for (final signC in [false, true]) {
          signedA.put(signA ? 1 : 0);
          signedB.put(signB ? 1 : 0);
          signedC.put(signC ? 1 : 0);
          final expected = BigInt.from(7).toCondSigned(3, signed: signA) *
                  BigInt.from(6).toCondSigned(3, signed: signB) +
              BigInt.from(63).toCondSigned(6, signed: signC);
          expect(mac.accumulate.value.toBigInt(),
              expected.toUnsigned(mac.accumulate.width),
              reason: 'signedA=$signA signedB=$signB signedC=$signC');
        }
      }
    }
  });

  test('one signal can configure both multiplier operands', () async {
    final a = Logic(width: 3)..put(7);
    final b = Logic(width: 3)..put(6);
    final signed = Logic(name: 'sharedSigned');
    final multiplier = CompressionTreeMultiplier(a, b,
        signedMultiplicand: StaticOrRuntimeParameter.fromLogic(signed,
            fallbackName: 'signedMultiplicand'),
        signedMultiplier: StaticOrRuntimeParameter.fromLogic(signed,
            fallbackName: 'signedMultiplier'));
    await multiplier.build();

    signed.put(0);
    expect(multiplier.product.value.toBigInt(), BigInt.from(42));
    signed.put(1);
    expect(multiplier.product.value.toBigInt(), BigInt.from(2));
  });

  test('one signal can configure all MAC operands', () async {
    final a = Logic(width: 3)..put(7);
    final b = Logic(width: 3)..put(6);
    final c = Logic(width: 6)..put(63);
    final signed = Logic(name: 'sharedSigned');
    final mac = CompressionTreeMultiplyAccumulate(a, b, c,
        signedMultiplicand: StaticOrRuntimeParameter.fromLogic(signed,
            fallbackName: 'signedMultiplicand'),
        signedMultiplier: StaticOrRuntimeParameter.fromLogic(signed,
            fallbackName: 'signedMultiplier'),
        signedAddend: StaticOrRuntimeParameter.fromLogic(signed,
            fallbackName: 'signedAddend'));
    await mac.build();

    signed.put(0);
    expect(mac.accumulate.value.toBigInt(), BigInt.from(105));
    signed.put(1);
    expect(mac.accumulate.value.toBigInt(), BigInt.one);
  });

  test('distinct runtime controls cannot silently share an input name', () {
    final signedA = Logic(name: 'operandSigned');
    final signedB = Logic(name: 'operandSigned');
    expect(
        () => CompressionTreeMultiplyAccumulate(
            Logic(width: 3), Logic(width: 3), Logic(width: 6),
            signedMultiplicand: StaticOrRuntimeParameter.fromLogic(signedA,
                fallbackName: 'signedMultiplicand'),
            signedMultiplier: StaticOrRuntimeParameter.fromLogic(signedB,
                fallbackName: 'signedMultiplier')),
        throwsA(isA<RohdHclException>().having(
            (error) => error.message, 'message', contains('operandSigned'))));
  });

  test('a runtime control cannot silently reuse a data input name', () {
    expect(
        () => NativeMultiplier(Logic(width: 3), Logic(width: 3),
            signedMultiplicand: StaticOrRuntimeParameter.fromLogic(
                Logic(name: 'a'),
                fallbackName: 'signedMultiplicand')),
        throwsA(isA<RohdHclException>()
            .having((error) => error.message, 'message', contains('"a"'))));
  });
}
