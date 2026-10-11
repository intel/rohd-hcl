// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fifo_core_functor_icarus_test.dart
// Generated-RTL checks for the FIFO construction foundation.
//
// 2026 October 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _NestedFifoHarness extends Module {
  _NestedFifoHarness({
    required int depth,
    bool generateBypass = false,
  }) : super(
          definitionName: 'NestedFifoFunctorHarness_D${depth}_'
              'B${generateBypass ? 1 : 0}',
        ) {
    final fifo = FifoCoreFunctor<Logic>(
      depth: depth,
      generateBypass: generateBypass,
    ).construct(
      FifoCoreRequest<Logic>(
        clk: addInput('clk', Logic()),
        reset: addInput('reset', Logic()),
        enqueue: addInput('enqueue', Logic()),
        dequeue: addInput('dequeue', Logic()),
        payload: addInput('payload', Logic(width: 8), width: 8),
        requirements: FifoCoreRequirements(
          fullReplacement: true,
          emptyBypass: generateBypass,
        ),
      ),
      name: 'fifo_core',
    );

    addOutput('canEnqueue') <= fifo.canEnqueue;
    addOutput('valid') <= fifo.outputValid;
    addOutput('data', width: 8) <= fifo.output;
    addOutput('full') <= fifo.full;
    addOutput('empty') <= fifo.empty;
    addOutput('slotReleased') <= fifo.slotReleased;
  }
}

void main() {
  tearDown(Simulator.reset);

  for (final depth in [1, 2, 4]) {
    test(
      'depth $depth nested hierarchy generates Icarus-compatible RTL',
      () async {
        final harness = _NestedFifoHarness(depth: depth);
        await harness.build();
        expect(harness.hierarchyString(), contains('fifo_core'));
        final systemVerilog = harness.generateSynth();
        expect(
          systemVerilog,
          contains('FifoCore_fifo_core_D${depth}_R1_B0_S1_O0_E0_W8'),
        );

        final directory = Directory(
          'build/p00_fifo_core_icarus/depth_$depth',
        );
        if (directory.existsSync()) {
          directory.deleteSync(recursive: true);
        }
        directory.createSync(recursive: true);
        final source = File('${directory.path}/fifo_core.sv');
        try {
          source.writeAsStringSync(systemVerilog);
          final result = Process.runSync('iverilog', [
            '-g2012',
            '-tnull',
            source.path,
          ]);
          expect(
            result.exitCode,
            0,
            reason: '${result.stdout}\n${result.stderr}',
          );
        } finally {
          directory.deleteSync(recursive: true);
        }
      },
      skip: _iverilogUnavailableReason(),
    );
  }

  test('full replacement matches generated RTL', () async {
    final harness = _NestedFifoHarness(depth: 1);
    await harness.build();
    final vectors = [
      Vector(
        {
          'clk': 0,
          'reset': 1,
          'enqueue': 0,
          'dequeue': 0,
          'payload': 0,
        },
        {},
      ),
      Vector(
        {
          'clk': 1,
          'reset': 1,
          'enqueue': 0,
          'dequeue': 0,
          'payload': 0,
        },
        {},
      ),
      Vector(
        {
          'clk': 0,
          'reset': 0,
          'enqueue': 1,
          'dequeue': 0,
          'payload': 0x11,
        },
        {'full': 0, 'valid': 0, 'canEnqueue': 1},
      ),
      Vector(
        {
          'clk': 1,
          'reset': 0,
          'enqueue': 1,
          'dequeue': 0,
          'payload': 0x11,
        },
        {},
      ),
      Vector(
        {
          'clk': 0,
          'reset': 0,
          'enqueue': 1,
          'dequeue': 1,
          'payload': 0x22,
        },
        {
          'full': 1,
          'valid': 1,
          'data': 0x11,
          'canEnqueue': 1,
          'slotReleased': 1,
        },
      ),
      Vector(
        {
          'clk': 1,
          'reset': 0,
          'enqueue': 1,
          'dequeue': 1,
          'payload': 0x22,
        },
        {},
      ),
      Vector(
        {
          'clk': 0,
          'reset': 0,
          'enqueue': 0,
          'dequeue': 1,
          'payload': 0,
        },
        {
          'full': 1,
          'valid': 1,
          'data': 0x22,
          'slotReleased': 1,
        },
      ),
      Vector(
        {
          'clk': 1,
          'reset': 0,
          'enqueue': 0,
          'dequeue': 1,
          'payload': 0,
        },
        {},
      ),
      Vector(
        {
          'clk': 0,
          'reset': 0,
          'enqueue': 0,
          'dequeue': 0,
          'payload': 0,
        },
        {
          'empty': 1,
          'valid': 0,
          'canEnqueue': 1,
          'slotReleased': 0,
        },
      ),
    ];

    await SimCompare.checkFunctionalVector(harness, vectors);
    SimCompare.checkIverilogVector(harness, vectors);
  }, skip: _iverilogUnavailableReason());

  test('empty bypass matches generated RTL', () async {
    final harness = _NestedFifoHarness(depth: 2, generateBypass: true);
    await harness.build();
    final vectors = [
      Vector(
        {
          'clk': 0,
          'reset': 1,
          'enqueue': 0,
          'dequeue': 0,
          'payload': 0,
        },
        {},
      ),
      Vector(
        {
          'clk': 1,
          'reset': 1,
          'enqueue': 0,
          'dequeue': 0,
          'payload': 0,
        },
        {},
      ),
      Vector(
        {
          'clk': 0,
          'reset': 0,
          'enqueue': 1,
          'dequeue': 1,
          'payload': 0x5a,
        },
        {
          'empty': 1,
          'valid': 1,
          'data': 0x5a,
          'canEnqueue': 1,
          'slotReleased': 0,
        },
      ),
      Vector(
        {
          'clk': 1,
          'reset': 0,
          'enqueue': 1,
          'dequeue': 1,
          'payload': 0x5a,
        },
        {},
      ),
      Vector(
        {
          'clk': 0,
          'reset': 0,
          'enqueue': 0,
          'dequeue': 0,
          'payload': 0,
        },
        {'empty': 1, 'valid': 0, 'slotReleased': 0},
      ),
    ];

    await SimCompare.checkFunctionalVector(harness, vectors);
    SimCompare.checkIverilogVector(harness, vectors);
  }, skip: _iverilogUnavailableReason());
}

String? _iverilogUnavailableReason() {
  try {
    final result = Process.runSync('iverilog', const ['-V']);
    return result.exitCode == 0 ? null : 'Icarus Verilog is unavailable.';
  } on ProcessException {
    return 'Icarus Verilog is not installed.';
  }
}
