// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_fixed_latency_test.dart
// Tests for generic fixed-latency scheduling and transport.
//
// 2026 November 15
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Compute extends Module {
  Logic get result => output('result');

  _Compute({
    required Logic clk,
    required Logic reset,
    required Logic start,
    required Logic data,
    required int latency,
  }) : super(definitionName: 'TestFixedCore_L$latency') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    start = addInput('start', start);
    data = addInput('data', data, width: 8);
    var value = mux(start, data ^ Const(0xa5, width: 8), Const(0, width: 8));
    for (var stage = 0; stage < latency; stage++) {
      value = flop(clk, value, reset: reset);
    }
    addOutput('result', width: 8) <= value;
  }
}

class _MultiCycleCompute extends Module {
  Logic get result => output('result');

  _MultiCycleCompute({
    required Logic clk,
    required Logic reset,
    required Logic start,
    required Logic data,
  }) : super(definitionName: 'TestMultiCycleCore') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    start = addInput('start', start);
    data = addInput('data', data, width: 8);
    final saved = Logic(name: 'saved', width: 8);
    final remaining = Logic(name: 'remaining', width: 2);
    final result = addOutput('result', width: 8);
    Sequential(clk, reset: reset, resetValues: {
      saved: 0,
      remaining: 0,
      result: 0,
    }, [
      If(start, then: [
        saved < data,
        remaining < 2,
      ], orElse: [
        If(remaining.eq(1), then: [
          result < (saved ^ Const(0xa5, width: 8)),
          remaining < 0,
        ], orElse: [
          If(remaining.or(), then: [remaining < remaining - 1])
        ])
      ])
    ]);
  }
}

class _Packet extends LogicStructure {
  Logic get low => elements[0];
  Logic get high => elements[1];

  _Packet({String name = 'packet'})
      : super([Logic(name: 'low', width: 4), Logic(name: 'high', width: 4)],
            name: name);

  @override
  _Packet clone({String? name}) => _Packet(name: name ?? this.name);
}

class _Tag extends LogicStructure {
  Logic get lane => elements[0];
  Logic get group => elements[1];

  _Tag({String name = 'tag'})
      : super([Logic(name: 'lane', width: 2), Logic(name: 'group', width: 2)],
            name: name);

  @override
  _Tag clone({String? name}) => _Tag(name: name ?? this.name);
}

class _TypedHarness extends Module {
  late final ReadyValidFixedLatency<_Packet, _Packet, _Tag> wrapper;

  _TypedHarness({int latency = 0}) {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final low = addInput('low', Logic(width: 4), width: 4);
    final high = addInput('high', Logic(width: 4), width: 4);
    final valid = addInput('valid', Logic());
    final ready = addInput('ready', Logic());
    final id = _Tag()..gets(addInput('id', Logic(width: 4), width: 4));
    final upstream = ReadyValidInterface(_Packet());
    final downstream = ReadyValidInterface(_Packet());
    upstream.data.low <= low;
    upstream.data.high <= high;
    upstream.valid <= valid;
    downstream.ready <= ready;
    wrapper = ReadyValidFixedLatency<_Packet, _Packet, _Tag>(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstream: downstream,
      requestId: id,
      latency: latency,
      coreIdentity: 'TypedIdentity_L$latency',
      coreGenerator: ({
        required clk,
        required reset,
        required start,
        required data,
      }) {
        var result = data;
        for (var stage = 0; stage < latency; stage++) {
          result = flop(clk, result);
        }
        return result;
      },
    );
    addOutput('input_ready') <= upstream.ready;
    addOutput('output_valid') <= downstream.valid;
    addOutput('low_result', width: 4) <= downstream.data.low;
    addOutput('high_result', width: 4) <= downstream.data.high;
    addOutput('result_id', width: 4) <= wrapper.resultId!;
    addOutput('id_lane', width: 2) <= wrapper.resultId!.lane;
    addOutput('error') <= wrapper.error;
  }
}

typedef _ArrayId = TypedLogicArray<Logic, LogicValue>;

_ArrayId _arrayId() =>
    _ArrayId([2], ({name}) => Logic(name: name ?? 'part', width: 2),
        numUnpackedDimensions: 1);

class _ArrayIdHarness extends Module {
  late final ReadyValidFixedLatency<Logic, Logic, _ArrayId> wrapper;

  _ArrayIdHarness() {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final upstream = ReadyValidInterface(Logic(width: 8));
    final downstream = ReadyValidInterface(Logic(width: 8));
    upstream.data <= addInput('data', Logic(width: 8), width: 8);
    upstream.valid <= addInput('valid', Logic());
    downstream.ready <= addInput('ready', Logic());
    final id = _arrayId()..gets(addInput('id', Logic(width: 4), width: 4));
    wrapper = ReadyValidFixedLatency<Logic, Logic, _ArrayId>(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstream: downstream,
      requestId: id,
      latency: 1,
      coreIdentity: 'ArrayId',
      coreGenerator: ({
        required clk,
        required reset,
        required start,
        required data,
      }) =>
          flop(clk, data),
    );
    addOutput('result', width: 8) <= downstream.data;
    addOutput('output_valid') <= downstream.valid;
    addOutput('result_id', width: 4) <= wrapper.resultId!.packed;
    addOutput('id_first', width: 2) <= wrapper.resultId!.arrayElements[0];
  }
}

class _WidenedArrayIdHarness extends Module {
  late final ReadyValidFixedLatency<Logic, Logic, Logic> wrapper;

  _WidenedArrayIdHarness() {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final upstream = ReadyValidInterface(Logic(width: 8));
    final downstream = ReadyValidInterface(Logic(width: 8));
    upstream.data <= addInput('data', Logic(width: 8), width: 8);
    upstream.valid <= addInput('valid', Logic());
    downstream.ready <= addInput('ready', Logic());
    final id = _arrayId()..gets(addInput('id', Logic(width: 4), width: 4));
    wrapper = ReadyValidFixedLatency<Logic, Logic, Logic>(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstream: downstream,
      requestId: id,
      latency: 1,
      coreIdentity: 'WidenedArrayId',
      coreGenerator: ({
        required clk,
        required reset,
        required start,
        required data,
      }) =>
          flop(clk, data),
    );
    addOutput('result', width: 8) <= downstream.data;
    addOutput('output_valid') <= downstream.valid;
    addOutput('result_id', width: 4) <= wrapper.resultId!;
  }
}

class _ConstantIdHarness extends Module {
  late final ReadyValidFixedLatency<Logic, Logic, Logic> wrapper;

  _ConstantIdHarness() {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final upstream = ReadyValidInterface(Logic(width: 8));
    final downstream = ReadyValidInterface(Logic(width: 8));
    upstream.data <= addInput('data', Logic(width: 8), width: 8);
    upstream.valid <= addInput('valid', Logic());
    downstream.ready <= addInput('ready', Logic());
    final id = FixedPoint.constant(FixedPointValue.withSignedness(
        integer: LogicValue.ofInt(5, 3), fraction: LogicValue.ofInt(0, 1)));
    wrapper = ReadyValidFixedLatency<Logic, Logic, Logic>(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstream: downstream,
      requestId: id,
      latency: 1,
      coreIdentity: 'ConstantId',
      coreGenerator: ({
        required clk,
        required reset,
        required start,
        required data,
      }) =>
          flop(clk, data),
    );
    addOutput('result', width: 8) <= downstream.data;
    addOutput('output_valid') <= downstream.valid;
    addOutput('result_id', width: 4) <= wrapper.resultId!;
  }
}

class _ConstantCoreHarness extends Module {
  _ConstantCoreHarness() {
    final upstream = ReadyValidInterface(Logic(width: 8));
    final downstream =
        ReadyValidInterface(FixedPoint(integerWidth: 3, fractionWidth: 4));
    upstream.data <= addInput('data', Logic(width: 8), width: 8);
    upstream.valid <= addInput('valid', Logic());
    downstream.ready <= addInput('ready', Logic());
    ReadyValidFixedLatency<Logic, FixedPoint, Logic>(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      upstream: upstream,
      downstream: downstream,
      latency: 0,
      coreIdentity: 'ConstantCore',
      coreGenerator: ({
        required clk,
        required reset,
        required start,
        required data,
      }) =>
          FixedPoint.constant(FixedPointValue.withSignedness(
              integer: LogicValue.ofInt(3, 4),
              fraction: LogicValue.ofInt(1, 4))),
    );
    addOutput('result', width: 8) <= downstream.data;
    addOutput('output_valid') <= downstream.valid;
  }
}

class _Harness extends Module {
  _Harness({
    required int latency,
    required int initiationInterval,
    required int capacity,
    required bool withId,
    bool multiCycle = false,
  }) : super(
            definitionName: 'TestFixedHarness_L${latency}_'
                'I${initiationInterval}_C${capacity}_Id${withId ? 1 : 0}') {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final request = addInput('request', Logic(width: 8), width: 8);
    final valid = addInput('valid', Logic());
    final ready = addInput('ready', Logic());
    final id = withId ? addInput('id', Logic(width: 4), width: 4) : null;
    final upstream = ReadyValidInterface(Logic(name: 'input', width: 8));
    final downstream = ReadyValidInterface(Logic(name: 'output', width: 8));
    upstream.data <= request;
    upstream.valid <= valid;
    downstream.ready <= ready;
    final wrapper = ReadyValidFixedLatency<Logic, Logic, Logic>(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstream: downstream,
      requestId: id,
      latency: latency,
      initiationInterval: initiationInterval,
      capacity: capacity,
      coreIdentity: multiCycle ? 'TestMultiCycleCore' : 'TestCore_L$latency',
      coreGenerator: ({
        required clk,
        required reset,
        required start,
        required data,
      }) =>
          multiCycle
              ? _MultiCycleCompute(
                      clk: clk, reset: reset, start: start, data: data)
                  .result
              : _Compute(
                      clk: clk,
                      reset: reset,
                      start: start,
                      data: data,
                      latency: latency)
                  .result,
    );
    addOutput('input_ready') <= upstream.ready;
    addOutput('output_valid') <= downstream.valid;
    addOutput('result', width: 8) <= downstream.data;
    if (withId) {
      addOutput('result_id', width: 4) <= wrapper.resultId!;
    }
    addOutput('error') <= wrapper.error;
  }
}

typedef _Transaction = ({int data, int id});

void main() {
  tearDown(Simulator.reset);

  test('result queue preserves structured payloads with and without IDs',
      () async {
    for (final withId in [false, true]) {
      final wrapper = ReadyValidFixedLatency<_Packet, _Packet, Logic>(
        clk: Logic(),
        reset: Logic(),
        upstream: ReadyValidInterface(_Packet()),
        downstream: ReadyValidInterface(_Packet()),
        requestId: withId ? Logic(width: 4) : null,
        latency: 1,
        coreIdentity: 'TypedQueue',
        coreGenerator: ({
          required clk,
          required reset,
          required start,
          required data,
        }) =>
            flop(clk, data, outputGenerator: data.clone),
      );
      await wrapper.build();
      final queue = wrapper.subModules.whereType<ReadyValidQueue>().single;
      final queued = queue.upstream.data as LogicStructure;
      expect(queued.elements.first, isA<_Packet>());
      expect(queued.elements.length, withId ? 2 : 1);
    }
  });

  test('result queue preserves unpacked typed arrays', () async {
    TypedLogicArray<_Packet, LogicValue> array() =>
        TypedLogicArray<_Packet, LogicValue>(
          [2, 2],
          ({name}) => _Packet(name: name ?? 'packet'),
          numUnpackedDimensions: 1,
        );
    final wrapper = ReadyValidFixedLatency<TypedLogicArray<_Packet, LogicValue>,
        TypedLogicArray<_Packet, LogicValue>, Logic>(
      clk: Logic(),
      reset: Logic(),
      upstream: ReadyValidInterface(array()),
      downstream: ReadyValidInterface(array()),
      requestId: Logic(width: 4),
      latency: 0,
      coreIdentity: 'TypedArray',
      coreGenerator: ({
        required clk,
        required reset,
        required start,
        required data,
      }) =>
          data,
    );
    await wrapper.build();
    final queue = wrapper.subModules.whereType<ReadyValidQueue>().single;
    final queued = queue.upstream.data as LogicStructure;
    final payload =
        queued.elements.first as TypedLogicArray<_Packet, LogicValue>;
    expect(payload.dimensions, [2, 2]);
    expect(payload.numUnpackedDimensions, 1);
    expect(wrapper.dumpSystemVerilog(), contains('module ReadyValid'));
  });

  test('structured IDs survive a pipeline and stalled result queue', () async {
    final dut = _TypedHarness(latency: 2);
    expect(dut.wrapper.input('request_id'), isA<_Tag>());
    expect(dut.wrapper.resultId, isA<_Tag>());
    await dut.build();
    final queue = dut.wrapper.subModules.whereType<ReadyValidQueue>().single;
    final queued = queue.upstream.data as LogicStructure;
    expect(queued.elements[1], isA<_Tag>());
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'low': 0,
        'high': 0,
        'valid': 0,
        'ready': 0,
        'id': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'low': 3,
        'high': 12,
        'valid': 1,
        'id': 9,
      }, {
        'input_ready': 1
      }),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'valid': 0, 'id': 2}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0}, {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
      }, {
        'output_valid': 1,
        'low_result': 3,
        'high_result': 12,
        'result_id': 9,
        'id_lane': 1,
        'error': 0,
      }),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'ready': 1
      }, {
        'output_valid': 1,
        'result_id': 9,
        'id_lane': 1,
      }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('unpacked array IDs survive a pipeline in generated RTL', () async {
    final dut = _ArrayIdHarness();
    expect(dut.wrapper.resultId!.numUnpackedDimensions, 1);
    await dut.build();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'data': 0,
        'valid': 0,
        'ready': 0,
        'id': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'data': 0xa5, 'valid': 1, 'id': 9}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'valid': 0, 'id': 2}, {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0
      }, {
        'output_valid': 1,
        'result': 0xa5,
        'result_id': 9,
        'id_first': 1,
      }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('widened unpacked array IDs retain their schema through the queue',
      () async {
    final dut = _WidenedArrayIdHarness();
    await dut.build();
    final queue = dut.wrapper.subModules.whereType<ReadyValidQueue>().single;
    final queued = queue.upstream.data as LogicStructure;
    expect(queued.elements[1], isA<_ArrayId>());
    expect((queued.elements[1] as _ArrayId).numUnpackedDimensions, 1);
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'data': 0,
        'valid': 0,
        'ready': 0,
        'id': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'data': 0xa5, 'valid': 1, 'id': 9}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'valid': 0, 'id': 2}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0}, {'output_valid': 1, 'result': 0xa5, 'result_id': 9}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('widened structured constant IDs survive a stalled result', () async {
    final dut = _ConstantIdHarness();
    expect(dut.wrapper.input('request_id'), isA<FixedPoint>());
    expect(dut.wrapper.resultId, isA<FixedPoint>());
    await dut.build();
    final queue = dut.wrapper.subModules.whereType<ReadyValidQueue>().single;
    final queued = queue.upstream.data as LogicStructure;
    expect(queued.elements[1], isA<FixedPoint>());
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'data': 0,
        'valid': 0,
        'ready': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'data': 0xa5, 'valid': 1}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'valid': 0}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0}, {'output_valid': 1, 'result': 0xa5, 'result_id': 10}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'ready': 1},
          {'output_valid': 1, 'result': 0xa5, 'result_id': 10}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('fixed-latency core may return a matching structured constant',
      () async {
    final dut = _ConstantCoreHarness();
    await dut.build();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'data': 0,
        'valid': 0,
        'ready': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'data': 0xa5, 'valid': 1}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'valid': 0}, {'output_valid': 1, 'result': 0x31}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'ready': 1}, {'output_valid': 1, 'result': 0x31}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  for (final (latency, interval, capacity, withId, multiCycle) in [
    (0, 1, 1, false, false),
    (0, 1, 2, true, false),
    (1, 1, 2, true, false),
    (4, 1, 5, true, false),
    (5, 3, 2, true, false),
    (3, 1, 1, true, false),
    (3, 3, 4, true, true),
  ]) {
    test(
        'fixed latency $latency interval $interval capacity $capacity '
        'ID $withId multi-cycle $multiCycle preserves results through stalls '
        'and reset', () async {
      final dut = _Harness(
        latency: latency,
        initiationInterval: interval,
        capacity: capacity,
        withId: withId,
        multiCycle: multiCycle,
      );
      await dut.build();
      final random = Random(160 + latency + interval + capacity);
      final queued = <_Transaction>[];
      final scheduled = <int, _Transaction>{};
      _Transaction? offered;
      var outstanding = 0;
      var cooldown = 0;
      var acceptedCount = 0;
      var retiredCount = 0;
      final vectors = <Vector>[];

      for (var cycle = 0; cycle < 220; cycle++) {
        final reset = cycle == 0 || cycle == 90;
        if (cycle < 160 && offered == null && random.nextInt(4) != 0) {
          offered = (data: random.nextInt(256), id: random.nextInt(16));
        }
        final downstreamReady =
            cycle >= 160 || (cycle % 23 >= 12 && random.nextBool());
        final validOut = !reset && queued.isNotEmpty;
        final retire = validOut && downstreamReady;
        final canAccept =
            !reset && cooldown == 0 && (outstanding < capacity || retire);
        final accept = offered != null && canAccept;
        final inputs = {
          'reset': reset ? 1 : 0,
          'request': offered?.data ?? 0,
          'valid': offered == null ? 0 : 1,
          'ready': downstreamReady ? 1 : 0,
          if (withId) 'id': offered?.id ?? 0,
        };
        vectors
          ..add(Vector({
            'clk': 0,
            ...inputs,
          }, {
            'input_ready': canAccept ? 1 : 0,
            'output_valid': validOut ? 1 : 0,
            'error': 0,
            if (validOut) 'result': queued.first.data,
            if (validOut && withId) 'result_id': queued.first.id,
          }))
          ..add(Vector({'clk': 1, ...inputs}, {}));

        if (reset) {
          queued.clear();
          scheduled.clear();
          outstanding = 0;
          cooldown = 0;
          offered = null;
          continue;
        }
        if (retire) {
          queued.removeAt(0);
          retiredCount++;
        }
        if (accept) {
          final transaction = offered;
          scheduled[cycle + latency] =
              (data: transaction.data ^ 0xa5, id: transaction.id);
          acceptedCount++;
          offered = null;
        }
        final completed = scheduled.remove(cycle);
        if (completed != null) {
          queued.add(completed);
        }
        outstanding += (accept ? 1 : 0) - (retire ? 1 : 0);
        expect(outstanding, lessThanOrEqualTo(capacity));
        if (accept) {
          cooldown = interval - 1;
        } else if (cooldown > 0) {
          cooldown--;
        }
      }
      expect(acceptedCount, greaterThan(5));
      expect(retiredCount, greaterThan(5));
      expect(outstanding, 0);
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  for (final (latency, interval) in [(0, 1), (4, 1), (5, 3)]) {
    test('fixed latency $latency admits at interval $interval without stalls',
        () async {
      final dut = _Harness(
        latency: latency,
        initiationInterval: interval,
        capacity: latency + 1,
        withId: false,
      );
      await dut.build();
      final vectors = <Vector>[
        Vector(
            {'clk': 0, 'reset': 1, 'request': 0, 'valid': 0, 'ready': 1}, {}),
        Vector(
            {'clk': 1, 'reset': 1, 'request': 0, 'valid': 0, 'ready': 1}, {}),
      ];
      for (var cycle = 0; cycle < 30; cycle++) {
        final accepted = cycle % interval == 0;
        final resultCycle = cycle - latency - 1;
        final resultValid = resultCycle >= 0 && resultCycle % interval == 0;
        final inputs = {
          'reset': 0,
          'request': cycle,
          'valid': 1,
          'ready': 1,
        };
        vectors
          ..add(Vector({
            'clk': 0,
            ...inputs,
          }, {
            'input_ready': accepted ? 1 : 0,
            'output_valid': resultValid ? 1 : 0,
            if (resultValid) 'result': resultCycle ^ 0xa5,
            'error': 0,
          }))
          ..add(Vector({'clk': 1, ...inputs}, {}));
      }
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  test('structured payload and ID remain stable under backpressure', () async {
    final dut = _TypedHarness();
    await dut.build();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'low': 0,
        'high': 0,
        'valid': 0,
        'ready': 0,
        'id': 0
      }, {}),
      Vector({
        'clk': 1,
        'reset': 1,
        'low': 0,
        'high': 0,
        'valid': 0,
        'ready': 0,
        'id': 0
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'low': 3,
        'high': 12,
        'valid': 1,
        'ready': 0,
        'id': 9
      }, {
        'input_ready': 1,
        'output_valid': 0
      }),
      Vector({
        'clk': 1,
        'reset': 0,
        'low': 3,
        'high': 12,
        'valid': 1,
        'ready': 0,
        'id': 9
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'low': 7,
        'high': 1,
        'valid': 0,
        'ready': 0,
        'id': 2
      }, {
        'output_valid': 1,
        'low_result': 3,
        'high_result': 12,
        'result_id': 9,
        'error': 0
      }),
      Vector({
        'clk': 1,
        'reset': 0,
        'low': 7,
        'high': 1,
        'valid': 0,
        'ready': 0,
        'id': 2
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'low': 7,
        'high': 1,
        'valid': 0,
        'ready': 1,
        'id': 2
      }, {
        'output_valid': 1,
        'low_result': 3,
        'high_result': 12,
        'result_id': 9,
        'error': 0
      }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test(
      'tracker reports premature retirement and supports zero-latency '
      'same-cycle completion', () async {
    final tracker = FixedLatencyTracker(
      clk: Logic(),
      reset: Logic(),
      request: Logic(),
      retire: Logic(),
      latency: 0,
      initiationInterval: 1,
      capacity: 1,
    );
    await tracker.build();
    final vectors = [
      Vector({'clk': 0, 'reset': 1, 'request': 0, 'retire': 0}, {}),
      Vector({'clk': 1, 'reset': 1, 'request': 0, 'retire': 0}, {}),
      Vector({'clk': 0, 'reset': 0, 'request': 0, 'retire': 1},
          {'can_accept': 1, 'accepted': 0, 'completed': 0, 'error': 1}),
      Vector({'clk': 1, 'reset': 0, 'request': 0, 'retire': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'request': 1, 'retire': 1},
          {'can_accept': 1, 'accepted': 1, 'completed': 1, 'error': 0}),
      Vector({'clk': 1, 'reset': 0, 'request': 1, 'retire': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'request': 0, 'retire': 0},
          {'outstanding': 0, 'error': 0}),
    ];
    await SimCompare.checkFunctionalVector(tracker, vectors);
    SimCompare.checkIverilogVector(tracker, vectors);
  });

  test('tracker rejects retirement before an in-flight result completes',
      () async {
    final tracker = FixedLatencyTracker(
      clk: Logic(),
      reset: Logic(),
      request: Logic(),
      retire: Logic(),
      latency: 2,
      initiationInterval: 1,
      capacity: 1,
    );
    await tracker.build();
    final vectors = [
      Vector({'clk': 0, 'reset': 1, 'request': 0, 'retire': 0}, {}),
      Vector({'clk': 1, 'reset': 1, 'request': 0, 'retire': 0}, {}),
      Vector({'clk': 0, 'reset': 0, 'request': 1, 'retire': 0},
          {'can_accept': 1, 'accepted': 1}),
      Vector({'clk': 1, 'reset': 0, 'request': 1, 'retire': 0}, {}),
      Vector({'clk': 0, 'reset': 0, 'request': 0, 'retire': 1},
          {'outstanding': 1, 'can_accept': 0, 'completed': 0, 'error': 1}),
      Vector({'clk': 1, 'reset': 0, 'request': 0, 'retire': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'request': 0, 'retire': 1},
          {'outstanding': 1, 'completed': 1, 'error': 0}),
      Vector({'clk': 1, 'reset': 0, 'request': 0, 'retire': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'request': 0, 'retire': 0},
          {'outstanding': 0, 'error': 0}),
    ];
    await SimCompare.checkFunctionalVector(tracker, vectors);
    SimCompare.checkIverilogVector(tracker, vectors);
  });

  test('wrapper validates timing, identity, and core result shape', () {
    ReadyValidFixedLatency<Logic, Logic, Logic> create({
      int latency = 1,
      int initiationInterval = 1,
      int capacity = 2,
      String coreIdentity = 'ValidCore',
      Logic? result,
    }) =>
        ReadyValidFixedLatency<Logic, Logic, Logic>(
          clk: Logic(),
          reset: Logic(),
          upstream: ReadyValidInterface(Logic(width: 8)),
          downstream: ReadyValidInterface(Logic(width: 8)),
          latency: latency,
          initiationInterval: initiationInterval,
          capacity: capacity,
          coreIdentity: coreIdentity,
          coreGenerator: ({
            required clk,
            required reset,
            required start,
            required data,
          }) =>
              result ?? data,
        );

    expect(() => create(latency: -1), throwsArgumentError);
    expect(() => create(initiationInterval: 0), throwsArgumentError);
    expect(() => create(capacity: 0), throwsArgumentError);
    expect(() => create(coreIdentity: 'bad-name'), throwsArgumentError);
    expect(() => create(result: Logic(width: 7)), throwsArgumentError);
    expect(() => create(result: _Packet()), throwsArgumentError);
    expect(
        () => ReadyValidFixedLatency<Logic, FixedPoint, Logic>(
              clk: Logic(),
              reset: Logic(),
              upstream: ReadyValidInterface(Logic(width: 8)),
              downstream: ReadyValidInterface(
                  FixedPoint(integerWidth: 3, fractionWidth: 4)),
              latency: 0,
              coreIdentity: 'WrongConstantFormat',
              coreGenerator: ({
                required clk,
                required reset,
                required start,
                required data,
              }) =>
                  FixedPoint.constant(FixedPointValue.withSignedness(
                      integer: LogicValue.ofInt(3, 4),
                      fraction: LogicValue.ofInt(1, 4),
                      signed: false)),
            ),
        throwsArgumentError);
  });
}
