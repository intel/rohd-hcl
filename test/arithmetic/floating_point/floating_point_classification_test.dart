// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_classification_test.dart
// Tests for floating-point classification and comparison.
//
// 2026 November 8
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

double _value(int bits) {
  final sign = bits >> 5 == 0 ? 1 : -1;
  final exponent = (bits >> 2) & 7;
  final fraction = bits & 3;
  if (exponent == 7) {
    return fraction == 0 ? sign * double.infinity : double.nan;
  }
  if (exponent == 0) {
    return sign * fraction / 4 * pow(2, -2);
  }
  return sign * (1 + fraction / 4) * pow(2, exponent - 3);
}

double _valueE4M3(int bits) {
  final sign = bits >> 7 == 0 ? 1 : -1;
  final exponent = (bits >> 3) & 15;
  final fraction = bits & 7;
  if (exponent == 15 && fraction == 7) {
    return double.nan;
  }
  if (exponent == 0) {
    return sign * fraction / 8 * pow(2, -6);
  }
  return sign * (1 + fraction / 8) * pow(2, exponent - 7);
}

void main() {
  tearDown(Simulator.reset);

  test('classifies all small-format encodings', () async {
    final dut = FloatingPointClassifier(
        FloatingPoint(exponentWidth: 3, mantissaWidth: 2));
    await dut.build();
    final vectors = [
      for (var bits = 0; bits < 64; bits++)
        Vector({
          'value': bits
        }, {
          'sign': bits >> 5,
          'zero': (bits & 31) == 0 ? 1 : 0,
          'subnormal': (bits & 28) == 0 && (bits & 3) != 0 ? 1 : 0,
          'normal': (bits & 28) != 0 && (bits & 28) != 28 ? 1 : 0,
          'infinity': (bits & 31) == 28 ? 1 : 0,
          'quietNaN': (bits & 28) == 28 && (bits & 2) != 0 ? 1 : 0,
          'signalingNaN': (bits & 31) == 29 ? 1 : 0,
        }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('compares every pair of small-format encodings', () async {
    final dut = FloatingPointComparator(
      FloatingPoint(exponentWidth: 3, mantissaWidth: 2),
      FloatingPoint(exponentWidth: 3, mantissaWidth: 2),
    );
    await dut.build();
    final vectors = [
      for (var a = 0; a < 64; a++)
        for (var b = 0; b < 64; b++)
          Vector({
            'a': a,
            'b': b
          }, {
            'less': _value(a) < _value(b) ? 1 : 0,
            'equal': _value(a) == _value(b) ? 1 : 0,
            'greater': _value(a) > _value(b) ? 1 : 0,
            'unordered': _value(a).isNaN || _value(b).isNaN ? 1 : 0,
          }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('classifies E4M3 including its finite maximum exponent', () async {
    final dut = FloatingPointClassifier(FloatingPoint8E4M3());
    await dut.build();
    final vectors = [
      for (var bits = 0; bits < 256; bits++)
        Vector({
          'value': bits
        }, {
          'sign': bits >> 7,
          'zero': (bits & 127) == 0 ? 1 : 0,
          'subnormal': (bits & 120) == 0 && (bits & 7) != 0 ? 1 : 0,
          'normal': (bits & 120) != 0 && (bits & 127) != 127 ? 1 : 0,
          'infinity': 0,
          'quietNaN': (bits & 127) == 127 ? 1 : 0,
          'signalingNaN': 0,
        }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('compares E4M3 boundary values', () async {
    final dut =
        FloatingPointComparator(FloatingPoint8E4M3(), FloatingPoint8E4M3());
    await dut.build();
    const values = [
      0,
      1,
      7,
      8,
      119,
      120,
      126,
      127,
      128,
      129,
      135,
      136,
      247,
      248,
      254,
      255
    ];
    final vectors = [
      for (final a in values)
        for (final b in values)
          Vector({
            'a': a,
            'b': b
          }, {
            'less': _valueE4M3(a) < _valueE4M3(b) ? 1 : 0,
            'equal': _valueE4M3(a) == _valueE4M3(b) ? 1 : 0,
            'greater': _valueE4M3(a) > _valueE4M3(b) ? 1 : 0,
            'unordered': _valueE4M3(a).isNaN || _valueE4M3(b).isNaN ? 1 : 0,
          }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('compares subnormals as signed zeros when configured', () async {
    final dut = FloatingPointComparator(
      FloatingPoint(exponentWidth: 3, mantissaWidth: 2, subNormalAsZero: true),
      FloatingPoint(exponentWidth: 3, mantissaWidth: 2, subNormalAsZero: true),
    );
    await dut.build();
    double flushed(int bits) => (bits & 28) == 0 ? 0 : _value(bits);
    final vectors = [
      for (var a = 0; a < 64; a++)
        for (var b = 0; b < 64; b++)
          Vector({
            'a': a,
            'b': b
          }, {
            'less': flushed(a) < flushed(b) ? 1 : 0,
            'equal': flushed(a) == flushed(b) ? 1 : 0,
            'greater': flushed(a) > flushed(b) ? 1 : 0,
            'unordered': flushed(a).isNaN || flushed(b).isNaN ? 1 : 0,
          }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('preserves unknown sign during classification of zero', () async {
    final dut = FloatingPointClassifier(
        FloatingPoint(exponentWidth: 3, mantissaWidth: 2));
    await dut.build();
    final vectors = [
      for (final sign in ['x', 'z'])
        Vector({
          'value': LogicValue.ofString('${sign}00000')
        }, {
          'sign': LogicValue.ofString(sign),
          'zero': 1,
          'subnormal': 0,
          'normal': 0,
          'infinity': 0,
          'quietNaN': 0,
          'signalingNaN': 0,
        }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('zero comparison does not depend on an unknown sign', () async {
    final dut = FloatingPointComparator(
      FloatingPoint(exponentWidth: 3, mantissaWidth: 2),
      FloatingPoint(exponentWidth: 3, mantissaWidth: 2),
    );
    await dut.build();
    final vectors = [
      for (final sign in ['x', 'z'])
        Vector({
          'a': LogicValue.ofString('${sign}00000'),
          'b': 0
        }, {
          'less': 0,
          'equal': 1,
          'greater': 0,
          'unordered': 0,
        }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('rejects different formats and explicit J-bit inputs', () {
    expect(
      () => FloatingPointComparator(
        FloatingPoint(exponentWidth: 3, mantissaWidth: 2),
        FloatingPoint(exponentWidth: 2, mantissaWidth: 3),
      ),
      throwsArgumentError,
    );
    expect(
      () => FloatingPointClassifier(
        FloatingPoint(exponentWidth: 3, mantissaWidth: 2, explicitJBit: true),
      ),
      throwsArgumentError,
    );
  });
}
