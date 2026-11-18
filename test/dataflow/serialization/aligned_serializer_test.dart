// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// aligned_serializer_test.dart
// Tests for aligned serializer timing.
//
// 2026 November 14
// Author: Desmond Kirkpatrick <desmond.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _SerializerPair extends Module {
  _SerializerPair() {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final enable = addInput('enable', Logic());
    final data = addTypedInput('dataIn', LogicArray([2], 8));
    final direct = Serializer(data, clk: clk, reset: reset, enable: enable);
    final aligned = Serializer(data,
        clk: clk,
        reset: reset,
        enable: enable,
        flopInput: true,
        alignOutputLatency: true);

    addOutput('directData', width: 8) <= direct.serialized;
    addOutput('alignedData', width: 8) <= aligned.serialized;
    addOutput('directCount', width: direct.count.width) <= direct.count;
    addOutput('alignedCount', width: aligned.count.width) <= aligned.count;
    addOutput('directDone') <= direct.done;
    addOutput('alignedDone') <= aligned.done;
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('aligned serializer bypasses the first element and captures the rest',
      () async {
    final tx = Serializer(LogicArray([3], 8),
        clk: Logic(),
        reset: Logic(),
        enable: Logic(),
        endCount: Logic(width: 2),
        flopInput: true,
        alignOutputLatency: true);
    await tx.build();

    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'enable': 0,
        'endCount': 2,
        'deserialized': 0x332211
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0
      }, {
        'serialized': 0x11,
        'count': 0,
        'done': 0,
      }),
      Vector({'clk': 1}, {'serialized': 0x11, 'count': 0, 'done': 0}),
      Vector({'clk': 0, 'enable': 1}, {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'enable': 0,
        'deserialized': 0x998877
      }, {
        'serialized': 0x22,
        'count': 1,
        'done': 0,
      }),
      Vector({'clk': 1}, {'serialized': 0x22, 'count': 1, 'done': 0}),
      Vector({'clk': 0, 'enable': 1}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0}, {'serialized': 0x33, 'count': 2, 'done': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0}, {'serialized': 0x77, 'count': 0, 'done': 0}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'endCount': 1,
        'deserialized': 0xccbbaa
      }, {
        'serialized': 0x88,
        'count': 1,
        'done': 1,
      }),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'endCount': 0
      }, {
        'serialized': 0x99,
        'count': 2,
        'done': 1,
      }),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0
      }, {
        'serialized': 0xaa,
        'count': 0,
        'done': 1,
      }),
    ];
    await SimCompare.checkFunctionalVector(tx, vectors);
    SimCompare.checkIverilogVector(tx, vectors);
  });

  test('aligned single-element serializer keeps the input live', () async {
    final tx = Serializer(LogicArray([1], 8),
        clk: Logic(),
        reset: Logic(),
        enable: Logic(),
        flopInput: true,
        alignOutputLatency: true);
    await tx.build();
    final vectors = [
      Vector({'clk': 0, 'reset': 1, 'enable': 0, 'deserialized': 0x12}, {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0
      }, {
        'serialized': 0x12,
        'count': 0,
        'done': 1,
      }),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'enable': 1,
        'deserialized': 0x34
      }, {
        'serialized': 0x34,
        'count': 0,
        'done': 1,
      }),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'deserialized': 0x56
      }, {
        'serialized': 0x56,
        'count': 0,
        'done': 1,
      }),
    ];
    await SimCompare.checkFunctionalVector(tx, vectors);
    SimCompare.checkIverilogVector(tx, vectors);
  });

  for (final flopInput in [false, true]) {
    test('aligned option with no enable and flopInput=$flopInput', () async {
      final tx = Serializer(LogicArray([2], 8),
          clk: Logic(),
          reset: Logic(),
          flopInput: flopInput,
          alignOutputLatency: true);
      await tx.build();
      final vectors = [
        Vector({'clk': 0, 'reset': 1, 'deserialized': 0x2211}, {}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'reset': 0},
            {'serialized': 0x11, 'count': 0, 'done': 0}),
        Vector({'clk': 1}, {}),
        Vector({
          'clk': 0,
          'deserialized': 0x4433
        }, {
          'serialized': flopInput ? 0x22 : 0x44,
          'count': 1,
          'done': 1,
        }),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0}, {'serialized': 0x33, 'count': 0, 'done': 0}),
      ];
      await SimCompare.checkFunctionalVector(tx, vectors);
      SimCompare.checkIverilogVector(tx, vectors);
    });
  }

  test('direct and aligned instances have matching timing in generated RTL',
      () async {
    final pair = _SerializerPair();
    await pair.build();
    final vectors = [
      Vector({'clk': 0, 'reset': 1, 'enable': 0, 'dataIn': 0x2211}, {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'enable': 1
      }, {
        'directData': 0x11,
        'alignedData': 0x11,
        'directCount': 0,
        'alignedCount': 0,
        'directDone': 0,
        'alignedDone': 0,
      }),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'dataIn': 0x4433
      }, {
        'directData': 0x44,
        'alignedData': 0x22,
        'directCount': 1,
        'alignedCount': 1,
        'directDone': 1,
        'alignedDone': 1,
      }),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0
      }, {
        'directData': 0x33,
        'alignedData': 0x33,
        'directCount': 0,
        'alignedCount': 0,
        'directDone': 0,
        'alignedDone': 0,
      }),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 1}, {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'enable': 0
      }, {
        'directData': 0x33,
        'alignedData': 0x33,
        'directCount': 0,
        'alignedCount': 0,
        'directDone': 0,
        'alignedDone': 0,
      }),
    ];
    await SimCompare.checkFunctionalVector(pair, vectors);
    SimCompare.checkIverilogVector(pair, vectors);
  });
}
