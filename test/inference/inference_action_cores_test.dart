// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// inference_action_cores_test.dart
// Direct scheduling and corner cases for protocol-neutral inference cores.
//
// 2026 November 23
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

import '../systemc_test_utils.dart';
import '../verilator_test_utils.dart';

void main() {
  tearDown(Simulator.reset);

  test('bounded attention arithmetic and retirement match native backends',
      () async {
    final request = FixedPointAttentionRequest(
      sequenceLength: 1,
      headDimension: 1,
      valueDimension: 1,
      elementWidth: 4,
      valueWidth: 8,
      requestIdWidth: 3,
    );
    final dut = FixedPointAttentionCore(
      clk: Logic(),
      reset: Logic(),
      request: request,
      resultSchema: FixedPointAttentionResult(
        valueDimension: 1,
        outputWidth: 8,
        requestIdWidth: 3,
      ),
      load: Logic(),
      retire: Logic(),
      elementFractionBits: 0,
      valueFractionBits: 0,
      scoreWidth: 6,
      scoreFractionBits: 0,
      normalizerWidth: 10,
      normalizerFractionBits: 6,
      expWidth: 8,
      expFractionBits: 6,
      reciprocalWidth: 10,
      reciprocalFractionBits: 8,
      outputWidth: 8,
    );
    await dut.build();
    final vectors = <Vector>[];
    void cycle(Map<String, dynamic> inputs, Map<String, dynamic> outputs) {
      vectors
        ..add(Vector({'clk': 0, ...inputs}, outputs))
        ..add(Vector({'clk': 1}, const {}));
    }

    cycle({'reset': 1, 'load': 0, 'retire': 0, 'request': 0}, const {});
    const activeRequest =
        (251 << 8) | (1 << 16) | (1 << 17) | (1 << 18) | (5 << 19);
    const maskedRequest = activeRequest & ~(1 << 16);
    const activeResult = 251 | (5 << 8);
    const maskedResult = (5 << 8) | (1 << 11);

    cycle({'reset': 0, 'load': 1, 'request': activeRequest},
        {'busy': 0, 'canLoad': 1, 'resultValid': 0});
    cycle({'load': 0, 'request': 0}, {'busy': 1, 'resultValid': 0});
    cycle(const {}, {'busy': 0, 'resultValid': 1, 'result': activeResult});
    cycle(const {}, {'canLoad': 0, 'resultValid': 1, 'result': activeResult});
    cycle({'retire': 1, 'load': 1, 'request': maskedRequest},
        {'canLoad': 1, 'resultValid': 1, 'result': activeResult});
    cycle({'load': 0, 'retire': 0}, {'busy': 1, 'resultValid': 0});
    cycle(const {}, {'busy': 0, 'resultValid': 1, 'result': maskedResult});
    cycle({'reset': 1}, {'resultValid': 1});
    cycle({'reset': 0}, {'busy': 0, 'resultValid': 0, 'canLoad': 1});
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    if (canRunSystemC()) {
      SimCompare.checkSystemCVector(dut, vectors);
    }
    checkVerilatorVector(dut, vectors);
    expectNoVerilatorWarnings(dut, ['LATCH', 'UNOPTFLAT']);
  }, timeout: const Timeout(Duration(minutes: 5)));

  for (final length in [1, 4]) {
    test('bounded attention completes in $length cycles for every mask',
        () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final load = Logic();
      final request = FixedPointAttentionRequest(
        sequenceLength: length,
        headDimension: 1,
        valueDimension: 1,
        elementWidth: 4,
        valueWidth: 8,
        requestIdWidth: 3,
      );
      final dut = FixedPointAttentionCore(
        clk: clk,
        reset: reset,
        request: request,
        resultSchema: FixedPointAttentionResult(
          valueDimension: 1,
          outputWidth: 8,
          requestIdWidth: 3,
        ),
        load: load,
        elementFractionBits: 0,
        valueFractionBits: 0,
        scoreWidth: 6,
        scoreFractionBits: 0,
        normalizerWidth: 10,
        normalizerFractionBits: 6,
        expWidth: 8,
        expFractionBits: 6,
        reciprocalWidth: 10,
        reciprocalFractionBits: 8,
        outputWidth: 8,
      );
      await dut.build();
      unawaited(Simulator.run());
      reset.inject(1);
      load.inject(0);
      request.inject(0);
      await _edge(clk);
      reset.inject(0);

      Future<void> runRequest(
        int id, {
        required int keyMask,
        required int laneMask,
        required int causalCount,
      }) async {
        request.keyMask.inject(keyMask);
        request.laneMask.inject(laneMask);
        request.causalKeyCount.inject(causalCount);
        request.requestId.inject(id);
        for (final value in request.values.arrayElements) {
          value.inject(BigInt.from(-5).toUnsigned(8));
        }
        expect(dut.canLoad.value, LogicValue.one);
        load.inject(1);
        await _edge(clk);
        load.inject(0);
        request.values.arrayElements.first.inject(42);
        for (var index = 0; index < length; index++) {
          expect(dut.busy.value, LogicValue.one);
          expect(dut.currentKey.value.toInt(), index);
          expect(dut.resultValid.value, LogicValue.zero);
          await _edge(clk);
        }
        final invalid = keyMask == 0 || laneMask == 0 || causalCount == 0;
        expect(dut.busy.value, LogicValue.zero);
        expect(dut.resultValid.value, LogicValue.one);
        expect(
          dut.result.values.arrayElements.single.value
              .toBigInt()
              .toSigned(8)
              .toInt(),
          invalid ? 0 : -5,
        );
        expect(dut.result.requestId.value.toInt(), id);
        expect(dut.result.invalidInput.value.toInt(), invalid ? 1 : 0);
        expect(dut.result.overflow.value, LogicValue.zero,
            reason: 'request=$id length=$length');
        expect(dut.result.inexact.value, LogicValue.zero);
      }

      final fullMask = (1 << length) - 1;
      await runRequest(0, keyMask: fullMask, laneMask: 1, causalCount: length);
      await runRequest(1, keyMask: fullMask, laneMask: 0, causalCount: length);
      await runRequest(2, keyMask: 0, laneMask: 1, causalCount: length);
      await runRequest(3, keyMask: fullMask, laneMask: 1, causalCount: 0);

      load.inject(1);
      await _edge(clk);
      load.inject(0);
      reset.inject(1);
      await _edge(clk);
      expect(dut.busy.value, LogicValue.zero);
      expect(dut.resultValid.value, LogicValue.zero);
      reset.inject(0);
      await runRequest(7, keyMask: fullMask, laneMask: 1, causalCount: length);
      await Simulator.endSimulation();
    });
  }

  test('row attention uses the active final row and resets partial state',
      () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final load = Logic();
    final writeRow = Logic();
    final command = FixedPointAttentionRowCommand(
      headDimension: 1,
      elementWidth: 4,
      requestIdWidth: 3,
    );
    final row = FixedPointAttentionRow(
      headDimension: 1,
      valueDimension: 1,
      elementWidth: 4,
      valueWidth: 8,
    );
    final dut = FixedPointAttentionRowCore(
      clk: clk,
      reset: reset,
      command: command,
      rows: row,
      resultSchema: FixedPointAttentionResult(
        valueDimension: 1,
        outputWidth: 8,
        requestIdWidth: 3,
      ),
      load: load,
      writeRow: writeRow,
      elementFractionBits: 0,
      valueFractionBits: 0,
      scoreWidth: 6,
      scoreFractionBits: 0,
      normalizerWidth: 10,
      normalizerFractionBits: 6,
      expWidth: 8,
      expFractionBits: 6,
      reciprocalWidth: 10,
      reciprocalFractionBits: 8,
      outputWidth: 8,
    );
    await dut.build();
    unawaited(Simulator.run());
    reset.inject(1);
    load.inject(0);
    writeRow.inject(0);
    command.inject(0);
    row.inject(0);
    await _edge(clk);
    reset.inject(0);
    command.laneMask.inject(1);
    load.inject(1);
    await _edge(clk);
    load.inject(0);
    row.active.inject(1);
    row.values.arrayElements.single.inject(11);
    writeRow.inject(1);
    await _edge(clk);
    writeRow.inject(0);
    expect(dut.processing.value, LogicValue.one);
    reset.inject(1);
    await _edge(clk);
    expect(dut.processing.value, LogicValue.zero);
    expect(dut.resultValid.value, LogicValue.zero);
    reset.inject(0);
    command.requestId.inject(5);
    load.inject(1);
    await _edge(clk);
    load.inject(0);
    expect(dut.canWriteRow.value, LogicValue.one);
    row.last.inject(1);
    row.values.arrayElements.single.inject(BigInt.from(-5).toUnsigned(8));
    writeRow.inject(1);
    await _edge(clk);
    writeRow.inject(0);
    expect(dut.processing.value, LogicValue.zero);
    expect(dut.resultValid.value, LogicValue.one);
    expect(dut.result.requestId.value.toInt(), 5);
    expect(dut.result.invalidInput.value, LogicValue.zero);
    expect(
        dut.result.values.arrayElements.single.value
            .toBigInt()
            .toSigned(8)
            .toInt(),
        -5);
    await _edge(clk);
    expect(dut.resultValid.value, LogicValue.zero);
    expect(dut.rowWaitCycles.value.toInt(), 0);
    await Simulator.endSimulation();
  });

  test('direct address cadence, carry, and idle restart match RTL', () async {
    final dut = TensorStridedAddressGeneratorCore(
      clk: Logic(),
      reset: Logic(),
      command: TensorAddressCommand(
        addressWidth: 8,
        mWidth: 2,
        nWidth: 2,
        kWidth: 2,
        commandIdWidth: 3,
      ),
      resultSchema: TensorAddressBeat(
        addressWidth: 8,
        mWidth: 2,
        nWidth: 2,
        kWidth: 2,
        commandIdWidth: 3,
      ),
      load: Logic(),
      advance: Logic(),
      counterWidth: 4,
    );
    await dut.build();
    final command = BigInt.from(250) |
        (BigInt.one << 8) |
        (BigInt.one << 10) |
        (BigInt.two << 12) |
        (BigInt.from(10) << 30) |
        (BigInt.one << 38);
    final zeroExtent = command & ~(BigInt.from(3) << 8);
    const first = 250 | (1 << 16);
    const last = 4 | (1 << 12) | (1 << 14) | (1 << 15) | (1 << 16);
    final vectors = <Vector>[];
    void cycle(
        int reset, int load, BigInt payload, Map<String, dynamic> expected) {
      final inputs = {
        'clk': 0,
        'reset': reset,
        'load': load,
        'advance': 1,
        'command': payload,
      };
      vectors
        ..add(Vector(inputs, expected))
        ..add(Vector({...inputs, 'clk': 1}, const {}));
    }

    cycle(1, 0, command, const {});
    cycle(0, 1, command, {'busy': 0, 'canLoad': 1});
    cycle(0, 0, command, {
      'busy': 1,
      'canLoad': 0,
      'result': first,
      'addressesAccepted': 0,
    });
    cycle(0, 0, command, {
      'busy': 1,
      'canLoad': 0,
      'result': last,
      'addressesAccepted': 1,
    });
    cycle(0, 1, zeroExtent, {
      'busy': 0,
      'canLoad': 1,
      'addressesAccepted': 2,
      'overflowedAddresses': 1,
    });
    cycle(0, 0, command, {
      'busy': 0,
      'canLoad': 1,
      'invalidCommand': 1,
      'commandsAccepted': 2,
      'addressesAccepted': 2,
      'overflowedAddresses': 1,
    });
    cycle(0, 0, command, {'busy': 0, 'invalidCommand': 0});
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('direct typed scratchpad retires responses without a handshake',
      () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final readEnable = Logic(width: 2);
    final writeEnable = Logic(width: 2);
    final reads = List.generate(
        2, (_) => TensorScratchpadReadRequest(addressWidth: 2, tagWidth: 2));
    final writes = List.generate(
        2,
        (_) => TensorScratchpadWriteRequest(
            addressWidth: 2, data: LogicArray([2], 4)));
    final dut = TensorScratchpadCore<LogicArray>(
      clk: clk,
      reset: reset,
      readRequests: reads,
      writeRequests: writes,
      readResponses: List.generate(
          2,
          (_) => TensorScratchpadReadResponse(
              data: LogicArray([2], 4), tagWidth: 2)),
      readEnable: readEnable,
      writeEnable: writeEnable,
      depth: 3,
      bankCount: 2,
    );
    await dut.build();
    unawaited(Simulator.run());
    reset.inject(1);
    readEnable.inject(0);
    writeEnable.inject(0);
    for (final request in [...reads, ...writes]) {
      request.inject(0);
    }
    await _edge(clk);
    reset.inject(0);
    for (var port = 0; port < 2; port++) {
      writes[port].address.inject(port);
      writes[port].data.inject(0xa1 + port);
      reads[port].address.inject(port);
      reads[port].tag.inject(port + 1);
    }
    writeEnable.inject(3);
    await _edge(clk);
    writeEnable.inject(0);
    readEnable.inject(3);
    await _edge(clk);
    readEnable.inject(0);
    expect(dut.responseValid.value.toInt(), 0);
    await _edge(clk);
    expect(dut.responseValid.value.toInt(), 3);
    for (var port = 0; port < 2; port++) {
      expect(dut.responses[port].data.value.toInt(), 0xa1 + port);
      expect(dut.responses[port].tag.value.toInt(), port + 1);
      expect(dut.responses[port].data.dimensions, [2]);
    }
    reads[0].address.inject(3);
    readEnable.inject(1);
    await _edge(clk);
    readEnable.inject(0);
    expect(dut.responseValid.value.toInt(), 1);
    expect(dut.responses[0].error.value, LogicValue.one);
    expect(dut.responses[0].data.value.toInt(), 0);
    await _edge(clk);
    expect(dut.responseValid.value.toInt(), 0);
    expect(dut.responseOverflow.value.toInt(), 0);
    expect(dut.unexpectedResponse.value.toInt(), 0);
    await Simulator.endSimulation();
  });
}

Future<void> _edge(Logic clk) async {
  await clk.nextPosedge;
  await clk.nextNegedge;
}
