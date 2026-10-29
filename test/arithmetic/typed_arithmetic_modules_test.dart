// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// typed_arithmetic_modules_test.dart
// Tests for typed arithmetic modules.
//
// 2026 October 23
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _UnsignedFixed extends FixedPoint {
  _UnsignedFixed({super.name})
      : super(integerWidth: 3, fractionWidth: 5, signed: false);

  @override
  _UnsignedFixed clone({String? name}) =>
      _UnsignedFixed(name: name ?? this.name);

  @override
  FixedPointValuePopulator<FixedPointValue> valuePopulator() =>
      FixedPointValue.populatorWithSignedness(
          integerWidth: 3, fractionWidth: 5, signed: false);
}

class _SignedFixed extends FixedPoint {
  _SignedFixed({super.name}) : super(integerWidth: 3, fractionWidth: 4);

  @override
  _SignedFixed clone({String? name}) => _SignedFixed(name: name ?? this.name);

  @override
  FixedPointValuePopulator<FixedPointValue> valuePopulator() =>
      FixedPointValue.populatorWithSignedness(
          integerWidth: 3, fractionWidth: 4);
}

class _FloatToFixedHarness extends Module {
  late final FloatToFixed<_SignedFixed> converter;
  late final _SignedFixed result;

  _FloatToFixedHarness() {
    final input = FloatingPoint32()
      ..gets(addInput('data', Logic(width: 32), width: 32));
    final schema = _SignedFixed();
    converter = FloatToFixed<_SignedFixed>(input,
        outFixed: schema,
        checkOverflow: true,
        roundingMode: FloatingPointRoundingMode.roundNearestEven);
    result = converter.fixed;
    addOutput('result', width: 8) <= result;
    addOutput('schemaResult', width: 8) <= schema;
    addOutput('overflow') <= converter.overflow!;
  }
}

class _Float8Harness extends Module {
  late final Float8ToFixed converter;

  _Float8Harness() {
    final data = FloatingPoint8E4M3()
      ..gets(addInput('data', Logic(width: 8), width: 8));
    converter = Float8ToFixed(data, addInput('mode', Logic()));
    addOutput('result', width: 33) <= converter.fixed;
  }
}

class _FixedSqrtHarness extends Module {
  late final _UnsignedFixed result;

  _FixedSqrtHarness() {
    final data = _UnsignedFixed()
      ..gets(addInput('data', Logic(width: 8), width: 8));
    result = FixedPointSqrt(data).sqrt;
    addOutput('result', width: 8) <= result;
  }
}

class _ConversionHarness extends Module {
  late final FloatingPoint32 result;

  _ConversionHarness() {
    final data = _UnsignedFixed()
      ..gets(addInput('data', Logic(width: 8), width: 8));
    result = FixedToFloat(data, FloatingPoint32(), signed: false).float;
    addOutput('result', width: 32) <= result;
  }
}

class _FixedComparisons extends Module {
  _FixedComparisons({required bool signed}) {
    final a = FixedPoint(
        integerWidth: signed ? 1 : 2, fractionWidth: 2, signed: signed)
      ..gets(addInput('a', Logic(width: 4), width: 4));
    final b = a.clone()..gets(addInput('b', Logic(width: 4), width: 4));
    addOutput('lt') <= a.lt(b);
    addOutput('lte') <= a.lte(b);
    addOutput('gt') <= a.gt(b);
    addOutput('gte') <= a.gte(b);
    addOutput('greaterOperator') <= (a > b);
    addOutput('greaterEqualOperator') <= (a >= b);
  }
}

class _NaNPipeline extends Module {
  late final Module arithmetic;

  _NaNPipeline(String kind) {
    final a = FloatingPoint(exponentWidth: 3, mantissaWidth: 4)
      ..gets(addInput('a', Logic(width: 8), width: 8));
    final b = a.clone()..gets(addInput('b', Logic(width: 8), width: 8));
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final enable = addInput('enable', Logic());
    final FloatingPoint result;
    final FloatingPointStatus status;
    switch (kind) {
      case 'single-path':
        final adder =
            FloatingPointAdderSinglePath<FloatingPoint, FloatingPoint>(a, b,
                clk: clk, reset: reset, enable: enable);
        arithmetic = adder;
        result = adder.sum;
        status = adder.status;
      case 'dual-path':
        final adder = FloatingPointAdderDualPath<FloatingPoint, FloatingPoint>(
            a, b,
            clk: clk, reset: reset, enable: enable);
        arithmetic = adder;
        result = adder.sum;
        status = adder.status;
      case 'multiply':
        final multiplier =
            FloatingPointMultiplierSimple<FloatingPoint, FloatingPoint>(a, b,
                clk: clk,
                reset: reset,
                enable: enable,
                multGen: (a, b, {clk, reset, enable, name = 'mult'}) =>
                    NativeMultiplier(a, b, name: name));
        arithmetic = multiplier;
        result = multiplier.product;
        status = multiplier.status;
      default:
        throw ArgumentError.value(kind, 'kind');
    }
    addOutput('result', width: 8) <= result;
    addOutput('invalid') <= status.invalid;
  }
}

Future<void> _compare(Module dut, List<Vector> vectors,
    {bool systemC = false}) async {
  await SimCompare.checkFunctionalVector(dut, vectors);
  SimCompare.checkIverilogVector(dut, vectors);
  if (systemC) {
    SimCompare.checkSystemCVector(dut, vectors);
  }
}

void main() {
  tearDown(Simulator.reset);

  test('float-to-fixed preserves and drives a signed output subtype', () async {
    final dut = _FloatToFixedHarness();
    await dut.build();
    expect(dut.converter.input('float'), isA<FloatingPoint32>());
    expect(dut.converter.output('fixed'), isA<_SignedFixed>());
    expect(dut.result.integerWidth, 3);
    expect(dut.result.fractionWidth, 4);
    expect(dut.converter.definitionName, contains('I3_F4'));
    final cases = <int, (int, int)>{
      0: (0, 0),
      0x3fa00000: (0x14, 0),
      0xbfc00000: (0xe8, 0),
      0x40fe0000: (0x7f, 0),
      0xc1000000: (0x80, 0),
      0x41000000: (0x80, 1),
      0xc1080000: (0x78, 1),
      0x3f840000: (0x10, 0),
      0x3f8c0000: (0x12, 0),
      0xbf840000: (0xf0, 0),
    };
    await _compare(
        dut,
        [
          for (final entry in cases.entries)
            Vector({
              'data': entry.key
            }, {
              'result': entry.value.$1,
              'schemaResult': entry.value.$1,
              'overflow': entry.value.$2,
            }),
        ],
        systemC: true);
  });

  test('float-to-fixed validates specialized output geometry', () {
    expect(() => FloatToFixed<_SignedFixed>(FloatingPoint32()),
        throwsArgumentError);
    expect(() => FloatToFixed(FloatingPoint32(), outFixed: _UnsignedFixed()),
        throwsArgumentError);
    expect(
        () => FloatToFixed(FloatingPoint32(),
            outFixed: _SignedFixed(), integerWidth: 4),
        throwsArgumentError);
    expect(
        () => FloatToFixed(FloatingPoint32(),
            outFixed: _SignedFixed(), fractionWidth: 3),
        throwsArgumentError);
    final matched = FloatToFixed(FloatingPoint32(),
        outFixed: _SignedFixed(), integerWidth: 3, fractionWidth: 4);
    final scalar =
        FloatToFixed(FloatingPoint32(), integerWidth: 3, fractionWidth: 4);
    expect(matched.definitionName, scalar.definitionName);
    expect(matched.fixed, isA<_SignedFixed>());
  });

  test('dual-format FP8 converter preserves its structured input', () async {
    final dut = _Float8Harness();
    await dut.build();
    expect(dut.converter.input('float'), isA<FloatingPoint8E4M3>());
    await _compare(dut, [
      Vector({'data': 0x3c, 'mode': 1}, {'result': 0x300}),
      Vector({'mode': 0}, {'result': 0x10000}),
    ]);
  });

  for (final signed in [false, true]) {
    test('fixed-point comparisons exhaust all encodings, signed=$signed',
        () async {
      final dut = _FixedComparisons(signed: signed);
      await dut.build();
      int numeric(int bits) => signed && bits >= 8 ? bits - 16 : bits;
      await _compare(
          dut,
          [
            for (var a = 0; a < 16; a++)
              for (var b = 0; b < 16; b++)
                Vector({
                  'a': a,
                  'b': b
                }, {
                  'lt': numeric(a) < numeric(b) ? 1 : 0,
                  'lte': numeric(a) <= numeric(b) ? 1 : 0,
                  'gt': numeric(a) > numeric(b) ? 1 : 0,
                  'gte': numeric(a) >= numeric(b) ? 1 : 0,
                  'greaterOperator': numeric(a) > numeric(b) ? 1 : 0,
                  'greaterEqualOperator': numeric(a) >= numeric(b) ? 1 : 0,
                }),
          ],
          systemC: true);
    });
  }

  test('fixed-point sqrt preserves its concrete input format', () async {
    final dut = _FixedSqrtHarness();
    await dut.build();
    expect(dut.result, isA<_UnsignedFixed>());
    expect(dut.result.signed, isFalse);
    expect(dut.result.integerWidth, 3);
    expect(dut.result.fractionWidth, 5);
    await _compare(
        dut,
        [
          Vector({'data': 0}, {'result': 0}),
          Vector({'data': 32}, {'result': 32}),
          Vector({'data': 72}, {'result': 48}),
          Vector({'data': 128}, {'result': 64}),
        ],
        systemC: true);
  });

  test('fixed-to-float retains a statically typed floating-point output',
      () async {
    final dut = _ConversionHarness();
    await dut.build();
    expect(dut.result, isA<FloatingPoint32>());
    await _compare(
        dut,
        [
          Vector({'data': 0}, {'result': 0}),
          Vector({'data': 32}, {'result': 0x3f800000}),
          Vector({'data': 40}, {'result': 0x3fa00000}),
          Vector({'data': 144}, {'result': 0x40900000}),
        ],
        systemC: true);
  });

  for (final kind in ['single-path', 'dual-path', 'multiply']) {
    test('$kind pipelines NaNs as floating-point payloads', () async {
      final dut = _NaNPipeline(kind);
      await dut.build();
      final nanFlops =
          dut.arithmetic.subModules.whereType<FlipFlop<FloatingPoint>>();
      expect(nanFlops, hasLength(1));
      expect(nanFlops.single.q.exponent.width, 3);
      expect(nanFlops.single.q.mantissa.width, 4);
      await _compare(dut, [
        Vector({'clk': 0, 'reset': 1, 'enable': 1, 'a': 0, 'b': 0}, {}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'reset': 0, 'a': 0x71, 'b': 0x30}, {}),
        Vector({'clk': 1}, {'result': 0x79, 'invalid': 1}),
        Vector({'clk': 0, 'enable': 0, 'a': 0x30, 'b': 0xfa},
            {'result': 0x79, 'invalid': 1}),
        Vector({'clk': 1}, {'result': 0x79, 'invalid': 1}),
        Vector({'clk': 0, 'enable': 1}, {}),
        Vector({'clk': 1}, {'result': 0xfa, 'invalid': 0}),
        Vector({
          'clk': 0,
          'a': kind == 'multiply' ? 0 : 0x70,
          'b': kind == 'multiply' ? 0x70 : 0xf0,
        }, {}),
        Vector({'clk': 1}, {'result': 0x78, 'invalid': 1}),
        Vector({'clk': 0, 'reset': 1, 'enable': 0}, {}),
        Vector({'clk': 1}, {'invalid': 0}),
        Vector({
          'clk': 0,
          'reset': 0,
          'enable': 1,
          'a': LogicValue.ofString('x1110001'),
          'b': 0x30,
        }, {}),
        Vector({'clk': 1},
            {'result': LogicValue.ofString('x1111001'), 'invalid': 1}),
      ]);
    });
  }
}
