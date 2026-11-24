// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// scratchpad_fixed_point_attention_icarus_test.dart
// Tests for Scratchpad Fixed Point Attention Icarus.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

import '../../example/attention_engine_example.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test(
    'public attention engine example runs and emits compilable RTL',
    () async {
      final example = await runAttentionExample();
      expect(example.values, [3, 2]);
      final directory = Directory.systemTemp.createTempSync(
        'rohd_hcl_attention_example_',
      );
      try {
        final source = File('${directory.path}/attention_engine.sv');
        await source.writeAsString(example.systemVerilog);
        final compile = await Process.run('iverilog', [
          '-g2012',
          '-s',
          'AttentionEngine',
          '-tnull',
          source.path,
        ]);
        expect(
          compile.exitCode,
          0,
          reason: '${compile.stdout}\n${compile.stderr}',
        );
      } finally {
        directory.deleteSync(recursive: true);
      }
    },
  );

  test('nested scratchpads and attention compile in Icarus', () async {
    final harness = _ScratchpadAttentionHarness(
      clk: Logic(),
      reset: Logic(),
      command: _command(),
      commandValid: Logic(),
      resultReady: Logic(),
      keyWriteAddress: Logic(width: 3),
      keyWriteData: Logic(width: 8),
      keyWriteValid: Logic(),
      valueWriteAddress: Logic(width: 3),
      valueWriteData: Logic(width: 16),
      valueWriteValid: Logic(),
    );
    await harness.build();

    final directory = Directory.systemTemp.createTempSync(
      'rohd_hcl_scratchpad_attention_',
    );
    final sourcePath = '${directory.path}/scratchpad_attention_harness.sv';
    try {
      final systemVerilog = harness.dumpSystemVerilog();
      expect(systemVerilog, contains('module ScratchpadAttentionHarness'));
      expect(systemVerilog, contains('module ScratchpadFixedPointAttention_'));
      expect(systemVerilog, contains('module TensorScratchpad_'));
      File(sourcePath).writeAsStringSync(systemVerilog);
      final result = Process.runSync('iverilog', [
        '-g2012',
        '-tnull',
        sourcePath,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('nested scratchpads supply an attention request', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final command = _command();
    final commandValid = Logic();
    final resultReady = Logic();
    final keyWriteAddress = Logic(width: 3);
    final keyWriteData = Logic(width: 8);
    final keyWriteValid = Logic();
    final valueWriteAddress = Logic(width: 3);
    final valueWriteData = Logic(width: 16);
    final valueWriteValid = Logic();
    final harness = _ScratchpadAttentionHarness(
      clk: clk,
      reset: reset,
      command: command,
      commandValid: commandValid,
      resultReady: resultReady,
      keyWriteAddress: keyWriteAddress,
      keyWriteData: keyWriteData,
      keyWriteValid: keyWriteValid,
      valueWriteAddress: valueWriteAddress,
      valueWriteData: valueWriteData,
      valueWriteValid: valueWriteValid,
    );
    await harness.build();
    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    reset.inject(1);
    command.inject(0);
    commandValid.inject(0);
    resultReady.inject(0);
    keyWriteValid.inject(0);
    valueWriteValid.inject(0);
    await clk.nextPosedge;
    reset.inject(0);

    const keyRows = [0x00, 0x0f, 0x0e];
    const valueRows = [0x0004, 0x0400, 0x0404];
    for (var row = 0; row < 3; row++) {
      keyWriteAddress.inject(row + 1);
      keyWriteData.inject(keyRows[row]);
      keyWriteValid.inject(1);
      valueWriteAddress.inject(row + 4);
      valueWriteData.inject(valueRows[row]);
      valueWriteValid.inject(1);
      await clk.nextNegedge;
      expect(harness.output('keyWriteReady').value, LogicValue.one);
      expect(harness.output('valueWriteReady').value, LogicValue.one);
      await clk.nextPosedge;
      keyWriteValid.inject(0);
      valueWriteValid.inject(0);
    }

    command.query.arrayElements[0].inject(1);
    command.query.arrayElements[1].inject(0);
    command.keyBaseAddress.inject(1);
    command.valueBaseAddress.inject(4);
    command.keyMask.inject(0x7);
    command.laneMask.inject(0x3);
    command.causalKeyCount.inject(3);
    command.requestId.inject(6);
    commandValid.inject(1);
    await clk.nextNegedge;
    expect(harness.output('commandReady').value, LogicValue.one);
    await clk.nextPosedge;
    commandValid.inject(0);

    for (var cycle = 0;
        cycle < 40 && harness.output('resultValid').value != LogicValue.one;
        cycle++) {
      await clk.nextPosedge;
    }
    expect(harness.output('resultValid').value, LogicValue.one);
    final result =
        harness.output('result') as ScratchpadFixedPointAttentionResult;
    expect(
      result.values.value.arrayValues
          .map((value) => value.toBigInt().toSigned(8).toInt())
          .toList(),
      [3, 2],
    );
    expect(result.requestId.value.toInt(), 6);
    expect(result.memoryError.value, LogicValue.zero);
    expect(result.protocolError.value, LogicValue.zero);
    expect(result.addressOverflow.value, LogicValue.zero);
    expect(harness.output('memoryReadBytes').value.toInt(), 9);
    await Simulator.endSimulation();
  });
}

ScratchpadFixedPointAttentionCommand _command() =>
    ScratchpadFixedPointAttentionCommand(
      sequenceLength: 3,
      headDimension: 2,
      elementWidth: 4,
      keyAddressWidth: 3,
      valueAddressWidth: 3,
      requestIdWidth: 3,
      name: 'command',
    );

class _ScratchpadAttentionHarness extends Module {
  _ScratchpadAttentionHarness({
    required Logic clk,
    required Logic reset,
    required ScratchpadFixedPointAttentionCommand command,
    required Logic commandValid,
    required Logic resultReady,
    required Logic keyWriteAddress,
    required Logic keyWriteData,
    required Logic keyWriteValid,
    required Logic valueWriteAddress,
    required Logic valueWriteData,
    required Logic valueWriteValid,
  }) : super(definitionName: 'ScratchpadAttentionHarness') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    command = addTypedInput('command', command);
    commandValid = addInput('commandValid', commandValid);
    resultReady = addInput('resultReady', resultReady);
    keyWriteAddress = addInput('keyWriteAddress', keyWriteAddress, width: 3);
    keyWriteData = addInput('keyWriteData', keyWriteData, width: 8);
    keyWriteValid = addInput('keyWriteValid', keyWriteValid);
    valueWriteAddress = addInput(
      'valueWriteAddress',
      valueWriteAddress,
      width: 3,
    );
    valueWriteData = addInput('valueWriteData', valueWriteData, width: 16);
    valueWriteValid = addInput('valueWriteValid', valueWriteValid);

    final commandLink = ValidThenReadyInterface(command.clone());
    final resultLink = ReadyValidInterface(
      ScratchpadFixedPointAttentionResult(
        valueDimension: 2,
        outputWidth: 8,
        requestIdWidth: 3,
        name: 'resultLink',
      ),
    );
    commandLink.data <= command;
    commandLink.valid <= commandValid;
    resultLink.ready <= resultReady;

    final keyReadRequest = ReadyValidInterface(
      TensorScratchpadReadRequest(
        addressWidth: 3,
        tagWidth: 2,
        name: 'keyReadRequest',
      ),
    );
    final keyReadResponse = ReadyValidInterface(
      TensorScratchpadReadResponse(
        data: Logic(width: 8),
        tagWidth: 2,
        name: 'keyReadResponse',
      ),
    );
    final keyWriteRequest = ValidThenReadyInterface(
      TensorScratchpadWriteRequest(
        addressWidth: 3,
        data: Logic(width: 8),
        name: 'keyWriteRequest',
      ),
    );
    keyWriteRequest.data.address <= keyWriteAddress;
    keyWriteRequest.data.data <= keyWriteData;
    keyWriteRequest.valid <= keyWriteValid;
    final keyScratchpad = TensorScratchpad(
      clk: clk,
      reset: reset,
      readRequests: [keyReadRequest],
      readResponses: [keyReadResponse],
      writeRequests: [keyWriteRequest],
      depth: 8,
      bankCount: 2,
      name: 'keyScratchpad',
    );

    final valueReadRequest = ReadyValidInterface(
      TensorScratchpadReadRequest(
        addressWidth: 3,
        tagWidth: 2,
        name: 'valueReadRequest',
      ),
    );
    final valueReadResponse = ReadyValidInterface(
      TensorScratchpadReadResponse(
        data: Logic(width: 16),
        tagWidth: 2,
        name: 'valueReadResponse',
      ),
    );
    final valueWriteRequest = ValidThenReadyInterface(
      TensorScratchpadWriteRequest(
        addressWidth: 3,
        data: Logic(width: 16),
        name: 'valueWriteRequest',
      ),
    );
    valueWriteRequest.data.address <= valueWriteAddress;
    valueWriteRequest.data.data <= valueWriteData;
    valueWriteRequest.valid <= valueWriteValid;
    final valueScratchpad = TensorScratchpad(
      clk: clk,
      reset: reset,
      readRequests: [valueReadRequest],
      readResponses: [valueReadResponse],
      writeRequests: [valueWriteRequest],
      depth: 8,
      bankCount: 2,
      name: 'valueScratchpad',
    );

    final attention = ScratchpadFixedPointAttention(
      clk: clk,
      reset: reset,
      command: commandLink,
      keyReadRequest: keyReadRequest,
      keyReadResponse: keyReadResponse,
      valueReadRequest: valueReadRequest,
      valueReadResponse: valueReadResponse,
      result: resultLink,
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

    addOutput('commandReady') <= commandLink.ready;
    addOutput('keyWriteReady') <= keyWriteRequest.ready;
    addOutput('valueWriteReady') <= valueWriteRequest.ready;
    final resultOutput = addTypedOutput('result', resultLink.data.clone);
    resultOutput <= resultLink.data;
    addOutput('resultValid') <= resultLink.valid;
    addOutput('busy') <= attention.busy;
    addOutput('memoryReadBytes', width: 16) <= attention.memoryReadBytes;
    addOutput('keyBankConflicts', width: 2) <= keyScratchpad.bankConflicts;
    addOutput('valueBankConflicts', width: 2) <= valueScratchpad.bankConflicts;
  }
}
