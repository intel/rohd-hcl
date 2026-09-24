// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_rounding_test.dart
// Tests for floating-point rounding support.
//
// 2026 August 25
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('FP: explicit and vector rounders cover every mode', () {
    final retainedLsb = Logic();
    final guard = Logic();
    final roundBit = Logic();
    final sticky = Logic();
    final sign = Logic();
    final vector = [retainedLsb, guard, roundBit, sticky].swizzle();

    for (final mode in FloatingPointRoundingMode.values) {
      final explicit = FloatingPointRounder.fromGRS(
          retainedLsb: retainedLsb,
          guard: guard,
          roundBit: roundBit,
          sticky: sticky,
          roundingMode: mode,
          sign: sign);
      final extracted =
          FloatingPointRounder(vector, 3, roundingMode: mode, sign: sign);

      for (final signValue in [false, true]) {
        for (var fields = 0; fields < 16; fields++) {
          sign.put(signValue);
          retainedLsb.put((fields >> 3) & 1);
          guard.put((fields >> 2) & 1);
          roundBit.put((fields >> 1) & 1);
          sticky.put(fields & 1);

          final lastValue = retainedLsb.value.toBool();
          final guardValue = guard.value.toBool();
          final roundValue = roundBit.value.toBool();
          final stickyValue = sticky.value.toBool();
          final inexact = guardValue || roundValue || stickyValue;
          final expected = switch (mode) {
            FloatingPointRoundingMode.truncate ||
            FloatingPointRoundingMode.roundTowardsZero =>
              false,
            FloatingPointRoundingMode.roundNearestEven =>
              guardValue && (lastValue || roundValue || stickyValue),
            FloatingPointRoundingMode.roundNearestTiesAway => guardValue,
            FloatingPointRoundingMode.roundTowardsInfinity =>
              !signValue && inexact,
            FloatingPointRoundingMode.roundTowardsNegativeInfinity =>
              signValue && inexact,
          };

          expect(explicit.inexact.value.toBool(), inexact,
              reason: 'mode=$mode sign=$signValue fields=$fields');
          expect(explicit.doRound.value.toBool(), expected,
              reason: 'mode=$mode sign=$signValue fields=$fields');
          expect(extracted.doRound.value, explicit.doRound.value,
              reason: 'mode=$mode sign=$signValue fields=$fields');
        }
      }
    }
  });
}
