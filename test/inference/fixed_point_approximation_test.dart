// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_approximation_test.dart
// Tests for Fixed Point Approximation.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('Exp2 lookup matches its exhaustive fixed-point oracle', () async {
    final input = Logic(width: 5);
    final dut = Exp2Approximation(
      input,
      inputFractionBits: 2,
      outputWidth: 10,
      outputFractionBits: 6,
      minimumInputRaw: -8,
      maximumInputRaw: 7,
    );
    await dut.build();

    var previous = BigInt.zero;
    for (var raw = -16; raw < 16; raw++) {
      input.inject(BigInt.from(raw).toUnsigned(input.width));
      await Simulator.tick();
      final expected = evaluateFixedPointApproximation(dut.contract, raw);
      expect(dut.result.value.toBigInt(), expected.result, reason: 'raw=$raw');
      expect(
        dut.status.invalidInput.value.toBool(),
        expected.invalidInput,
        reason: 'raw=$raw invalid',
      );
      expect(
        dut.status.outOfRange.value.toBool(),
        expected.outOfRange,
        reason: 'raw=$raw range',
      );
      expect(
        dut.status.overflow.value.toBool(),
        expected.overflow,
        reason: 'raw=$raw overflow',
      );
      expect(
        dut.status.inexact.value.toBool(),
        expected.inexact,
        reason: 'raw=$raw inexact',
      );
      if (raw >= dut.contract.minimumInputRaw &&
          raw <= dut.contract.maximumInputRaw) {
        expect(
          dut.result.value.toBigInt(),
          greaterThanOrEqualTo(previous),
          reason: 'raw=$raw monotonic',
        );
        previous = dut.result.value.toBigInt();
      }
    }
    expect(dut.contract.maximumErrorLsb, 0.5);
    expect(dut.contract.monotonicallyIncreasing, isTrue);
  });

  test('reciprocal lookup reports zero and decreases over its domain',
      () async {
    final input = Logic(width: 6);
    final dut = ReciprocalApproximation(
      input,
      inputFractionBits: 3,
      outputWidth: 12,
      outputFractionBits: 8,
    );
    await dut.build();

    BigInt? previous;
    for (var raw = 0; raw < 64; raw++) {
      input.inject(raw);
      await Simulator.tick();
      final expected = evaluateFixedPointApproximation(dut.contract, raw);
      expect(dut.result.value.toBigInt(), expected.result, reason: 'raw=$raw');
      expect(
        dut.status.invalidInput.value.toBool(),
        raw == 0,
        reason: 'raw=$raw invalid',
      );
      if (raw > 0) {
        if (previous != null) {
          expect(
            dut.result.value.toBigInt(),
            lessThanOrEqualTo(previous),
            reason: 'raw=$raw decreasing',
          );
        }
        previous = dut.result.value.toBigInt();
      }
    }
  });

  test('reciprocal-square-root lookup matches exhaustive oracle', () async {
    final input = Logic(width: 6);
    final dut = ReciprocalSqrtApproximation(
      input,
      inputFractionBits: 3,
      outputWidth: 12,
      outputFractionBits: 8,
    );
    await dut.build();

    for (var raw = 0; raw < 64; raw++) {
      input.inject(raw);
      await Simulator.tick();
      final expected = evaluateFixedPointApproximation(dut.contract, raw);
      expect(dut.result.value.toBigInt(), expected.result, reason: 'raw=$raw');
      expect(
        dut.status.invalidInput.value.toBool(),
        raw == 0,
        reason: 'raw=$raw invalid',
      );
    }
  });

  test('positive approximation functors retain operation identity', () {
    expect(
      lookupReciprocalApproximationFunctor.operation,
      FixedPointApproximationOperation.reciprocal,
    );
    expect(
      lookupReciprocalSqrtApproximationFunctor.operation,
      FixedPointApproximationOperation.reciprocalSquareRoot,
    );
    expect(lookupExp2ApproximationFunctor.identity, 'lookup');
  });

  test('rejects invalid contracts and oversized lookup tables', () {
    expect(
      () => FixedPointApproximationContract(
        operation: FixedPointApproximationOperation.reciprocal,
        inputWidth: 4,
        inputFractionBits: 2,
        signedInput: false,
        outputWidth: 8,
        outputFractionBits: 4,
        minimumInputRaw: 0,
        maximumInputRaw: 15,
        roundingMode: NumericRoundingMode.nearestEven,
        maximumErrorLsb: 0.5,
        monotonicallyIncreasing: false,
      ),
      throwsArgumentError,
    );
    expect(
      () => Exp2Approximation(
        Logic(width: 13),
        inputFractionBits: 4,
        outputWidth: 8,
        outputFractionBits: 4,
      ),
      throwsArgumentError,
    );
  });
}
