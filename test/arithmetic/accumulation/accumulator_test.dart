// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// accumulator_test.dart
// Tests for the lightweight accumulator.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('clear suppresses accumulation and restart accumulates', () async {
    final accumulator = Accumulator(
      Logic(width: 3),
      clk: Logic(),
      reset: Logic(),
      enable: Logic(),
      clear: Logic(),
      restart: Logic(),
      resetValue: 2,
      width: 4,
    );
    await accumulator.build();

    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'enable': 0,
        'clear': 0,
        'restart': 0,
        'amount': 0,
      }, {}),
      Vector({
        'clk': 1,
        'reset': 1,
        'enable': 0,
        'clear': 0,
        'restart': 0,
        'amount': 0,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'enable': 1,
        'clear': 0,
        'restart': 0,
        'amount': 3,
      }, {
        'value': 2,
      }),
      Vector({
        'clk': 1,
        'reset': 0,
        'enable': 1,
        'clear': 0,
        'restart': 0,
        'amount': 3,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'enable': 1,
        'clear': 1,
        'restart': 0,
        'amount': 3,
      }, {
        'value': 5,
      }),
      Vector({
        'clk': 1,
        'reset': 0,
        'enable': 1,
        'clear': 1,
        'restart': 0,
        'amount': 3,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'enable': 1,
        'clear': 0,
        'restart': 1,
        'amount': 3,
      }, {
        'value': 2,
      }),
      Vector({
        'clk': 1,
        'reset': 0,
        'enable': 1,
        'clear': 0,
        'restart': 1,
        'amount': 3,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'enable': 0,
        'clear': 0,
        'restart': 0,
        'amount': 7,
      }, {
        'value': 5,
      }),
    ];

    await SimCompare.checkFunctionalVector(accumulator, vectors);
    SimCompare.checkIverilogVector(accumulator, vectors);
  });

  test('saturates at the natural maximum', () async {
    final accumulator = Accumulator(
      Logic(width: 3),
      clk: Logic(),
      reset: Logic(),
      width: 3,
      saturates: true,
    );
    await accumulator.build();

    final vectors = [
      Vector({'clk': 0, 'reset': 1, 'amount': 0}, {}),
      Vector({'clk': 1, 'reset': 1, 'amount': 0}, {}),
      Vector({'clk': 0, 'reset': 0, 'amount': 6}, {'value': 0}),
      Vector({'clk': 1, 'reset': 0, 'amount': 6}, {}),
      Vector({'clk': 0, 'reset': 0, 'amount': 3}, {'value': 6}),
      Vector({'clk': 1, 'reset': 0, 'amount': 3}, {}),
      Vector({'clk': 0, 'reset': 0, 'amount': 1}, {'value': 7}),
    ];

    await SimCompare.checkFunctionalVector(accumulator, vectors);
    SimCompare.checkIverilogVector(accumulator, vectors);
  });

  test('counter omits unrequested status ports and history', () async {
    final counter = Counter.simple(
      clk: Logic(),
      reset: Logic(),
      width: 2,
      trackOverflow: false,
      trackUnderflow: false,
    );
    await counter.build();

    expect(
      counter.outputs.keys,
      containsAll(['count', 'equalsMax', 'equalsMin']),
    );
    expect(counter.outputs.keys, isNot(contains('overflowed')));
    expect(counter.outputs.keys, isNot(contains('underflowed')));
    expect(counter.overflowed, isNull);
    expect(counter.underflowed, isNull);

    final vectors = [
      Vector({'clk': 0, 'reset': 1}, {}),
      Vector({'clk': 1, 'reset': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0
      }, {
        'count': 0,
      }),
      Vector({'clk': 1, 'reset': 0}, {}),
      Vector({
        'clk': 0,
        'reset': 0
      }, {
        'count': 1,
      }),
    ];

    await SimCompare.checkFunctionalVector(counter, vectors);
    SimCompare.checkIverilogVector(counter, vectors);
  });
}
