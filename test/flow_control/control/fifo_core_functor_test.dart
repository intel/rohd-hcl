// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fifo_core_functor_test.dart
// Tests direct action-driven FIFO core construction.
//
// 2026 October 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Packet extends LogicStructure {
  Logic get data => elements[0];
  Logic get tag => elements[1];

  _Packet()
      : super(
          [
            Logic(name: 'data', width: 8),
            Logic(name: 'tag', width: 2),
          ],
          name: 'packet',
        );

  _Packet._clone(LogicStructure original, {String? name})
      : super(
          original.elements.map((element) => element.clone()).toList(),
          name: name ?? original.name,
        );

  @override
  _Packet clone({String? name}) => _Packet._clone(this, name: name);
}

class _FifoFunctorHarness<LogicType extends Logic> extends Module {
  late final LogicType payloadOut;
  late final FifoCoreBinding<LogicType> binding;

  Logic get canEnqueue => output('canEnqueue');
  Logic get outputValid => output('outputValid');
  Logic get slotReleased => output('slotReleased');
  Logic get full => output('full');
  Logic get empty => output('empty');
  Logic? get occupancy => tryOutput('occupancy');

  _FifoFunctorHarness({
    required Logic clk,
    required Logic reset,
    required Logic enqueue,
    required Logic dequeue,
    required LogicType payload,
    required int depth,
    bool generateBypass = false,
    bool generateOccupancy = false,
  }) : super(
          definitionName: 'FifoFunctorHarness_D${depth}_'
              'B${generateBypass ? 1 : 0}_W${payload.width}',
        ) {
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localEnqueue = addInput('enqueue', enqueue);
    final localDequeue = addInput('dequeue', dequeue);
    final localPayload = addTypedInput('payload', payload);
    final functor = FifoCoreFunctor<LogicType>(
      depth: depth,
      generateBypass: generateBypass,
      generateOccupancy: generateOccupancy,
    );
    binding = functor.construct(
      FifoCoreRequest<LogicType>(
        clk: localClk,
        reset: localReset,
        enqueue: localEnqueue,
        dequeue: localDequeue,
        payload: localPayload,
        requirements: FifoCoreRequirements(
          fullReplacement: true,
          emptyBypass: generateBypass,
        ),
      ),
      name: 'fifo_core',
    );

    addOutput('canEnqueue') <= binding.canEnqueue;
    addOutput('outputValid') <= binding.outputValid;
    addOutput('slotReleased') <= binding.slotReleased;
    addOutput('full') <= binding.full;
    addOutput('empty') <= binding.empty;
    if (generateOccupancy) {
      addOutput(
            'occupancy',
            width: binding.occupancy!.width,
          ) <=
          binding.occupancy!;
    }
    payloadOut = addTypedOutput(
      'payloadOut',
      payload.clone as LogicType Function({String? name}),
    )..gets(binding.output);
  }
}

void main() {
  tearDown(Simulator.reset);

  test('capabilities and implementation identity are stable', () {
    final functor = FifoCoreFunctor<Logic>(
      depth: 4,
      generateBypass: true,
      generateOccupancy: true,
      generateError: true,
    );

    expect(functor.identity, 'fifo_core');
    expect(functor.definitionIdentity, 'fifo_core');
    expect(
      functor.capabilities.configurationIdentity,
      'D4_R1_B1_S1_O1_E1',
    );
    expect(functor.capabilities.supportsFullReplacement, isTrue);
    expect(functor.capabilities.supportsEmptyBypass, isTrue);
    expect(functor.capabilities.slotReleaseRequiresStoredEntry, isTrue);
    expect(() => FifoCoreFunctor<Logic>(depth: 0), throwsArgumentError);
  });

  test('requirements reject unavailable empty bypass', () {
    final functor = FifoCoreFunctor<Logic>(depth: 2);

    expect(
      () => functor.construct(
        FifoCoreRequest<Logic>(
          clk: Logic(),
          reset: Logic(),
          enqueue: Logic(),
          dequeue: Logic(),
          payload: Logic(width: 8),
          requirements: const FifoCoreRequirements(emptyBypass: true),
        ),
        name: 'fifo',
      ),
      throwsArgumentError,
    );
  });

  for (final depth in [1, 2, 4]) {
    test(
      'depth $depth supports full replacement and stable typed output',
      () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();
        final enqueue = Logic();
        final dequeue = Logic();
        final payload = _Packet();
        final harness = _FifoFunctorHarness<_Packet>(
          clk: clk,
          reset: reset,
          enqueue: enqueue,
          dequeue: dequeue,
          payload: payload,
          depth: depth,
          generateOccupancy: true,
        );

        await harness.build();
        final systemVerilog = harness.generateSynth();
        expect(
          systemVerilog,
          contains('FifoCore_fifo_core_D${depth}_R1_B0_S1_O1_E0_W10'),
        );
        expect(
            harness.binding.module.outputs.keys,
            containsAll({
              'canEnqueue',
              'outputValid',
              'slotReleased',
            }));
        expect(harness.payloadOut, isA<_Packet>());
        expect(harness.occupancy!.width, log2Ceil(depth + 1));
        unawaited(Simulator.run());

        reset.inject(1);
        enqueue.inject(0);
        dequeue.inject(0);
        payload.data.inject(0);
        payload.tag.inject(0);
        await clk.nextPosedge;
        reset.inject(0);

        for (var index = 0; index < depth; index++) {
          enqueue.inject(1);
          payload.data.inject(0x10 + index);
          payload.tag.inject(index & 0x3);
          await clk.nextPosedge;
        }
        enqueue.inject(0);
        await clk.nextNegedge;

        expect(harness.full.value, LogicValue.one);
        expect(harness.outputValid.value, LogicValue.one);
        expect(harness.canEnqueue.value, LogicValue.zero);
        expect(harness.slotReleased.value, LogicValue.zero);
        expect(harness.payloadOut.data.value, LogicValue.ofInt(0x10, 8));
        expect(harness.occupancy!.value.toInt(), depth);
        await clk.nextPosedge;
        await clk.nextPosedge;
        expect(
          harness.payloadOut.data.value,
          LogicValue.ofInt(0x10, 8),
          reason: 'The offered head must remain stable without a dequeue.',
        );

        enqueue.inject(1);
        dequeue.inject(1);
        payload.data.inject(0x70 + depth);
        payload.tag.inject(3);
        await clk.nextNegedge;
        expect(harness.canEnqueue.value, LogicValue.one);
        expect(harness.slotReleased.value, LogicValue.one);
        expect(harness.outputValid.value, LogicValue.one);
        expect(harness.payloadOut.data.value, LogicValue.ofInt(0x10, 8));
        await clk.nextPosedge;
        expect(harness.full.value, LogicValue.one);
        expect(harness.occupancy!.value.toInt(), depth);

        enqueue.inject(0);
        final expected = [
          for (var index = 1; index < depth; index++) 0x10 + index,
          0x70 + depth,
        ];
        for (final value in expected) {
          await clk.nextNegedge;
          expect(harness.outputValid.value, LogicValue.one);
          expect(harness.slotReleased.value, LogicValue.one);
          expect(harness.payloadOut.data.value, LogicValue.ofInt(value, 8));
          await clk.nextPosedge;
        }

        await clk.nextNegedge;
        expect(harness.empty.value, LogicValue.one);
        expect(harness.outputValid.value, LogicValue.zero);
        expect(harness.slotReleased.value, LogicValue.zero);
        expect(harness.canEnqueue.value, LogicValue.one);
        expect(harness.occupancy!.value.toInt(), 0);

        await Simulator.endSimulation();
      },
    );
  }

  test('empty bypass exposes payload without releasing a stored slot',
      () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final enqueue = Logic();
    final dequeue = Logic();
    final payload = Logic(width: 8);
    final harness = _FifoFunctorHarness<Logic>(
      clk: clk,
      reset: reset,
      enqueue: enqueue,
      dequeue: dequeue,
      payload: payload,
      depth: 2,
      generateBypass: true,
    );

    await harness.build();
    unawaited(Simulator.run());
    reset.inject(1);
    enqueue.inject(0);
    dequeue.inject(0);
    payload.inject(0);
    await clk.nextPosedge;
    reset.inject(0);

    enqueue.inject(1);
    dequeue.inject(1);
    payload.inject(0x5a);
    await clk.nextNegedge;
    expect(harness.empty.value, LogicValue.one);
    expect(harness.canEnqueue.value, LogicValue.one);
    expect(harness.outputValid.value, LogicValue.one);
    expect(harness.payloadOut.value, LogicValue.ofInt(0x5a, 8));
    expect(harness.slotReleased.value, LogicValue.zero);
    await clk.nextPosedge;
    expect(harness.empty.value, LogicValue.one);

    await Simulator.endSimulation();
  });
}
