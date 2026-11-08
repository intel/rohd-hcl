// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_linear_recurrence_simcompare_test.dart
// Functional and generated RTL tests for registered binary recurrences.
//
// 2026 October 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('registered recurrence matches RTL across enable load and reset',
      () async {
    final recurrence = BinaryLinearRecurrence(
      clk: Logic(),
      reset: Logic(),
      enable: Logic(),
      load: Logic(),
      loadState: Logic(width: 3),
      dataIn: Logic(),
      descriptor: BinaryLinearRecurrenceDescriptor(
        stateMatrix: BinaryMatrix(
          [BigInt.from(4), BigInt.one, BigInt.from(2)],
          columnCount: 3,
        ),
        inputMatrix: BinaryMatrix([BigInt.one, BigInt.zero, BigInt.zero],
            columnCount: 1),
      ),
      initialState: BigInt.one,
    );
    await recurrence.build();

    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'enable': 0,
        'load': 0,
        'load_state': 0,
        'data_in': 0,
      }, {}),
      Vector({
        'clk': 1,
        'reset': 1,
        'enable': 0,
        'load': 0,
        'load_state': 0,
        'data_in': 0,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'enable': 1,
        'load': 0,
        'load_state': 0,
        'data_in': 1,
      }, {
        'state': 1,
        'next_state': 3,
      }),
      Vector({
        'clk': 1,
        'reset': 0,
        'enable': 1,
        'load': 0,
        'load_state': 0,
        'data_in': 1,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'enable': 0,
        'load': 0,
        'load_state': 0,
        'data_in': 0,
      }, {
        'state': 3,
        'next_state': 6,
      }),
      Vector({
        'clk': 1,
        'reset': 0,
        'enable': 0,
        'load': 0,
        'load_state': 0,
        'data_in': 0,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'enable': 0,
        'load': 1,
        'load_state': 5,
        'data_in': 0,
      }, {
        'state': 3,
        'next_state': 6,
      }),
      Vector({
        'clk': 1,
        'reset': 0,
        'enable': 0,
        'load': 1,
        'load_state': 5,
        'data_in': 0,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'enable': 0,
        'load': 0,
        'load_state': 0,
        'data_in': 0,
      }, {
        'state': 5,
        'next_state': 3,
      }),
      Vector({
        'clk': 0,
        'reset': 1,
        'enable': 1,
        'load': 1,
        'load_state': 7,
        'data_in': 1,
      }, {}),
      Vector({
        'clk': 1,
        'reset': 1,
        'enable': 1,
        'load': 1,
        'load_state': 7,
        'data_in': 1,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'enable': 0,
        'load': 0,
        'load_state': 0,
        'data_in': 0,
      }, {
        'state': 1,
        'next_state': 2,
      }),
    ];

    await SimCompare.checkFunctionalVector(recurrence, vectors);
    SimCompare.checkIverilogVector(recurrence, vectors);
  });

  test(
      'autonomous recurrence supports asynchronous reset and load-only control',
      () async {
    final recurrence = BinaryLinearRecurrence(
      clk: Logic(),
      reset: Logic(),
      load: Logic(),
      loadState: Logic(width: 3),
      descriptor: BinaryLinearRecurrenceDescriptor(
        stateMatrix: BinaryMatrix(
          [BigInt.from(4), BigInt.one, BigInt.from(2)],
          columnCount: 3,
        ),
        offset: BigInt.one,
      ),
      initialState: BigInt.from(2),
      asyncReset: true,
      radix: 3,
    );
    await recurrence.build();

    final vectors = [
      Vector({
        'clk': 0,
        'reset': 0,
        'load': 0,
        'load_state': 0,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 1,
        'load': 0,
        'load_state': 0,
      }, {
        'state': 2,
        'next_state': 5,
      }),
      Vector({
        'clk': 0,
        'reset': 0,
        'load': 0,
        'load_state': 0,
      }, {
        'state': 2,
        'next_state': 5,
      }),
      Vector({
        'clk': 1,
        'reset': 0,
        'load': 0,
        'load_state': 0,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'load': 0,
        'load_state': 0,
      }, {
        'state': 5,
        'next_state': 2,
      }),
      Vector({
        'clk': 0,
        'reset': 0,
        'load': 1,
        'load_state': 6,
      }, {}),
      Vector({
        'clk': 1,
        'reset': 0,
        'load': 1,
        'load_state': 6,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'load': 0,
        'load_state': 0,
      }, {
        'state': 6,
        'next_state': 4,
      }),
      Vector({
        'clk': 0,
        'reset': 1,
        'load': 0,
        'load_state': 0,
      }, {
        'state': 2,
        'next_state': 5,
      }),
    ];

    await SimCompare.checkFunctionalVector(recurrence, vectors);
    SimCompare.checkIverilogVector(recurrence, vectors);
  });

  test('enable-only recurrence holds and advances in generated RTL', () async {
    final recurrence = BinaryLinearRecurrence(
      clk: Logic(),
      reset: Logic(),
      enable: Logic(),
      dataIn: Logic(),
      descriptor: BinaryLinearRecurrenceDescriptor(
        stateMatrix: BinaryMatrix.identity(2),
        inputMatrix: BinaryMatrix([BigInt.one, BigInt.one], columnCount: 1),
      ),
    );
    await recurrence.build();

    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'enable': 0,
        'data_in': 0,
      }, {}),
      Vector({
        'clk': 1,
        'reset': 1,
        'enable': 0,
        'data_in': 0,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'enable': 0,
        'data_in': 1,
      }, {
        'state': 0,
        'next_state': 3,
      }),
      Vector({
        'clk': 1,
        'reset': 0,
        'enable': 0,
        'data_in': 1,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'enable': 1,
        'data_in': 1,
      }, {
        'state': 0,
        'next_state': 3,
      }),
      Vector({
        'clk': 1,
        'reset': 0,
        'enable': 1,
        'data_in': 1,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'enable': 0,
        'data_in': 0,
      }, {
        'state': 3,
        'next_state': 3,
      }),
    ];

    await SimCompare.checkFunctionalVector(recurrence, vectors);
    SimCompare.checkIverilogVector(recurrence, vectors);
  });

  test('validates recurrence ports and controls', () {
    final descriptor = BinaryLinearRecurrenceDescriptor(
      stateMatrix: BinaryMatrix.identity(3),
      inputMatrix: BinaryMatrix(
        [BigInt.one, BigInt.zero, BigInt.zero],
        columnCount: 1,
      ),
    );

    expect(
      () => BinaryLinearRecurrence(
        clk: Logic(),
        descriptor: descriptor,
      ),
      throwsA(isA<RohdHclException>()),
    );
    expect(
      () => BinaryLinearRecurrence(
        clk: Logic(),
        dataIn: Logic(),
        load: Logic(),
        descriptor: descriptor,
      ),
      throwsA(isA<RohdHclException>()),
    );
    expect(
      () => BinaryLinearRecurrence(
        clk: Logic(),
        dataIn: Logic(),
        reset: Logic(),
        initialState: BigInt.from(8),
        descriptor: descriptor,
      ),
      throwsA(isA<RohdHclException>()),
    );
  });
}
