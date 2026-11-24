// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// attention_engine_example.dart
// A small fixed-point inference engine composed from public ROHD-HCL APIs.
//
// 2026 November 23
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

const _addressWidth = 3;
const _sequenceLength = 3;
const _headDimension = 2;
const _valueDimension = 2;
const _keyWidth = 4;
const _valueWidth = 8;
const _requestIdWidth = 3;

/// One fixed-point attention head with independently writable key/value banks.
///
/// Load KV rows before issuing a command. Do not overwrite rows in use by
/// an outstanding query.
class AttentionEngine extends Module {
  AttentionEngine({
    required Logic clk,
    required Logic reset,
    required ValidThenReadyInterface<TensorScratchpadWriteRequest<LogicArray>>
        keyWrites,
    required ValidThenReadyInterface<TensorScratchpadWriteRequest<LogicArray>>
        valueWrites,
    required ValidThenReadyInterface<ScratchpadFixedPointAttentionCommand>
        commands,
    required ReadyValidInterface<ScratchpadFixedPointAttentionResult> results,
  }) : super(definitionName: 'AttentionEngine') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    final commandPort = addPairInterface(
      commands,
      PairRole.consumer,
      uniquify: (port) => 'command_$port',
    );
    final resultPort = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(results.data.clone()),
      results,
      PairRole.provider,
      uniquify: (port) => 'result_$port',
    );

    // The scratchpads and attention block share typed request/response links.
    final keys = _attachBank(clk, reset, keyWrites, 'key');
    final values = _attachBank(clk, reset, valueWrites, 'value');
    ScratchpadFixedPointAttention(
      clk: clk,
      reset: reset,
      command: commandPort,
      keyReadRequest: keys.request,
      keyReadResponse: keys.response,
      valueReadRequest: values.request,
      valueReadResponse: values.response,
      result: resultPort,
      valueDimension: _valueDimension,
      valueWidth: _valueWidth,
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
      outputWidth: _valueWidth,
      counterWidth: 16,
    );
  }

  ({
    ReadyValidInterface<TensorScratchpadReadRequest> request,
    ReadyValidInterface<TensorScratchpadReadResponse<LogicArray>> response,
  }) _attachBank(
    Logic clk,
    Logic reset,
    ValidThenReadyInterface<TensorScratchpadWriteRequest<LogicArray>> writes,
    String label,
  ) {
    final writePort = addPairInterface(
      writes,
      PairRole.consumer,
      uniquify: (port) => '${label}_write_$port',
    );
    final request = ReadyValidInterface(
      TensorScratchpadReadRequest(addressWidth: _addressWidth, tagWidth: 2),
    );
    final response = ReadyValidInterface(
      TensorScratchpadReadResponse(
        data: writes.data.data,
        tagWidth: 2,
      ),
    );
    TensorScratchpad(
      clk: clk,
      reset: reset,
      readRequests: [request],
      readResponses: [response],
      writeRequests: [writePort],
      depth: 1 << _addressWidth,
      bankCount: 2,
      name: '${label}_scratchpad',
    );
    return (request: request, response: response);
  }
}

/// Simulates one attention request and returns the checked result and RTL.
Future<({List<int> values, String systemVerilog})> runAttentionExample() async {
  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic();
  final keyWrites = ValidThenReadyInterface(
    TensorScratchpadWriteRequest(
      addressWidth: _addressWidth,
      data: LogicArray([_headDimension], _keyWidth),
    ),
  );
  final valueWrites = ValidThenReadyInterface(
    TensorScratchpadWriteRequest(
      addressWidth: _addressWidth,
      data: LogicArray([_valueDimension], _valueWidth),
    ),
  );
  final commands = ValidThenReadyInterface(
    ScratchpadFixedPointAttentionCommand(
      sequenceLength: _sequenceLength,
      headDimension: _headDimension,
      elementWidth: _keyWidth,
      keyAddressWidth: _addressWidth,
      valueAddressWidth: _addressWidth,
      requestIdWidth: _requestIdWidth,
    ),
  );
  final results = ReadyValidInterface(
    ScratchpadFixedPointAttentionResult(
      valueDimension: _valueDimension,
      outputWidth: _valueWidth,
      requestIdWidth: _requestIdWidth,
    ),
  );
  final engine = AttentionEngine(
    clk: clk,
    reset: reset,
    keyWrites: keyWrites,
    valueWrites: valueWrites,
    commands: commands,
    results: results,
  );
  await engine.build();

  Future<void> waitForHigh(Logic signal, String description) async {
    for (var cycle = 0; cycle < 64; cycle++) {
      await clk.nextNegedge;
      if (signal.value == LogicValue.one) {
        return;
      }
    }
    throw StateError('Timed out waiting for $description.');
  }

  Future<void> writeRow(
    ValidThenReadyInterface<TensorScratchpadWriteRequest<LogicArray>> writes,
    int address,
    int packedRow,
  ) async {
    writes.data.address.inject(address);
    writes.data.data.inject(packedRow);
    writes.valid.inject(1);
    await waitForHigh(writes.ready, 'scratchpad write ready');
    await clk.nextPosedge;
    writes.valid.inject(0);
  }

  reset.inject(1);
  for (final port in [keyWrites, valueWrites, commands]) {
    port.valid.inject(0);
    port.data.inject(0);
  }
  results.ready.inject(0);
  final simulation = Simulator.run();
  try {
    await clk.nextPosedge;
    reset.inject(0);

    // Lane zero occupies the low bits. Query [1, 0] gives scores [0, -1, -2].
    const keyRows = [0x00, 0x0f, 0x0e];
    const valueRows = [0x0004, 0x0400, 0x0404];
    for (var row = 0; row < _sequenceLength; row++) {
      await writeRow(keyWrites, row, keyRows[row]);
      await writeRow(valueWrites, row, valueRows[row]);
    }

    final command = commands.data;
    command.query.arrayElements[0].inject(1);
    command.query.arrayElements[1].inject(0);
    command.keyBaseAddress.inject(0);
    command.valueBaseAddress.inject(0);
    command.keyMask.inject(0x7);
    command.laneMask.inject(0x3);
    command.causalKeyCount.inject(_sequenceLength);
    command.requestId.inject(5);
    commands.valid.inject(1);
    await waitForHigh(commands.ready, 'command ready');
    await clk.nextPosedge;
    commands.valid.inject(0);

    await waitForHigh(results.valid, 'attention result');
    final result = results.data;
    final values = [
      for (final lane in result.values.value.arrayValues)
        lane.toBigInt().toSigned(_valueWidth).toInt(),
    ];
    if (values[0] != 3 ||
        values[1] != 2 ||
        result.requestId.value.toInt() != 5 ||
        result.memoryError.value != LogicValue.zero ||
        result.protocolError.value != LogicValue.zero ||
        result.addressOverflow.value != LogicValue.zero) {
      throw StateError(
        'Unexpected attention result: $values (${result.value}).',
      );
    }

    // A stalled consumer must see the same valid payload on the next cycle.
    final retained = result.value;
    await clk.nextNegedge;
    if (results.valid.value != LogicValue.one || result.value != retained) {
      throw StateError('Attention result changed under backpressure.');
    }
    results.ready.inject(1);
    await clk.nextPosedge;
    await clk.nextNegedge;
    if (results.valid.value != LogicValue.zero) {
      throw StateError('Consumed attention result did not retire.');
    }
    return (values: values, systemVerilog: engine.dumpSystemVerilog());
  } finally {
    await Simulator.endSimulation();
    await simulation;
  }
}

Future<void> main(List<String> args) async {
  if (args.length > 1) {
    throw ArgumentError('Expected at most one argument: the output HDL path.');
  }
  final path = args.isEmpty ? 'attention_engine.sv' : args.single;
  final example = await runAttentionExample();
  await File(path).writeAsString(example.systemVerilog);
  stdout.writeln('Attention result: ${example.values}. Wrote $path.');
}
