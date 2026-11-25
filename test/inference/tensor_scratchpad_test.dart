// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_scratchpad_test.dart
// Tests for Tensor Scratchpad.
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

  test('registers every interface direction as a scratchpad port', () async {
    final fixture = _ScratchpadFixture();
    await fixture.dut.build();
    for (var port = 0; port < 2; port++) {
      expect(
        fixture.dut.inputs.keys.where(
          (name) => name.startsWith('read_${port}_'),
        ),
        hasLength(2),
      );
      expect(fixture.dut.outputs, contains('read_${port}_ready'));
      expect(fixture.dut.inputs, contains('response_${port}_ready'));
      expect(
        fixture.dut.outputs.keys.where(
          (name) => name.startsWith('response_${port}_'),
        ),
        hasLength(2),
      );
      expect(
        fixture.dut.inputs.keys.where(
          (name) => name.startsWith('write_${port}_'),
        ),
        hasLength(2),
      );
      expect(fixture.dut.outputs, contains('write_${port}_ready'));
    }
  });

  test(
    'services different banks concurrently and returns request tags',
    () async {
      final fixture = _ScratchpadFixture();
      await fixture.buildAndReset();

      fixture
        ..driveWrite(0, address: 0, data: 0x11)
        ..driveWrite(1, address: 1, data: 0x22);
      await fixture.clk.nextNegedge;
      expect(fixture.writeRequests[0].ready.value, LogicValue.one);
      expect(fixture.writeRequests[1].ready.value, LogicValue.one);
      await fixture.clk.nextPosedge;
      fixture
        ..clearWriteValids()
        ..driveRead(0, address: 0, tag: 1)
        ..driveRead(1, address: 1, tag: 2);
      await fixture.clk.nextNegedge;
      expect(fixture.readRequests[0].ready.value, LogicValue.one);
      expect(fixture.readRequests[1].ready.value, LogicValue.one);
      await fixture.clk.nextPosedge;
      fixture.clearReadValids();
      await fixture.waitForResponses();

      expect(fixture.readResponses[0].data.data.value.toInt(), 0x11);
      expect(fixture.readResponses[0].data.tag.value.toInt(), 1);
      expect(fixture.readResponses[1].data.data.value.toInt(), 0x22);
      expect(fixture.readResponses[1].data.tag.value.toInt(), 2);
      expect(fixture.dut.bankConflicts.value.toInt(), 0);
      expect(fixture.dut.responseOverflow.value.toInt(), 0);
      expect(fixture.dut.unexpectedResponse.value.toInt(), 0);
      await Simulator.endSimulation();
    },
  );

  test('retains a lower-priority conflicting write until admitted', () async {
    final fixture = _ScratchpadFixture();
    await fixture.buildAndReset();

    fixture
      ..driveWrite(0, address: 0, data: 0x31)
      ..driveWrite(1, address: 2, data: 0x42);
    await fixture.clk.nextNegedge;
    expect(fixture.writeRequests[0].ready.value, LogicValue.one);
    expect(fixture.writeRequests[1].ready.value, LogicValue.zero);
    expect(fixture.dut.bankConflicts.value[1], LogicValue.one);
    await fixture.clk.nextPosedge;
    fixture.writeRequests[0].valid.inject(0);
    await fixture.clk.nextNegedge;
    expect(fixture.writeRequests[1].ready.value, LogicValue.one);
    await fixture.clk.nextPosedge;
    fixture.writeRequests[1].valid.inject(0);

    await fixture.readOne(0, address: 0, tag: 0);
    expect(fixture.readResponses[0].data.data.value.toInt(), 0x31);
    await fixture.acceptResponse(0);
    await fixture.readOne(0, address: 2, tag: 0);
    expect(fixture.readResponses[0].data.data.value.toInt(), 0x42);
    await Simulator.endSimulation();
  });

  test(
    'retains a read response and blocks another outstanding request',
    () async {
      final fixture = _ScratchpadFixture();
      await fixture.buildAndReset();
      await fixture.writeOne(0, address: 0, data: 0x55);
      await fixture.writeOne(0, address: 1, data: 0x66);

      fixture.driveRead(0, address: 0, tag: 1);
      await fixture.clk.nextPosedge;
      fixture.readRequests[0].valid.inject(0);
      await fixture.waitForResponse(0);
      final retained = fixture.readResponses[0].data.value;
      fixture.driveRead(0, address: 1, tag: 2);
      await fixture.clk.nextNegedge;
      expect(fixture.readRequests[0].ready.value, LogicValue.zero);
      await fixture.clk.nextPosedge;
      expect(fixture.readResponses[0].data.value, retained);

      fixture.readResponses[0].ready.inject(1);
      await fixture.clk.nextNegedge;
      expect(fixture.readRequests[0].ready.value, LogicValue.one);
      await fixture.clk.nextPosedge;
      fixture.readResponses[0].ready.inject(0);
      fixture.readRequests[0].valid.inject(0);
      await fixture.waitForResponse(0);
      expect(fixture.readResponses[0].data.data.value.toInt(), 0x66);
      expect(fixture.readResponses[0].data.tag.value.toInt(), 2);
      await Simulator.endSimulation();
    },
  );

  test(
    'returns an error response for an invalid read and consumes bad writes',
    () async {
      final fixture = _ScratchpadFixture();
      await fixture.buildAndReset();

      await fixture.clk.nextPosedge;
      fixture.driveRead(0, address: 7, tag: 3);
      await fixture.clk.nextNegedge;
      expect(fixture.readRequests[0].ready.value, LogicValue.one);
      await fixture.clk.nextPosedge;
      fixture.readRequests[0].valid.inject(0);
      await fixture.waitForResponse(0);
      expect(fixture.readResponses[0].data.error.value, LogicValue.one);
      expect(fixture.readResponses[0].data.data.value.toInt(), 0);
      expect(fixture.readResponses[0].data.tag.value.toInt(), 3);

      fixture.driveWrite(0, address: 7, data: 0xaa);
      await fixture.clk.nextNegedge;
      expect(fixture.writeRequests[0].ready.value, LogicValue.one);
      expect(fixture.dut.invalidWriteAddress.value[0], LogicValue.one);
      await Simulator.endSimulation();
    },
  );

  test('accepts the top address of a full-width address space', () async {
    final fixture = _ScratchpadFixture(depth: 16, addressWidth: 4);
    await fixture.buildAndReset();

    await fixture.writeOne(0, address: 15, data: 0xa5);
    await fixture.readOne(0, address: 15, tag: 2);
    expect(fixture.readResponses[0].data.error.value, LogicValue.zero);
    expect(fixture.readResponses[0].data.data.value.toInt(), 0xa5);
    expect(fixture.readResponses[0].data.tag.value.toInt(), 2);
    await Simulator.endSimulation();
  });

  test('routes uneven modulo banks through one-cycle SRAM arrays', () async {
    final fixture = _ScratchpadFixture(
      depth: 8,
      bankCount: 3,
      bankMapping: TensorScratchpadBankMapping.modulo,
      memoryFunctor: inferredSramArray<Logic>(),
    );
    await fixture.buildAndReset();
    await fixture.writeOne(0, address: 0, data: 0x11);
    fixture
      ..driveWrite(0, address: 6, data: 0x66)
      ..driveWrite(1, address: 7, data: 0x77);
    await fixture.clk.nextNegedge;
    expect(
      fixture.writeRequests.map((port) => port.ready.value),
      everyElement(LogicValue.one),
    );
    await fixture.clk.nextPosedge;
    fixture
      ..clearWriteValids()
      ..driveRead(0, address: 7, tag: 1)
      ..driveRead(1, address: 6, tag: 2);
    await fixture.clk.nextNegedge;
    expect(
      fixture.readRequests.map((port) => port.ready.value),
      everyElement(LogicValue.one),
    );

    await fixture.clk.nextPosedge;
    fixture.clearReadValids();
    await fixture.clk.nextNegedge;
    expect(
      fixture.readResponses.map((port) => port.valid.value),
      everyElement(LogicValue.zero),
    );
    await fixture.clk.nextNegedge;
    expect(
      fixture.readResponses.map((port) => port.valid.value),
      everyElement(LogicValue.one),
    );
    expect(fixture.readResponses[0].data.data.value.toInt(), 0x77);
    expect(fixture.readResponses[0].data.tag.value.toInt(), 1);
    expect(fixture.readResponses[1].data.data.value.toInt(), 0x66);
    expect(fixture.readResponses[1].data.tag.value.toInt(), 2);
    await fixture.acceptResponse(0);
    await fixture.readOne(0, address: 0, tag: 3);
    expect(fixture.readResponses[0].data.data.value.toInt(), 0x11);
    await Simulator.endSimulation();
  });

  for (final policy in [
    TensorScratchpadBankConflictPolicy.disallow,
    TensorScratchpadBankConflictPolicy.stall,
  ]) {
    test('${policy.name} admission preserves unrelated bank policy', () async {
      final fixture = _ScratchpadFixture(bankConflictPolicy: policy);
      await fixture.buildAndReset();
      await fixture.clk.nextPosedge;
      fixture
        ..driveWrite(0, address: 0, data: 0x11)
        ..driveWrite(1, address: 2, data: 0x22)
        ..driveRead(0, address: 1, tag: 1);
      await fixture.clk.nextNegedge;
      final disallow = policy == TensorScratchpadBankConflictPolicy.disallow;
      expect(
        fixture.writeRequests.map((port) => port.ready.value),
        everyElement(LogicValue.zero),
      );
      expect(
        fixture.readRequests[0].ready.value,
        disallow ? LogicValue.one : LogicValue.zero,
      );
      expect(fixture.dut.bankConflicts.value.toInt(), disallow ? 0x3 : 0x7);
      await fixture.clk.nextPosedge;
      fixture
        ..clearWriteValids()
        ..clearReadValids();
      if (disallow) {
        await fixture.waitForResponse(0);
        expect(fixture.readResponses[0].data.tag.value.toInt(), 1);
      }
      await Simulator.endSimulation();
    });
  }

  test('handles a lone word and bank', () async {
    final fixture = _ScratchpadFixture(depth: 1, addressWidth: 1, bankCount: 1);
    await fixture.buildAndReset();
    await fixture.writeOne(0, address: 0, data: 0x39);
    await fixture.readOne(0, address: 0, tag: 1);
    expect(fixture.readResponses[0].data.data.value.toInt(), 0x39);
    await Simulator.endSimulation();
  });

  test('rejects incompatible word schemas even across packed bridges', () {
    final signedTile = inferenceLogicTensorTile(
        rowCount: 1,
        columnCount: 2,
        format: InferenceNumericFormat.signedInteger(8));
    final unsignedTile = inferenceLogicTensorTile(
        rowCount: 1,
        columnCount: 2,
        format: InferenceNumericFormat.unsignedInteger(8));
    final transposedShape = inferenceLogicTensorTile(
        rowCount: 2, columnCount: 1, format: signedTile.format);
    for (final destination in [unsignedTile, transposedShape]) {
      expect(
        () => TensorScratchpad<Logic>(
          clk: Logic(),
          reset: Logic(),
          depth: 4,
          bankCount: 2,
          readRequests: [
            ReadyValidInterface(
                TensorScratchpadReadRequest(addressWidth: 2, tagWidth: 1)),
          ],
          readResponses: [
            ReadyValidInterface(TensorScratchpadReadResponse<Logic>(
                data: destination, tagWidth: 1)),
          ],
          writeRequests: [
            ReadyValidInterface(TensorScratchpadWriteRequest<Logic>(
                data: Logic(width: signedTile.width), addressWidth: 2)),
            ReadyValidInterface(TensorScratchpadWriteRequest<Logic>(
                data: signedTile, addressWidth: 2)),
          ],
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects different codecs for equal-width array words', () {
    TypedLogicArray<Logic, LogicValue> word() =>
        TypedLogicArray<Logic, LogicValue>(
          [2],
          ({name}) => Logic(name: name, width: 4),
          valueCodec:
              // Distinct codec instances must not be canonicalized.
              // ignore: prefer_const_constructors
              LogicValueCodec(decode: _identityValue, encode: _identityValue),
        );
    expect(
      () => TensorScratchpad(
        clk: Logic(),
        reset: Logic(),
        depth: 4,
        bankCount: 2,
        readRequests: [
          ReadyValidInterface(
              TensorScratchpadReadRequest(addressWidth: 2, tagWidth: 1)),
        ],
        readResponses: [
          ReadyValidInterface(
              TensorScratchpadReadResponse(data: word(), tagWidth: 1)),
        ],
        writeRequests: [
          ReadyValidInterface(
              TensorScratchpadWriteRequest(data: word(), addressWidth: 2)),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('rejects invalid banking and unsupported array limits', () {
    expect(() => _ScratchpadFixture(bankCount: 3), throwsArgumentError);
    expect(
      () => _ScratchpadFixture(
        memoryFunctor: const MemoryArrayFunctor<Logic>(
          identity: 'noReads',
          capabilities: MemoryArrayCapabilities(
            readLatency: 1,
            readCollision: MemoryArrayReadCollision.unspecified,
            writeCollision: MemoryArrayWriteCollision.disallow,
            supportsMaskedWrites: false,
            implementation: MemoryArrayImplementation.synthesizable,
            maxReadPorts: 0,
          ),
          build: _unexpectedArrayBuild,
        ),
      ),
      throwsArgumentError,
    );
  });
}

LogicValue _identityValue(LogicValue value) => value;

Memory<Logic> _unexpectedArrayBuild({
  required Logic clk,
  required Logic reset,
  required List<DataPortInterface<Logic>> writePorts,
  required List<DataPortInterface<Logic>> readPorts,
  required int entryCount,
  required String name,
}) =>
    throw StateError('Incompatible backing array should not be built.');

class _ScratchpadFixture {
  final int depth;
  final int addressWidth;
  final Logic clk = SimpleClockGenerator(10).clk;
  final Logic reset = Logic();
  late final List<ReadyValidInterface<TensorScratchpadReadRequest>>
      readRequests;
  late final List<ReadyValidInterface<TensorScratchpadReadResponse>>
      readResponses;
  late final List<ReadyValidInterface<TensorScratchpadWriteRequest>>
      writeRequests;
  late final TensorScratchpad dut;

  _ScratchpadFixture({
    this.depth = 6,
    this.addressWidth = 3,
    int bankCount = 2,
    TensorScratchpadBankMapping bankMapping =
        TensorScratchpadBankMapping.lowAddressBits,
    TensorScratchpadBankConflictPolicy bankConflictPolicy =
        TensorScratchpadBankConflictPolicy.lowestPortWins,
    MemoryArrayFunctor<Logic>? memoryFunctor,
  }) {
    readRequests = [
      for (var port = 0; port < 2; port++)
        ReadyValidInterface(
          TensorScratchpadReadRequest(
            addressWidth: addressWidth,
            tagWidth: 2,
            name: 'readRequest$port',
          ),
        ),
    ];
    readResponses = [
      for (var port = 0; port < 2; port++)
        ReadyValidInterface(
          TensorScratchpadReadResponse(
            data: Logic(width: 8),
            tagWidth: 2,
            name: 'readResponse$port',
          ),
        ),
    ];
    writeRequests = [
      for (var port = 0; port < 2; port++)
        ReadyValidInterface(
          TensorScratchpadWriteRequest(
            addressWidth: addressWidth,
            data: Logic(width: 8),
            name: 'writeRequest$port',
          ),
        ),
    ];
    dut = TensorScratchpad(
      clk: clk,
      reset: reset,
      readRequests: readRequests,
      readResponses: readResponses,
      writeRequests: writeRequests,
      depth: depth,
      bankCount: bankCount,
      bankMapping: bankMapping,
      bankConflictPolicy: bankConflictPolicy,
      memoryFunctor: memoryFunctor,
    );
  }

  Future<void> buildAndReset() async {
    await dut.build();
    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());
    reset.inject(1);
    for (final request in [...readRequests, ...writeRequests]) {
      request.valid.inject(0);
      request.data.inject(0);
    }
    for (final response in readResponses) {
      response.ready.inject(0);
    }
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextNegedge;
  }

  void driveWrite(int port, {required int address, required int data}) {
    writeRequests[port].data.address.inject(address);
    writeRequests[port].data.data.inject(data);
    writeRequests[port].valid.inject(1);
  }

  void clearWriteValids() {
    for (final request in writeRequests) {
      request.valid.inject(0);
    }
  }

  void driveRead(int port, {required int address, required int tag}) {
    readRequests[port].data.address.inject(address);
    readRequests[port].data.tag.inject(tag);
    readRequests[port].valid.inject(1);
  }

  void clearReadValids() {
    for (final request in readRequests) {
      request.valid.inject(0);
    }
  }

  Future<void> writeOne(
    int port, {
    required int address,
    required int data,
  }) async {
    driveWrite(port, address: address, data: data);
    while (writeRequests[port].ready.value != LogicValue.one) {
      await clk.nextNegedge;
    }
    await clk.nextPosedge;
    writeRequests[port].valid.inject(0);
    await clk.nextNegedge;
  }

  Future<void> readOne(
    int port, {
    required int address,
    required int tag,
  }) async {
    driveRead(port, address: address, tag: tag);
    while (readRequests[port].ready.value != LogicValue.one) {
      await clk.nextNegedge;
    }
    await clk.nextPosedge;
    readRequests[port].valid.inject(0);
    await waitForResponse(port);
  }

  Future<void> waitForResponse(int port) async {
    while (readResponses[port].valid.value != LogicValue.one) {
      await clk.nextNegedge;
    }
  }

  Future<void> waitForResponses() async {
    while (readResponses.any(
      (response) => response.valid.value != LogicValue.one,
    )) {
      await clk.nextNegedge;
    }
  }

  Future<void> acceptResponse(int port) async {
    readResponses[port].ready.inject(1);
    await clk.nextPosedge;
    readResponses[port].ready.inject(0);
    await clk.nextNegedge;
  }
}
