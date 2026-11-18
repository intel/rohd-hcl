// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_queue_icarus_test.dart
// Generated RTL coverage for ready/valid queues.
//
// 2026 November 5
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _NamedPacket extends LogicStructure {
  final String suffix;

  _NamedPacket({required String name, this.suffix = 'payload'})
      : super([Logic(name: '${name}_$suffix', width: 8)], name: name);

  @override
  _NamedPacket clone({String? name}) =>
      _NamedPacket(name: name ?? this.name, suffix: suffix);
}

class _NamedBufferHarness extends Module {
  _NamedBufferHarness({ReadyValidQueueStorage? storage}) {
    final upstream = ReadyValidInterface(_NamedPacket(name: 'incoming'));
    final downstream = ReadyValidInterface(_NamedPacket(name: 'outgoing'));
    upstream.data <= addInput('data', Logic(width: 8), width: 8);
    upstream.valid <= addInput('valid', Logic());
    downstream.ready <= addInput('ready', Logic());
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final Logic full;
    if (storage == null) {
      full = ReadyValidFallThroughBuffer<_NamedPacket>(
              clk: clk,
              reset: reset,
              upstream: upstream,
              downstream: downstream)
          .full;
    } else {
      full = ReadyValidQueue<_NamedPacket>(
              clk: clk,
              reset: reset,
              upstream: upstream,
              downstream: downstream,
              depth: 1,
              policy: ReadyValidQueuePolicy.fallThrough,
              storage: storage)
          .full;
    }
    addOutput('out', width: 8) <= downstream.data;
    addOutput('outValid') <= downstream.valid;
    addOutput('inReady') <= upstream.ready;
    addOutput('full') <= full;
  }
}

class _QueueHarness extends Module {
  _QueueHarness(ReadyValidQueueStorage storage, ReadyValidQueuePolicy policy) {
    final upstream = ReadyValidInterface(Logic(name: 'input', width: 8));
    final downstream = ReadyValidInterface(Logic(name: 'output', width: 8));
    upstream.data <= addInput('data', Logic(width: 8), width: 8);
    upstream.valid <= addInput('valid', Logic());
    downstream.ready <= addInput('ready', Logic());
    final queue = ReadyValidQueue<Logic>(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      upstream: upstream,
      downstream: downstream,
      depth: 1,
      policy: policy,
      storage: storage,
    );
    addOutput('out', width: 8) <= downstream.data;
    addOutput('outValid') <= downstream.valid;
    addOutput('inReady') <= upstream.ready;
    addOutput('full') <= queue.full;
  }
}

void main() {
  tearDown(Simulator.reset);

  for (final storage in [null, ...ReadyValidQueueStorage.values]) {
    test('$storage fall-through preserves parent-renamed packets under stall',
        () async {
      final dut = _NamedBufferHarness(storage: storage);
      final vectors = [
        Vector({'clk': 0, 'reset': 1, 'data': 17, 'valid': 0, 'ready': 0}, {}),
        Vector({'clk': 1}, {'full': 0}),
        Vector({'clk': 0, 'reset': 0, 'valid': 1},
            {'inReady': 1, 'outValid': 1, 'out': 17}),
        Vector({'clk': 1}, {'full': 1, 'outValid': 1, 'out': 17}),
        Vector({'clk': 0, 'data': 34, 'valid': 0},
            {'inReady': 0, 'outValid': 1, 'out': 17}),
        Vector({'ready': 1}, {'inReady': 1, 'outValid': 1, 'out': 17}),
        Vector({'clk': 1}, {'full': 0, 'outValid': 0}),
      ];
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  test('single-entry buffer checks declared packets across a packed bridge',
      () {
    for (final mode in SingleEntryBufferMode.values) {
      for (var packedIndex = 0; packedIndex < 3; packedIndex++) {
        final payloads = <Logic>[
          _NamedPacket(name: 'incoming'),
          _NamedPacket(name: 'outgoing', suffix: 'different'),
        ]..insert(packedIndex, Logic(width: 8));
        expect(
            () => configureSingleEntryBuffer<Logic>(
                  clk: Logic(),
                  reset: Logic(),
                  occupied: Logic(),
                  upstream: ReadyValidInterface(payloads[0]),
                  downstream: IrrevocableReadyValidInterface(payloads[1]),
                  storedData: payloads[2],
                  mode: mode,
                  name: 'buffer',
                ),
            throwsA(isA<PortTypeException>()));
        final compatible = <Logic>[
          _NamedPacket(name: 'incoming'),
          _NamedPacket(name: 'outgoing'),
        ]..insert(packedIndex, Logic(width: 8));
        expect(
            () => configureSingleEntryBuffer<Logic>(
                  clk: Logic(),
                  reset: Logic(),
                  occupied: Logic(),
                  upstream: ReadyValidInterface(compatible[0]),
                  downstream: IrrevocableReadyValidInterface(compatible[1]),
                  storedData: compatible[2],
                  mode: mode,
                  name: 'buffer',
                ),
            returnsNormally);
      }
      expect(
          () => configureSingleEntryBuffer<_NamedPacket>(
                clk: Logic(),
                reset: Logic(),
                occupied: Logic(),
                upstream: ReadyValidInterface(_NamedPacket(name: 'incoming')),
                downstream: IrrevocableReadyValidInterface(
                    _NamedPacket(name: 'outgoing')),
                storedData: _NamedPacket(name: 'stored'),
                mode: mode,
                name: 'buffer',
              ),
          returnsNormally);
    }
  });

  for (final storage in ReadyValidQueueStorage.values) {
    for (final policy in ReadyValidQueuePolicy.values) {
      test('$storage $policy matches Icarus on full replacement', () async {
        final dut = _QueueHarness(storage, policy);
        final vectors = [
          Vector(
              {'clk': 0, 'reset': 1, 'data': 17, 'valid': 0, 'ready': 0}, {}),
          Vector({'clk': 1}, {'full': 0}),
          Vector({'clk': 0, 'reset': 0, 'valid': 1}, {'inReady': 1}),
          Vector({'clk': 1}, {'full': 1, 'outValid': 1, 'out': 17}),
          Vector({'clk': 0, 'data': 34, 'ready': 1}, {'inReady': 1, 'out': 17}),
          Vector({'clk': 1}, {'full': 1, 'out': 34}),
          Vector({'clk': 0, 'valid': 0}, {}),
          Vector({'clk': 1}, {'full': 0, 'outValid': 0}),
        ];
        await dut.build();
        await SimCompare.checkFunctionalVector(dut, vectors);
        SimCompare.checkIverilogVector(dut, vectors);
      });
    }
  }
}
