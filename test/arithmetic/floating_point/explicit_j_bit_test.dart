// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// explicit_j_bit_test.dart
// Reference-model tests for explicit-J-bit canonicalization.
//
// 2026 November 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

double _explicitValue(int bits, {bool flushSubnormal = false}) {
  final sign = bits >> 6 == 0 ? 1 : -1;
  final exponent = (bits >> 3) & 7;
  final mantissa = bits & 7;
  if (exponent == 7) {
    return (mantissa & 3) == 0 ? sign * double.infinity : double.nan;
  }
  final value = sign * mantissa / 4 * pow(2, max(1, exponent) - 3);
  return flushSubnormal && value.abs() < 0.25 ? 0 : value;
}

double _implicitValue(int bits) {
  final sign = bits >> 5 == 0 ? 1 : -1;
  final exponent = (bits >> 2) & 7;
  final fraction = bits & 3;
  if (exponent == 7) {
    return fraction == 0 ? sign * double.infinity : double.nan;
  }
  return exponent == 0
      ? sign * fraction / 4 * pow(2, -2)
      : sign * (1 + fraction / 4) * pow(2, exponent - 3);
}

int _implicitEncoding(int bits) {
  final sign = bits >> 6;
  final value = _explicitValue(bits);
  if (value.isNaN) {
    return (sign << 5) | 28 | 2 | (bits & 1);
  }
  for (var candidate = 0; candidate < 32; candidate++) {
    final signedCandidate = (sign << 5) | candidate;
    if (_implicitValue(signedCandidate) == value) {
      return signedCandidate;
    }
  }
  throw StateError('No exact implicit encoding for $bits.');
}

FloatingPoint _explicit({bool flushSubnormal = false}) => FloatingPoint(
      exponentWidth: 3,
      mantissaWidth: 3,
      explicitJBit: true,
      subNormalAsZero: flushSubnormal,
    );

void main() {
  tearDown(Simulator.reset);

  test('classifies all explicit-J encodings by numerical value', () async {
    final dut = FloatingPointClassifier(_explicit(), alignExplicitJBit: true);
    await dut.build();
    final vectors = [
      for (var bits = 0; bits < 128; bits++)
        Vector({
          'value': bits
        }, {
          'sign': bits >> 6,
          'zero': _explicitValue(bits) == 0 ? 1 : 0,
          'subnormal': _explicitValue(bits) != 0 &&
                  !_explicitValue(bits).isNaN &&
                  _explicitValue(bits).abs() < 0.25
              ? 1
              : 0,
          'normal': _explicitValue(bits).isFinite &&
                  _explicitValue(bits).abs() >= 0.25
              ? 1
              : 0,
          'infinity': _explicitValue(bits).isInfinite ? 1 : 0,
          'quietNaN': _explicitValue(bits).isNaN && (bits & 2) != 0 ? 1 : 0,
          'signalingNaN': _explicitValue(bits).isNaN && (bits & 2) == 0 ? 1 : 0,
        }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  for (final flush in [false, true]) {
    test('compares all explicit-J pairs, subnormal as zero: $flush', () async {
      final dut = FloatingPointComparator(
        _explicit(flushSubnormal: flush),
        _explicit(flushSubnormal: flush),
        alignExplicitJBit: true,
      );
      await dut.build();
      final values = [
        for (var bits = 0; bits < 128; bits++)
          _explicitValue(bits, flushSubnormal: flush),
      ];
      final vectors = [
        for (var a = 0; a < 128; a++)
          for (var b = 0; b < 128; b++)
            Vector({
              'a': a,
              'b': b
            }, {
              'less': values[a] < values[b] ? 1 : 0,
              'equal': values[a] == values[b] ? 1 : 0,
              'greater': values[a] > values[b] ? 1 : 0,
              'unordered': values[a].isNaN || values[b].isNaN ? 1 : 0,
            }),
      ];
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  test('exact same-exponent conversion canonicalizes every encoding', () async {
    final destination = FloatingPoint(exponentWidth: 3, mantissaWidth: 2);
    final source = _explicit();
    final dut = FloatingPointConverter(
      source,
      destination,
      alignExplicitJBit: true,
    );
    await dut.build();
    final vectors = [
      for (var bits = 0; bits < 128; bits++)
        Vector({'source': bits}, {'destination': _implicitEncoding(bits)}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  for (final exponentWidth in [1, 2, 3, 4]) {
    for (final explicitDestination in [false, true]) {
      for (final fractionWidth in [1, 2, 3]) {
        for (final roundingMode in FloatingPointRoundingMode.values) {
          test(
              'aligned conversion E$exponentWidth '
              'fraction=$fractionWidth explicit=$explicitDestination '
              '$roundingMode', () async {
            final mantissaWidth = fractionWidth + (explicitDestination ? 1 : 0);
            final destination = FloatingPoint(
              exponentWidth: exponentWidth,
              mantissaWidth: mantissaWidth,
              explicitJBit: explicitDestination,
            );
            final source = _explicit();
            final dut = FloatingPointConverter(
              source,
              destination,
              alignExplicitJBit: true,
              roundingMode: roundingMode,
            );
            await dut.build();
            final vectors = [
              for (var bits = 0; bits < 128; bits++)
                Vector({
                  'source': bits
                }, {
                  'destination': (_explicitValue(bits).isNaN
                              ? destination
                                  .valuePopulator()
                                  .ofFloatingPointValueRounded(source
                                      .valuePopulator()
                                      .ofInts(7, bits & 7,
                                          sign: (bits & 64) != 0))
                              : destination.valuePopulator().ofDouble(
                                  _explicitValue(bits),
                                  roundingMode: roundingMode))
                          .value
                          .toInt() |
                      ((bits & 64) != 0
                          ? 1 << (exponentWidth + mantissaWidth)
                          : 0),
                }),
            ];
            await SimCompare.checkFunctionalVector(dut, vectors);
            if (roundingMode == FloatingPointRoundingMode.roundNearestEven) {
              SimCompare.checkIverilogVector(dut, vectors);
            }
          });
        }
      }
    }
  }

  test('aligned converter reports special values and rounding status',
      () async {
    final source = _explicit();
    final destination = FloatingPoint(exponentWidth: 2, mantissaWidth: 2);
    final dut =
        FloatingPointConverter(source, destination, alignExplicitJBit: true);
    await dut.build();
    source.put(57);
    expect(dut.status.invalid.value, LogicValue.one);
    expect(destination.isQuietNaN.value, LogicValue.one);
    source.put(59);
    expect(dut.status.invalid.value, LogicValue.zero);
    expect(destination.isQuietNaN.value, LogicValue.one);
    source.put(55);
    expect(dut.status.overflow.value, LogicValue.one);
    expect(dut.status.inexact.value, LogicValue.one);
    source.put(1);
    expect(dut.status.underflow.value, LogicValue.one);
    expect(dut.status.inexact.value, LogicValue.one);
    source.put(28);
    expect(dut.status.underflow.value, LogicValue.zero);
    expect(dut.status.inexact.value, LogicValue.zero);
  });

  test('classification does not flush canonicalized subnormals', () async {
    final dut = FloatingPointClassifier(
      _explicit(flushSubnormal: true),
      alignExplicitJBit: true,
    );
    await dut.build();
    final vectors = [
      Vector({'value': 9}, {'zero': 0, 'subnormal': 1, 'normal': 0}),
      Vector({'value': 8}, {'zero': 1, 'subnormal': 0, 'normal': 0}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('aligned converter rejects an explicit format without a fraction', () {
    expect(
      () => FloatingPointConverter(
        FloatingPoint(exponentWidth: 2, mantissaWidth: 1, explicitJBit: true),
        FloatingPoint(exponentWidth: 3, mantissaWidth: 2),
        alignExplicitJBit: true,
      ),
      throwsArgumentError,
    );
    expect(
      () => FloatingPointConverter(
        _explicit(),
        FloatingPoint(exponentWidth: 2, mantissaWidth: 1, explicitJBit: true),
        alignExplicitJBit: true,
      ),
      throwsArgumentError,
    );
  });

  test('alignment rejects exponent formats without canonical normals', () {
    FloatingPoint small() => FloatingPoint(
          exponentWidth: 1,
          mantissaWidth: 2,
          explicitJBit: true,
        );
    expect(
      () => FloatingPointClassifier(small(), alignExplicitJBit: true),
      throwsArgumentError,
    );
    expect(
      () => FloatingPointComparator(small(), small(), alignExplicitJBit: true),
      throwsArgumentError,
    );
    expect(
      () => FloatingPointConverter(
        small(),
        FloatingPoint(exponentWidth: 2, mantissaWidth: 2),
        alignExplicitJBit: true,
      ),
      throwsArgumentError,
    );
  });

  test('aligned converter supports finite-only destinations', () async {
    final source = FloatingPoint(
      exponentWidth: 4,
      mantissaWidth: 4,
      explicitJBit: true,
    );
    final destination = FloatingPoint8E4M3();
    final dut =
        FloatingPointConverter(source, destination, alignExplicitJBit: true);
    await dut.build();
    double value(int bits) {
      final exponent = (bits >> 4) & 15;
      final mantissa = bits & 15;
      final magnitude = exponent == 15
          ? ((mantissa & 7) == 0 ? double.infinity : double.nan)
          : mantissa / 8 * pow(2, max(1, exponent) - 7);
      return (bits & 256) == 0 ? magnitude : -magnitude;
    }

    int encoding(int bits) {
      final populator = destination.valuePopulator();
      final result = value(bits).isNaN
          ? populator.ofFloatingPointValueRounded(source
              .valuePopulator()
              .ofInts(15, bits & 15, sign: (bits & 256) != 0))
          : populator.ofDouble(value(bits));
      return result.value.toInt() | ((bits & 256) != 0 ? 128 : 0);
    }

    final vectors = [
      for (var bits = 0; bits < 512; bits++)
        Vector({'source': bits}, {'destination': encoding(bits)}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('aligned converter uses the selected leading-one encoder', () async {
    var invocations = 0;
    PriorityEncoder encoder(Logic bits,
        {bool generateValid = false, String name = 'priority_encoder'}) {
      invocations++;
      return RecursiveModulePriorityEncoder(
        bits,
        generateValid: generateValid,
        name: name,
      );
    }

    final dut = FloatingPointConverter(
      _explicit(),
      FloatingPoint(exponentWidth: 3, mantissaWidth: 2),
      alignExplicitJBit: true,
      priorityGen: encoder,
    );
    await dut.build();
    expect(invocations, 1);
  });

  test('unknown sign propagates through aligned classification', () async {
    final dut = FloatingPointClassifier(_explicit(), alignExplicitJBit: true);
    await dut.build();
    final vectors = [
      for (final sign in ['x', 'z'])
        Vector({
          'value': LogicValue.ofString('${sign}001000')
        }, {
          'sign': LogicValue.ofString(sign),
          'zero': 1,
          'subnormal': 0,
          'normal': 0,
        }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('unknown mantissa propagates through aligned classification', () async {
    final dut = FloatingPointClassifier(_explicit(), alignExplicitJBit: true);
    await dut.build();
    final vectors = [
      for (final bit in ['x', 'z'])
        Vector({
          'value': LogicValue.ofString('000000$bit')
        }, {
          'zero': LogicValue.x,
          'subnormal': LogicValue.x,
          'normal': LogicValue.x,
          'infinity': LogicValue.x,
          'quietNaN': LogicValue.x,
          'signalingNaN': LogicValue.x,
        }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('alignment is opt-in and does not change implicit-J RTL', () async {
    final baseline = FloatingPointClassifierConfigurator();
    final enabled = FloatingPointClassifierConfigurator()
      ..alignExplicitJBitKnob.value = true;
    String withoutTimestamp(String rtl) =>
        rtl.replaceFirst(RegExp(r' \* Generation time:.*\n'), '');
    expect(
      withoutTimestamp(await enabled.generateSV()),
      withoutTimestamp(await baseline.generateSV()),
    );
    expect(
      () => FloatingPointClassifier(_explicit()),
      throwsArgumentError,
    );
    expect(
      () => FloatingPointComparator(_explicit(), _explicit()),
      throwsArgumentError,
    );
    expect(
      () => FloatingPointComparator(
        _explicit(),
        FloatingPoint(exponentWidth: 3, mantissaWidth: 3),
        alignExplicitJBit: true,
      ),
      throwsArgumentError,
    );
    for (final pair in [
      (
        FloatingPointComparatorConfigurator(),
        FloatingPointComparatorConfigurator()
          ..alignExplicitJBitKnob.value = true,
      ),
      (
        FloatingPointConverterConfigurator(),
        FloatingPointConverterConfigurator()
          ..alignExplicitJBitKnob.value = true,
      ),
    ]) {
      expect(
        withoutTimestamp(await pair.$1.generateSV()),
        withoutTimestamp(await pair.$2.generateSV()),
      );
    }
  });
}
