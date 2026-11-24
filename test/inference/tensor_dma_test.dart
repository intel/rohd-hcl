// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_dma_test.dart
// Tests for Tensor Dma.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('registers every DMA interface direction as a module port', () async {
    final fixture = _TensorDmaFixture();
    await fixture.dut.build();

    expect(
      fixture.dut.inputs.keys.where((name) => name.startsWith('command_')),
      hasLength(2),
    );
    expect(fixture.dut.outputs, contains('command_ready'));
    expect(fixture.dut.inputs, contains('source_read_request_ready'));
    expect(
      fixture.dut.outputs.keys
          .where((name) => name.startsWith('source_read_request_')),
      hasLength(2),
    );
    expect(
      fixture.dut.inputs.keys
          .where((name) => name.startsWith('source_read_response_')),
      hasLength(2),
    );
    expect(fixture.dut.outputs, contains('source_read_response_ready'));
    expect(fixture.dut.inputs, contains('destination_write_request_ready'));
    expect(
      fixture.dut.outputs.keys
          .where((name) => name.startsWith('destination_write_request_')),
      hasLength(2),
    );
    expect(fixture.dut.inputs, contains('completion_ready'));
    expect(
      fixture.dut.outputs.keys.where((name) => name.startsWith('completion_')),
      hasLength(2),
    );
  });

  test('copies a strided tensor and retains writes and completion', () async {
    final fixture = _TensorDmaFixture();
    await fixture.buildAndReset();
    await fixture.startCommand(
      sourceBase: 10,
      destinationBase: 40,
      mExtent: 1,
      nExtent: 2,
      kExtent: 2,
      sourceNStride: 4,
      sourceKStride: 1,
      destinationNStride: 8,
      destinationKStride: 2,
      commandId: 9,
    );

    final expectedSourceAddresses = [10, 11, 14, 15];
    final expectedDestinationAddresses = [40, 42, 48, 50];
    final expectedData = [0x31, 0x42, 0x53, 0x64];
    for (var beat = 0; beat < expectedSourceAddresses.length; beat++) {
      final request = await fixture.acceptReadRequest(
        stallCycles: beat == 0 ? 1 : 0,
      );
      expect(request.$1, expectedSourceAddresses[beat]);
      expect(request.$2, beat);

      await fixture.sendReadResponse(
        data: expectedData[beat],
        tag: request.$2,
      );
      final write = await fixture.acceptWrite(
        stallCycles: beat == 0 ? 2 : 0,
      );
      expect(write.$1, expectedDestinationAddresses[beat]);
      expect(write.$2, expectedData[beat]);
    }

    await fixture.waitForCompletion();
    expect(fixture.completion.data.commandId.value.toInt(), 9);
    expect(fixture.completion.data.transferredCount.value.toInt(), 4);
    expect(fixture.completion.data.error.value, LogicValue.zero);
    final retainedCompletion = fixture.completion.data.value;
    await fixture.clk.nextPosedge;
    await fixture.clk.nextNegedge;
    expect(fixture.completion.valid.value, LogicValue.one);
    expect(fixture.completion.data.value, retainedCompletion);
    expect(fixture.dut.commandsAccepted.value.toInt(), 1);
    expect(fixture.dut.readRequestsIssued.value.toInt(), 4);
    expect(fixture.dut.writesCompleted.value.toInt(), 4);
    expect(fixture.dut.failedCommands.value.toInt(), 0);
    expect(fixture.dut.readStallCycles.value.toInt(), greaterThanOrEqualTo(1));
    expect(fixture.dut.writeStallCycles.value.toInt(), greaterThanOrEqualTo(2));
    expect(
      fixture.dut.completionStallCycles.value.toInt(),
      greaterThanOrEqualTo(1),
    );
    await fixture.acceptCompletion();
    expect(fixture.dut.busy.value, LogicValue.zero);
    await Simulator.endSimulation();
  });

  test('reports source and tag errors without writing failed beats', () async {
    final fixture = _TensorDmaFixture();
    await fixture.buildAndReset();
    await fixture.startCommand(
      sourceBase: 2,
      destinationBase: 20,
      mExtent: 1,
      nExtent: 1,
      kExtent: 2,
      sourceKStride: 1,
      destinationKStride: 1,
      commandId: 3,
    );

    final first = await fixture.acceptReadRequest();
    await fixture.sendReadResponse(data: 0xaa, tag: first.$2, error: true);
    expect(fixture.destinationWriteRequest.valid.value, LogicValue.zero);

    final second = await fixture.acceptReadRequest();
    await fixture.sendReadResponse(data: 0xbb, tag: second.$2 ^ 1);
    expect(fixture.destinationWriteRequest.valid.value, LogicValue.zero);

    await fixture.waitForCompletion();
    expect(fixture.completion.data.error.value, LogicValue.one);
    expect(fixture.completion.data.sourceError.value, LogicValue.one);
    expect(fixture.completion.data.protocolError.value, LogicValue.one);
    expect(fixture.completion.data.addressError.value, LogicValue.zero);
    expect(fixture.completion.data.transferredCount.value.toInt(), 0);
    await fixture.acceptCompletion();
    expect(fixture.dut.failedCommands.value.toInt(), 1);
    await Simulator.endSimulation();
  });

  test('skips out-of-range addresses and reports partial completion', () async {
    final fixture = _TensorDmaFixture(
      sourceDepth: 12,
    );
    await fixture.buildAndReset();
    await fixture.startCommand(
      sourceBase: 10,
      destinationBase: 30,
      mExtent: 1,
      nExtent: 1,
      kExtent: 2,
      sourceKStride: 2,
      destinationKStride: 1,
      commandId: 5,
    );

    final request = await fixture.acceptReadRequest();
    expect(request.$1, 10);
    await fixture.sendReadResponse(data: 0x5a, tag: request.$2);
    final write = await fixture.acceptWrite();
    expect(write, (30, 0x5a));

    await fixture.waitForCompletion();
    expect(fixture.dut.readRequestsIssued.value.toInt(), 1);
    expect(fixture.dut.writesCompleted.value.toInt(), 1);
    expect(fixture.completion.data.transferredCount.value.toInt(), 1);
    expect(fixture.completion.data.error.value, LogicValue.one);
    expect(fixture.completion.data.addressError.value, LogicValue.one);
    expect(fixture.completion.data.sourceError.value, LogicValue.zero);
    await fixture.acceptCompletion();
    await Simulator.endSimulation();
  });

  test('completes a zero-extent command without issuing traffic', () async {
    final fixture = _TensorDmaFixture();
    await fixture.buildAndReset();
    await fixture.startCommand(
      sourceBase: 0,
      destinationBase: 0,
      mExtent: 0,
      nExtent: 1,
      kExtent: 1,
      commandId: 7,
    );

    await fixture.waitForCompletion();
    expect(fixture.sourceReadRequest.valid.value, LogicValue.zero);
    expect(fixture.destinationWriteRequest.valid.value, LogicValue.zero);
    expect(fixture.completion.data.commandId.value.toInt(), 7);
    expect(fixture.completion.data.transferredCount.value.toInt(), 0);
    expect(fixture.completion.data.error.value, LogicValue.one);
    expect(fixture.completion.data.invalidCommand.value, LogicValue.one);
    await fixture.acceptCompletion();
    await Simulator.endSimulation();
  });

  for (final useSram in [false, true]) {
    test('copies typed tiles through nested DMA and scratchpads, SRAM=$useSram',
        () async {
      final schema = inferenceLogicTensorTile(
        rowCount: 1,
        columnCount: 2,
        format: InferenceNumericFormat.signedInteger(8),
      );
      final fixture = _ScratchpadDmaFixture(
        schema,
        memoryFunctor: useSram
            ? inferredSramArray<InferenceTensorTile<Logic, LogicValue>>()
            : null,
      );
      await fixture.buildAndReset();
      await fixture.preload(0, 0x71234);
      await fixture.preload(1, 0x75678);
      await fixture.startCommand(
          sourceBase: 0,
          destinationBase: 8,
          nExtent: 1,
          kExtent: 2,
          nStride: 2,
          commandId: 3);
      await fixture.waitForCompletion();
      expect(fixture.completion.data.error.value, LogicValue.zero);
      expect(fixture.completion.data.transferredCount.value.toInt(), 2);
      await fixture.acceptCompletion();
      expect(await fixture.readDestination(8), 0x71234);
      expect(await fixture.readDestination(9), 0x75678);
      final returnedTile = fixture.destinationResponse.data.data;
      expect(returnedTile.format, same(schema.format));
      expect(returnedTile.data.dimensions, [1, 2]);
      expect(returnedTile.data.arrayElements[0].value.toInt(), 0x78);
      expect(returnedTile.data.arrayElements[1].value.toInt(), 0x56);
      expect(returnedTile.rowMask.value.toInt(), 1);
      expect(returnedTile.columnMask.value.toInt(), 3);
      await Simulator.endSimulation();
      final directory =
          await Directory.systemTemp.createTemp('typed_tensor_dma_');
      try {
        final source = File('${directory.path}/dma.sv');
        await source.writeAsString(fixture.dut.dumpSystemVerilog());
        final compile =
            await Process.run('iverilog', ['-g2012', '-tnull', source.path]);
        expect(compile.exitCode, 0,
            reason: '${compile.stdout}\n${compile.stderr}');
      } finally {
        await directory.delete(recursive: true);
      }
    });
  }

  test('DMA rejects equal-width words with incompatible numeric schemas', () {
    final source = inferenceLogicTensorTile(
        rowCount: 1,
        columnCount: 2,
        format: InferenceNumericFormat.signedInteger(8));
    final destination = inferenceLogicTensorTile(
        rowCount: 1,
        columnCount: 2,
        format: InferenceNumericFormat.unsignedInteger(8));
    final fixture =
        _ScratchpadDmaFixture(source, destinationSchema: destination);
    expect(() => fixture.dut, throwsArgumentError);
  });

  test('copies data between banked tensor scratchpads', () async {
    final fixture = _ScratchpadDmaFixture(Logic(width: 8));
    await fixture.buildAndReset();
    final sourceContents = {
      2: 0x12,
      3: 0x23,
      6: 0x46,
      7: 0x57,
    };
    for (final MapEntry(key: address, value: data) in sourceContents.entries) {
      await fixture.preload(address, data);
    }

    await fixture.startCommand(
      sourceBase: 2,
      destinationBase: 8,
      nExtent: 2,
      kExtent: 2,
      nStride: 4,
      commandId: 6,
    );
    await fixture.waitForCompletion();
    expect(fixture.completion.data.commandId.value.toInt(), 6);
    expect(
      fixture.completion.data.error.value,
      LogicValue.zero,
      reason: 'invalid=${fixture.completion.data.invalidCommand.value}, '
          'source=${fixture.completion.data.sourceError.value}, '
          'address=${fixture.completion.data.addressError.value}, '
          'protocol=${fixture.completion.data.protocolError.value}',
    );
    expect(fixture.completion.data.transferredCount.value.toInt(), 4);
    await fixture.acceptCompletion();

    final expectedDestination = {
      8: 0x12,
      9: 0x23,
      12: 0x46,
      13: 0x57,
    };
    for (final MapEntry(key: address, value: data)
        in expectedDestination.entries) {
      expect(await fixture.readDestination(address), data);
    }
    await Simulator.endSimulation();
  });
}

class _TensorDmaFixture {
  static const sourceAddressWidth = 8;
  static const destinationAddressWidth = 8;
  static const dataWidth = 8;
  static const tagWidth = 3;
  static const mWidth = 2;
  static const nWidth = 2;
  static const kWidth = 2;
  static const commandIdWidth = 4;

  final Logic clk = SimpleClockGenerator(10).clk;
  final Logic reset = Logic();
  final ReadyAndValidInterface<TensorDmaCommand> command =
      ReadyAndValidInterface(
    TensorDmaCommand(
      sourceAddressWidth: sourceAddressWidth,
      destinationAddressWidth: destinationAddressWidth,
      mWidth: mWidth,
      nWidth: nWidth,
      kWidth: kWidth,
      commandIdWidth: commandIdWidth,
      name: 'dmaCommand',
    ),
  );
  final ReadyAndValidInterface<TensorScratchpadReadRequest> sourceReadRequest =
      ReadyAndValidInterface(
    TensorScratchpadReadRequest(
      addressWidth: sourceAddressWidth,
      tagWidth: tagWidth,
      name: 'sourceReadRequest',
    ),
  );
  final IrrevocableReadyValidInterface<TensorScratchpadReadResponse>
      sourceReadResponse = IrrevocableReadyValidInterface(
    TensorScratchpadReadResponse(
      data: Logic(width: dataWidth),
      tagWidth: tagWidth,
      name: 'sourceReadResponse',
    ),
  );
  final ReadyAndValidInterface<TensorScratchpadWriteRequest>
      destinationWriteRequest = ReadyAndValidInterface(
    TensorScratchpadWriteRequest(
      addressWidth: destinationAddressWidth,
      data: Logic(width: dataWidth),
      name: 'destinationWriteRequest',
    ),
  );
  final ReadyAndValidInterface<TensorDmaCompletion> completion =
      ReadyAndValidInterface(
    TensorDmaCompletion(
      commandIdWidth: commandIdWidth,
      countWidth: tensorDmaCountWidth(
        mWidth: mWidth,
        nWidth: nWidth,
        kWidth: kWidth,
      ),
      name: 'dmaCompletion',
    ),
  );
  late final TensorDmaEngine dut;

  _TensorDmaFixture({
    int? sourceDepth = 64,
    int? destinationDepth = 64,
  }) {
    dut = TensorDmaEngine(
      clk: clk,
      reset: reset,
      command: command,
      sourceReadRequest: sourceReadRequest,
      sourceReadResponse: sourceReadResponse,
      destinationWriteRequest: destinationWriteRequest,
      completion: completion,
      sourceDepth: sourceDepth,
      destinationDepth: destinationDepth,
      counterWidth: 16,
    );
  }

  Future<void> buildAndReset() async {
    await dut.build();
    Simulator.setMaxSimTime(20000);
    unawaited(Simulator.run());
    reset.inject(1);
    command.valid.inject(0);
    command.data.inject(0);
    sourceReadRequest.ready.inject(0);
    sourceReadResponse.valid.inject(0);
    sourceReadResponse.data.inject(0);
    destinationWriteRequest.ready.inject(0);
    completion.ready.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextNegedge;
  }

  Future<void> startCommand({
    required int sourceBase,
    required int destinationBase,
    required int mExtent,
    required int nExtent,
    required int kExtent,
    required int commandId,
    int sourceMStride = 0,
    int sourceNStride = 0,
    int sourceKStride = 0,
    int destinationMStride = 0,
    int destinationNStride = 0,
    int destinationKStride = 0,
  }) async {
    await clk.nextPosedge;
    command.data.sourceBaseAddress.inject(sourceBase);
    command.data.destinationBaseAddress.inject(destinationBase);
    command.data.mExtent.inject(mExtent);
    command.data.nExtent.inject(nExtent);
    command.data.kExtent.inject(kExtent);
    command.data.sourceMStride.inject(sourceMStride);
    command.data.sourceNStride.inject(sourceNStride);
    command.data.sourceKStride.inject(sourceKStride);
    command.data.destinationMStride.inject(destinationMStride);
    command.data.destinationNStride.inject(destinationNStride);
    command.data.destinationKStride.inject(destinationKStride);
    command.data.commandId.inject(commandId);
    command.valid.inject(1);
    await clk.nextNegedge;
    expect(command.ready.value, LogicValue.one);
    await clk.nextPosedge;
    await clk.nextNegedge;
    command.valid.inject(0);
  }

  Future<(int, int)> acceptReadRequest({int stallCycles = 0}) async {
    await _waitForHigh(sourceReadRequest.valid, 'source read request');
    final address = sourceReadRequest.data.address.value.toInt();
    final tag = sourceReadRequest.data.tag.value.toInt();
    for (var cycle = 0; cycle < stallCycles; cycle++) {
      await clk.nextPosedge;
      await clk.nextNegedge;
      expect(sourceReadRequest.valid.value, LogicValue.one);
      expect(sourceReadRequest.data.address.value.toInt(), address);
      expect(sourceReadRequest.data.tag.value.toInt(), tag);
    }
    sourceReadRequest.ready.inject(1);
    await clk.nextPosedge;
    await clk.nextNegedge;
    sourceReadRequest.ready.inject(0);
    return (address, tag);
  }

  Future<void> sendReadResponse({
    required int data,
    required int tag,
    bool error = false,
  }) async {
    sourceReadResponse.data.data.inject(data);
    sourceReadResponse.data.tag.inject(tag);
    sourceReadResponse.data.error.inject(error ? 1 : 0);
    sourceReadResponse.valid.inject(1);
    await _waitForHigh(sourceReadResponse.ready, 'source response ready');
    await clk.nextPosedge;
    await clk.nextNegedge;
    sourceReadResponse.valid.inject(0);
  }

  Future<(int, int)> acceptWrite({int stallCycles = 0}) async {
    await _waitForHigh(destinationWriteRequest.valid, 'destination write');
    final address = destinationWriteRequest.data.address.value.toInt();
    final data = destinationWriteRequest.data.data.value.toInt();
    for (var cycle = 0; cycle < stallCycles; cycle++) {
      await clk.nextPosedge;
      await clk.nextNegedge;
      expect(destinationWriteRequest.valid.value, LogicValue.one);
      expect(destinationWriteRequest.data.address.value.toInt(), address);
      expect(destinationWriteRequest.data.data.value.toInt(), data);
    }
    destinationWriteRequest.ready.inject(1);
    await clk.nextPosedge;
    await clk.nextNegedge;
    destinationWriteRequest.ready.inject(0);
    return (address, data);
  }

  Future<void> waitForCompletion() =>
      _waitForHigh(completion.valid, 'DMA completion');

  Future<void> acceptCompletion() async {
    completion.ready.inject(1);
    await clk.nextPosedge;
    await clk.nextNegedge;
    completion.ready.inject(0);
  }

  Future<void> _waitForHigh(Logic signal, String description) async {
    for (var cycle = 0; cycle < 40; cycle++) {
      if (signal.value == LogicValue.one) {
        return;
      }
      await clk.nextNegedge;
    }
    fail('Timed out waiting for $description.');
  }
}

class _TensorDmaScratchpadHarness<T extends Logic> extends Module {
  _TensorDmaScratchpadHarness({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<TensorDmaCommand> command,
    required ReadyValidInterface<TensorScratchpadWriteRequest<T>> sourcePreload,
    required ReadyValidInterface<TensorScratchpadReadRequest> destinationRead,
    required ReadyValidInterface<TensorScratchpadReadResponse<T>>
        destinationResponse,
    required ReadyValidInterface<TensorDmaCompletion> completion,
    MemoryArrayFunctor<T>? memoryFunctor,
  }) : super(definitionName: 'TensorDmaScratchpadHarness') {
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localCommand = addPairInterface(
      command,
      PairRole.consumer,
      uniquify: (original) => 'command_$original',
    );
    final localSourcePreload = addPairInterface(
      sourcePreload,
      PairRole.consumer,
      uniquify: (original) => 'source_preload_$original',
    );
    final localDestinationRead = addPairInterface(
      destinationRead,
      PairRole.consumer,
      uniquify: (original) => 'destination_read_$original',
    );
    final localDestinationResponse = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(destinationResponse.data.clone()),
      destinationResponse,
      PairRole.provider,
      uniquify: (original) => 'destination_response_$original',
    );
    final localCompletion = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(completion.data.clone()),
      completion,
      PairRole.provider,
      uniquify: (original) => 'completion_$original',
    );
    final sourceReadRequest = ReadyValidInterface(
      TensorScratchpadReadRequest(
        addressWidth: 4,
        tagWidth: 2,
        name: 'dmaSourceReadRequest',
      ),
    );
    final sourceReadResponse = ReadyValidInterface(
      TensorScratchpadReadResponse(
        data: localSourcePreload.data.data,
        tagWidth: 2,
        name: 'dmaSourceReadResponse',
      ),
    );
    final destinationWriteRequest = ReadyValidInterface(
      TensorScratchpadWriteRequest(
        addressWidth: 4,
        data: localDestinationResponse.data.data,
        name: 'dmaDestinationWriteRequest',
      ),
    );

    TensorDmaEngine(
      clk: localClk,
      reset: localReset,
      command: localCommand,
      sourceReadRequest: sourceReadRequest,
      sourceReadResponse: sourceReadResponse,
      destinationWriteRequest: destinationWriteRequest,
      completion: localCompletion,
      sourceDepth: 16,
      destinationDepth: 16,
      counterWidth: 16,
      name: 'dma',
    );
    TensorScratchpad(
      clk: localClk,
      reset: localReset,
      readRequests: [sourceReadRequest],
      readResponses: [sourceReadResponse],
      writeRequests: [localSourcePreload],
      depth: 16,
      bankCount: 2,
      memoryFunctor: memoryFunctor,
      name: 'sourceScratchpad',
    );
    TensorScratchpad(
      clk: localClk,
      reset: localReset,
      readRequests: [localDestinationRead],
      readResponses: [localDestinationResponse],
      writeRequests: [destinationWriteRequest],
      depth: 16,
      bankCount: 2,
      memoryFunctor: memoryFunctor,
      name: 'destinationScratchpad',
    );
  }
}

class _ScratchpadDmaFixture<T extends Logic> {
  final MemoryArrayFunctor<T>? memoryFunctor;

  _ScratchpadDmaFixture(T wordSchema,
      {T? destinationSchema, this.memoryFunctor})
      : sourcePreload = ReadyAndValidInterface(
          TensorScratchpadWriteRequest<T>(
            addressWidth: 4,
            data: wordSchema,
            name: 'sourcePreload',
          ),
        ),
        destinationResponse = ReadyAndValidInterface(
          TensorScratchpadReadResponse<T>(
            data: destinationSchema ?? wordSchema,
            tagWidth: 2,
            name: 'destinationResponse',
          ),
        );

  final Logic clk = SimpleClockGenerator(10).clk;
  final Logic reset = Logic();
  final ReadyAndValidInterface<TensorDmaCommand> command =
      ReadyAndValidInterface(
    TensorDmaCommand(
      sourceAddressWidth: 4,
      destinationAddressWidth: 4,
      mWidth: 2,
      nWidth: 2,
      kWidth: 2,
      commandIdWidth: 3,
      name: 'integratedDmaCommand',
    ),
  );
  final ReadyAndValidInterface<TensorScratchpadWriteRequest<T>> sourcePreload;
  final ReadyAndValidInterface<TensorScratchpadReadRequest> destinationRead =
      ReadyAndValidInterface(
    TensorScratchpadReadRequest(
      addressWidth: 4,
      tagWidth: 2,
      name: 'destinationRead',
    ),
  );
  final ReadyAndValidInterface<TensorScratchpadReadResponse<T>>
      destinationResponse;
  final ReadyAndValidInterface<TensorDmaCompletion> completion =
      ReadyAndValidInterface(
    TensorDmaCompletion(
      commandIdWidth: 3,
      countWidth: tensorDmaCountWidth(mWidth: 2, nWidth: 2, kWidth: 2),
      name: 'integratedDmaCompletion',
    ),
  );
  late final _TensorDmaScratchpadHarness<T> dut =
      _TensorDmaScratchpadHarness<T>(
    clk: clk,
    reset: reset,
    command: command,
    sourcePreload: sourcePreload,
    destinationRead: destinationRead,
    destinationResponse: destinationResponse,
    completion: completion,
    memoryFunctor: memoryFunctor,
  );

  Future<void> buildAndReset() async {
    await dut.build();
    Simulator.setMaxSimTime(30000);
    unawaited(Simulator.run());
    reset.inject(1);
    command.valid.inject(0);
    command.data.inject(0);
    sourcePreload.valid.inject(0);
    sourcePreload.data.inject(0);
    destinationRead.valid.inject(0);
    destinationRead.data.inject(0);
    destinationResponse.ready.inject(0);
    completion.ready.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextNegedge;
  }

  Future<void> preload(int address, int data) async {
    sourcePreload.data.address.inject(address);
    sourcePreload.data.data.inject(data);
    sourcePreload.valid.inject(1);
    await _waitForHigh(sourcePreload.ready, 'source preload ready');
    await clk.nextPosedge;
    await clk.nextNegedge;
    sourcePreload.valid.inject(0);
  }

  Future<void> startCommand({
    required int sourceBase,
    required int destinationBase,
    required int nExtent,
    required int kExtent,
    required int nStride,
    required int commandId,
  }) async {
    command.data.sourceBaseAddress.inject(sourceBase);
    command.data.destinationBaseAddress.inject(destinationBase);
    command.data.mExtent.inject(1);
    command.data.nExtent.inject(nExtent);
    command.data.kExtent.inject(kExtent);
    command.data.sourceMStride.inject(0);
    command.data.sourceNStride.inject(nStride);
    command.data.sourceKStride.inject(1);
    command.data.destinationMStride.inject(0);
    command.data.destinationNStride.inject(nStride);
    command.data.destinationKStride.inject(1);
    command.data.commandId.inject(commandId);
    command.valid.inject(1);
    await _waitForHigh(command.ready, 'integrated DMA command ready');
    await clk.nextPosedge;
    await clk.nextNegedge;
    command.valid.inject(0);
  }

  Future<void> waitForCompletion() =>
      _waitForHigh(completion.valid, 'integrated DMA completion');

  Future<void> acceptCompletion() async {
    completion.ready.inject(1);
    await clk.nextPosedge;
    await clk.nextNegedge;
    completion.ready.inject(0);
  }

  Future<int> readDestination(int address) async {
    destinationRead.data.address.inject(address);
    destinationRead.data.tag.inject(0);
    destinationRead.valid.inject(1);
    await _waitForHigh(destinationRead.ready, 'destination read ready');
    await clk.nextPosedge;
    await clk.nextNegedge;
    destinationRead.valid.inject(0);
    await _waitForHigh(destinationResponse.valid, 'destination response');
    final data = destinationResponse.data.data.value.toInt();
    expect(destinationResponse.data.error.value, LogicValue.zero);
    destinationResponse.ready.inject(1);
    await clk.nextPosedge;
    await clk.nextNegedge;
    destinationResponse.ready.inject(0);
    return data;
  }

  Future<void> _waitForHigh(Logic signal, String description) async {
    for (var cycle = 0; cycle < 100; cycle++) {
      if (signal.value == LogicValue.one) {
        return;
      }
      await clk.nextNegedge;
    }
    fail('Timed out waiting for $description.');
  }
}
