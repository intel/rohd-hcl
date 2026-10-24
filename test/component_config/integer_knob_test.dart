// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// integer_knob_test.dart
// Tests for signed, nonnegative, and positive integer configuration knobs.
//
// 2026 October 23
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('signed knobs preserve negative values and hexadecimal JSON', () {
    final knob = IntConfigKnob(value: -7);
    expect(knob.value, -7);
    knob.setValueFromString(' -0x10 ');
    expect(knob.value, -16);
    knob.loadJson({'value': '0x100'});
    expect(knob.value, 256);
    expect(knob.toJson(), {'value': '0x100'});
  });

  for (final minimum in [0, 1, 2]) {
    IntConfigKnob create(int value) => switch (minimum) {
          0 => NonNegativeIntConfigKnob(value: value),
          1 => PositiveIntConfigKnob(value: value),
          _ => IntConfigKnob(value: value, minValue: minimum),
        };
    test('minimum $minimum applies to construction, edits and deserialization',
        () {
      expect(() => create(minimum - 1), throwsArgumentError);
      final knob = create(minimum);
      expect(knob.value, minimum);
      expect(() => knob.value = minimum - 1, throwsArgumentError);
      expect(
          () => knob.setValueFromString('${minimum - 1}'), throwsArgumentError);
      expect(() => knob.loadJson({'value': minimum - 1}), throwsArgumentError);
      expect(() => knob.loadJson({'value': '${minimum - 1}'}),
          throwsArgumentError);
      expect(knob.value, minimum);
      knob.value = 1000000;
      expect(knob.value, 1000000);
      final restored = create(minimum)..loadJson(knob.toJson());
      expect(restored.value, knob.value);
    });
  }

  for (final invalid in ['', 'abc', '1.5', '0x', '--2']) {
    test('invalid integer "$invalid" reports an error without changing value',
        () {
      final knob = IntConfigKnob(value: 7);
      expect(() => knob.setValueFromString(invalid), throwsArgumentError);
      expect(knob.value, 7);
    });
  }

  test('configurators distinguish positive geometry from zero-inclusive data',
      () {
    expect(RippleCarryAdderConfigurator().logicWidthKnob.minValue, 1);
    expect(FifoConfigurator().depthKnob.minValue, 1);
    expect(RegisterFileConfigurator().numWritePortsKnobs.minValue, 0);
    expect(ApbCsrCompleterConfigurator().responseLatencyKnob.minValue, 0);
    expect(ApbCsrCompleterConfigurator().userRequestWidthKnob.minValue, 0);
    expect(FixedToFloatConfigurator().fractionWidthKnob.minValue, 0);
    expect(CountConfigurator().radixKnob.minValue, 2);
    expect(AsyncFifoConfigurator().syncStagesKnob.minValue, 2);
    expect(StaticOrRuntimeIntKnob().runtimeWidthKnob.minValue, 1);
    final signed = SumInterfaceKnob().fixedValueKnob..value = -3;
    expect(signed.value, -3);
  });
}
