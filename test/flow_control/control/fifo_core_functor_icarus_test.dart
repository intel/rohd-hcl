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

class _SplitPayload extends LogicStructure {
  final int firstWidth;
  final int secondWidth;

  _SplitPayload(
    this.firstWidth,
    this.secondWidth, {
    required String name,
  }) : super(
          [
            Logic(name: 'first', width: firstWidth),
            Logic(name: 'second', width: secondWidth),
          ],
          name: name,
        );

  @override
  _SplitPayload clone({String? name}) => _SplitPayload(
        firstWidth,
        secondWidth,
        name: name ?? this.name,
      );
}

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

class _ShapeIdentityIcarusHarness extends Module {
  late final FifoCoreBinding<_SplitPayload> first;
  late final FifoCoreBinding<_SplitPayload> repeated;
  late final FifoCoreBinding<_SplitPayload> distinct;

  _ShapeIdentityIcarusHarness()
      : super(definitionName: 'FifoShapeIdentityIcarusHarness') {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final enqueue = addInput('enqueue', Logic());
    final dequeue = addInput('dequeue', Logic());
    final functor = FifoCoreFunctor<_SplitPayload>(depth: 2);

    FifoCoreBinding<_SplitPayload> construct(
      String portName,
      _SplitPayload source,
      String moduleName,
    ) =>
        functor.construct(
          FifoCoreRequest<_SplitPayload>(
            clk: clk,
            reset: reset,
            enqueue: enqueue,
            dequeue: dequeue,
            payload: addTypedInput(portName, source),
          ),
          name: moduleName,
        );

    first = construct(
      'firstPayload',
      _SplitPayload(4, 4, name: 'first_root'),
      'first_fifo',
    );
    repeated = construct(
      'repeatedPayload',
      _SplitPayload(4, 4, name: 'different_root'),
      'repeated_fifo',
    );
    distinct = construct(
      'distinctPayload',
      _SplitPayload(2, 6, name: 'third_root'),
      'distinct_fifo',
    );
    addOutput('firstValid') <= first.outputValid;
    addOutput('repeatedValid') <= repeated.outputValid;
    addOutput('distinctValid') <= distinct.outputValid;
  }
}

class _InitializedFifoHarness extends Module {
  _InitializedFifoHarness({
    required int depth,
    required List<int> initialValues,
  }) : super(definitionName: 'InitializedFifoHarness_D$depth') {
    final fifo = Fifo<Logic>(
      addInput('clk', Logic()),
      addInput('reset', Logic()),
      writeEnable: addInput('writeEnable', Logic()),
      writeData: addInput('writeData', Logic(width: 8), width: 8),
      readEnable: addInput('readEnable', Logic()),
      depth: depth,
      generateOccupancy: true,
      initialValues: initialValues,
    );
    addOutput('canEnqueue') <= fifo.canEnqueue;
    addOutput('valid') <= fifo.outputValid;
    addOutput('data', width: 8) <= fifo.readData;
    addOutput('full') <= fifo.full;
    addOutput('empty') <= fifo.empty;
    addOutput('slotReleased') <= fifo.slotReleased;
    addOutput('occupancy', width: fifo.occupancy!.width) <= fifo.occupancy!;
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
          contains('FifoCore_fifo_core_D${depth}_R1_B0_S1_O0_E0_PL8_W8'),
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

  test('payload shape identities merge and compile in one hierarchy', () async {
    final harness = _ShapeIdentityIcarusHarness();
    await harness.build();
    final firstDefinition = harness.first.module.definitionName;
    final repeatedDefinition = harness.repeated.module.definitionName;
    final distinctDefinition = harness.distinct.module.definitionName;
    expect(firstDefinition, repeatedDefinition);
    expect(firstDefinition, isNot(distinctDefinition));

    final systemVerilog = harness.generateSynth();
    expect(
      RegExp('module ${RegExp.escape(firstDefinition)}\\b')
          .allMatches(systemVerilog),
      hasLength(1),
    );
    expect(
      RegExp('module ${RegExp.escape(distinctDefinition)}\\b')
          .allMatches(systemVerilog),
      hasLength(1),
    );

    final directory = Directory('build/p00_fifo_core_icarus/shape_identity');
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
    directory.createSync(recursive: true);
    final source = File('${directory.path}/shape_identity.sv');
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
  }, skip: _iverilogUnavailableReason());

  for (final depth in [1, 3]) {
    test('initialized depth $depth replacement matches generated RTL',
        () async {
      final initialValues = [
        for (var index = 0; index < depth; index++) 0x20 + index,
      ];
      final replacement = 0x70 + depth;
      final harness = _InitializedFifoHarness(
        depth: depth,
        initialValues: initialValues,
      );
      await harness.build();
      final vectors = <Vector>[
        Vector(
          {
            'clk': 0,
            'reset': 1,
            'writeEnable': 0,
            'readEnable': 0,
            'writeData': 0,
          },
          {},
        ),
        Vector(
          {
            'clk': 1,
            'reset': 1,
            'writeEnable': 0,
            'readEnable': 0,
            'writeData': 0,
          },
          {},
        ),
        Vector(
          {
            'clk': 0,
            'reset': 0,
            'writeEnable': 1,
            'readEnable': 1,
            'writeData': replacement,
          },
          {
            'full': 1,
            'empty': 0,
            'valid': 1,
            'data': initialValues.first,
            'canEnqueue': 1,
            'slotReleased': 1,
            'occupancy': depth,
          },
        ),
        Vector(
          {
            'clk': 1,
            'reset': 0,
            'writeEnable': 1,
            'readEnable': 1,
            'writeData': replacement,
          },
          {},
        ),
        for (final (index, value)
            in [...initialValues.skip(1), replacement].indexed) ...[
          Vector(
            {
              'clk': 0,
              'reset': 0,
              'writeEnable': 0,
              'readEnable': 1,
              'writeData': 0,
            },
            {
              'full': index == 0 ? 1 : 0,
              'empty': 0,
              'valid': 1,
              'data': value,
              'slotReleased': 1,
              'occupancy': depth - index,
            },
          ),
          Vector(
            {
              'clk': 1,
              'reset': 0,
              'writeEnable': 0,
              'readEnable': 1,
              'writeData': 0,
            },
            {},
          ),
        ],
        Vector(
          {
            'clk': 0,
            'reset': 0,
            'writeEnable': 0,
            'readEnable': 0,
            'writeData': 0,
          },
          {
            'full': 0,
            'empty': 1,
            'valid': 0,
            'canEnqueue': 1,
            'slotReleased': 0,
            'occupancy': 0,
          },
        ),
      ];

      await SimCompare.checkFunctionalVector(harness, vectors);
      SimCompare.checkIverilogVector(harness, vectors);
    }, skip: _iverilogUnavailableReason());
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
