// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// scratchpad_fixed_point_attention_test.dart
// Tests for Scratchpad Fixed Point Attention.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('loads packed KV rows and matches fixed-point attention', () async {
    final fixture = _ScratchpadAttentionFixture();
    await fixture.buildAndReset();

    fixture.command.data.query.arrayElements[0].inject(1);
    fixture.command.data.query.arrayElements[1].inject(0);
    fixture.command.data.keyBaseAddress.inject(1);
    fixture.command.data.valueBaseAddress.inject(4);
    fixture.command.data.keyMask.inject(0x7);
    fixture.command.data.laneMask.inject(0x3);
    fixture.command.data.causalKeyCount.inject(3);
    fixture.command.data.requestId.inject(5);
    fixture.command.valid.inject(1);
    await fixture.clk.nextNegedge;
    expect(fixture.command.ready.value, LogicValue.one);
    await fixture.clk.nextPosedge;
    fixture.command.valid.inject(0);

    const keyRows = [0x00, 0x0f, 0x0e];
    const valueRows = [0x0004, 0x0400, 0x0404];
    for (var row = 0; row < 3; row++) {
      await fixture.serviceRow(
        row,
        keyAddress: row + 1,
        valueAddress: row + 4,
        keyData: keyRows[row],
        valueData: valueRows[row],
      );
    }

    for (var cycle = 0;
        cycle < 16 && fixture.result.valid.value != LogicValue.one;
        cycle++) {
      await fixture.clk.nextPosedge;
    }
    expect(fixture.result.valid.value, LogicValue.one);
    expect(fixture.outputValues, [3, 2]);
    expect(fixture.result.data.requestId.value.toInt(), 5);
    expect(fixture.result.data.memoryError.value, LogicValue.zero);
    expect(fixture.result.data.protocolError.value, LogicValue.zero);
    expect(fixture.result.data.addressOverflow.value, LogicValue.zero);
    const traffic = FixedPointAttentionTrafficModel(
      sequenceLength: 3,
      headDimension: 2,
      valueDimension: 2,
      elementWidth: 4,
      valueWidth: 8,
      scoreWidth: 6,
    );
    expect(traffic.registerCapturedCommandBytes, 10);
    expect(traffic.scratchpadCommandBytes, 1);
    expect(traffic.scratchpadReadBytes, 9);
    expect(traffic.scratchpadTotalBytes, 10);
    expect(traffic.commandByteReduction, 9);
    expect(fixture.dut.commandInputBytes.value.toInt(),
        traffic.scratchpadCommandBytes);
    expect(
        fixture.dut.memoryReadBytes.value.toInt(), traffic.scratchpadReadBytes);
    expect(fixture.dut.rowsAccepted.value.toInt(), 3);
    expect(fixture.dut.scoreProducts.value.toInt(), 6);
    expect(fixture.dut.activeValues.value.toInt(), 3);
    expect(fixture.dut.avoidedScoreWriteBytes.value.toInt(),
        traffic.maximumAvoidedScoreWriteBytes);
    expect(
        fixture.dut.computeBusyCycles.value.toInt(), greaterThanOrEqualTo(3));
    expect(fixture.dut.rowWaitCycles.value.toInt(), greaterThan(0));

    final retained = fixture.result.data.value;
    await fixture.clk.nextPosedge;
    expect(fixture.result.data.value, retained);
    fixture.result.ready.inject(1);
    await fixture.clk.nextPosedge;
    expect(fixture.result.valid.value, LogicValue.zero);
    expect(fixture.command.ready.value, LogicValue.one);
    await Simulator.endSimulation();
  });

  test('reports memory and response-tag errors with the result', () async {
    final fixture = _ScratchpadAttentionFixture();
    await fixture.buildAndReset();

    fixture.command.data.query.arrayElements[0].inject(1);
    fixture.command.data.query.arrayElements[1].inject(0);
    fixture.command.data.keyBaseAddress.inject(0);
    fixture.command.data.valueBaseAddress.inject(0);
    fixture.command.data.keyMask.inject(0);
    fixture.command.data.laneMask.inject(0x3);
    fixture.command.data.causalKeyCount.inject(3);
    fixture.command.data.requestId.inject(1);
    fixture.command.valid.inject(1);
    await fixture.clk.nextPosedge;
    fixture.command.valid.inject(0);

    for (var row = 0; row < 3; row++) {
      await fixture.serviceRow(
        row,
        keyAddress: row,
        valueAddress: row,
        keyData: 0,
        valueData: 0,
        keyError: row == 0,
        responseTag: row == 1 ? 3 : row,
      );
    }
    for (var cycle = 0;
        cycle < 16 && fixture.result.valid.value != LogicValue.one;
        cycle++) {
      await fixture.clk.nextPosedge;
    }

    expect(fixture.result.valid.value, LogicValue.one);
    expect(fixture.result.data.invalidInput.value, LogicValue.one);
    expect(fixture.result.data.memoryError.value, LogicValue.one);
    expect(fixture.result.data.protocolError.value, LogicValue.one);
    await Simulator.endSimulation();
  });

  test('does not issue wrapped reads after an address overflow', () async {
    final fixture = _ScratchpadAttentionFixture();
    await fixture.buildAndReset();

    fixture.command.data.query.inject(0);
    fixture.command.data.keyBaseAddress.inject(7);
    fixture.command.data.valueBaseAddress.inject(7);
    fixture.command.data.keyMask.inject(0);
    fixture.command.data.laneMask.inject(0x3);
    fixture.command.data.causalKeyCount.inject(3);
    fixture.command.data.requestId.inject(2);
    fixture.command.valid.inject(1);
    await fixture.clk.nextPosedge;
    fixture.command.valid.inject(0);
    await fixture.serviceRow(
      0,
      keyAddress: 7,
      valueAddress: 7,
      keyData: 0,
      valueData: 0,
    );

    for (var cycle = 0;
        cycle < 16 && fixture.result.valid.value != LogicValue.one;
        cycle++) {
      await fixture.clk.nextPosedge;
      expect(fixture.keyReadRequest.valid.value, LogicValue.zero);
      expect(fixture.valueReadRequest.valid.value, LogicValue.zero);
    }
    expect(fixture.result.valid.value, LogicValue.one);
    expect(fixture.result.data.addressOverflow.value, LogicValue.one);
    expect(fixture.dut.memoryReadBytes.value.toInt(), 3);
    await Simulator.endSimulation();
  });

  test('prefetches the next row while the current row is computed', () async {
    final fixture = _ScratchpadAttentionFixture();
    await fixture.buildAndReset();

    fixture.command.data.query.inject(0);
    fixture.command.data.keyBaseAddress.inject(1);
    fixture.command.data.valueBaseAddress.inject(4);
    fixture.command.data.keyMask.inject(0x7);
    fixture.command.data.laneMask.inject(0x3);
    fixture.command.data.causalKeyCount.inject(3);
    fixture.command.data.requestId.inject(0);
    fixture.command.valid.inject(1);
    await fixture.clk.nextPosedge;
    fixture.command.valid.inject(0);
    await fixture.serviceRow(
      0,
      keyAddress: 1,
      valueAddress: 4,
      keyData: 0,
      valueData: 0,
    );

    fixture.keyReadRequest.ready.inject(0);
    fixture.valueReadRequest.ready.inject(0);
    await fixture.clk.nextNegedge;
    expect(fixture.keyReadRequest.valid.value, LogicValue.one);
    expect(fixture.valueReadRequest.valid.value, LogicValue.one);
    expect(fixture.keyReadRequest.data.address.value.toInt(), 2);
    expect(fixture.valueReadRequest.data.address.value.toInt(), 5);
    expect(fixture.keyReadRequest.data.tag.value.toInt(), 1);
    expect(fixture.valueReadRequest.data.tag.value.toInt(), 1);
    expect(fixture.dut.loadIndex.value.toInt(), 0);
    await Simulator.endSimulation();
  });
}

class _ScratchpadAttentionFixture {
  final Logic clk = SimpleClockGenerator(10).clk;
  final Logic reset = Logic();
  final ReadyValidInterface<ScratchpadFixedPointAttentionCommand> command =
      ReadyValidInterface(
    ScratchpadFixedPointAttentionCommand(
      sequenceLength: 3,
      headDimension: 2,
      elementWidth: 4,
      keyAddressWidth: 3,
      valueAddressWidth: 3,
      requestIdWidth: 3,
    ),
  );
  final ReadyValidInterface<TensorScratchpadReadRequest> keyReadRequest =
      ReadyValidInterface(
    TensorScratchpadReadRequest(addressWidth: 3, tagWidth: 2),
  );
  final ReadyValidInterface<TensorScratchpadReadResponse> keyReadResponse =
      ReadyValidInterface(
    TensorScratchpadReadResponse(data: Logic(width: 8), tagWidth: 2),
  );
  final ReadyValidInterface<TensorScratchpadReadRequest> valueReadRequest =
      ReadyValidInterface(
    TensorScratchpadReadRequest(addressWidth: 3, tagWidth: 2),
  );
  final ReadyValidInterface<TensorScratchpadReadResponse> valueReadResponse =
      ReadyValidInterface(
    TensorScratchpadReadResponse(data: Logic(width: 16), tagWidth: 2),
  );
  final ReadyValidInterface<ScratchpadFixedPointAttentionResult> result =
      ReadyValidInterface(
    ScratchpadFixedPointAttentionResult(
      valueDimension: 2,
      outputWidth: 8,
      requestIdWidth: 3,
    ),
  );
  late final ScratchpadFixedPointAttention dut;

  _ScratchpadAttentionFixture() {
    dut = ScratchpadFixedPointAttention(
      clk: clk,
      reset: reset,
      command: command,
      keyReadRequest: keyReadRequest,
      keyReadResponse: keyReadResponse,
      valueReadRequest: valueReadRequest,
      valueReadResponse: valueReadResponse,
      result: result,
      valueDimension: 2,
      valueWidth: 8,
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
      counterWidth: 16,
    );
  }

  List<int> get outputValues => [
        for (final value in result.data.values.value.arrayValues)
          value.toBigInt().toSigned(8).toInt(),
      ];

  Future<void> buildAndReset() async {
    await dut.build();
    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());
    reset.inject(1);
    command.valid.inject(0);
    command.data.inject(0);
    keyReadRequest.ready.inject(1);
    valueReadRequest.ready.inject(1);
    keyReadResponse.valid.inject(0);
    keyReadResponse.data.inject(0);
    valueReadResponse.valid.inject(0);
    valueReadResponse.data.inject(0);
    result.ready.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
  }

  Future<void> serviceRow(
    int row, {
    required int keyAddress,
    required int valueAddress,
    required int keyData,
    required int valueData,
    bool keyError = false,
    int? responseTag,
  }) async {
    for (var cycle = 0;
        cycle < 8 &&
            (keyReadRequest.valid.value != LogicValue.one ||
                valueReadRequest.valid.value != LogicValue.one);
        cycle++) {
      await clk.nextNegedge;
    }
    expect(keyReadRequest.valid.value, LogicValue.one);
    expect(valueReadRequest.valid.value, LogicValue.one);
    expect(keyReadRequest.data.address.value.toInt(), keyAddress);
    expect(valueReadRequest.data.address.value.toInt(), valueAddress);
    expect(keyReadRequest.data.tag.value.toInt(), row);
    expect(valueReadRequest.data.tag.value.toInt(), row);
    await clk.nextPosedge;

    keyReadResponse.data.data.inject(keyData);
    keyReadResponse.data.tag.inject(responseTag ?? row);
    keyReadResponse.data.error.inject(keyError ? 1 : 0);
    valueReadResponse.data.data.inject(valueData);
    valueReadResponse.data.tag.inject(row);
    valueReadResponse.data.error.inject(0);
    keyReadResponse.valid.inject(1);
    valueReadResponse.valid.inject(1);
    await clk.nextPosedge;
    keyReadResponse.valid.inject(0);
    valueReadResponse.valid.inject(0);
  }
}
