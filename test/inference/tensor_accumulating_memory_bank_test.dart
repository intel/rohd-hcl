// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_accumulating_memory_bank_test.dart
// Tests for masked tensor writes and lane-wise accumulation.
//
// 2026 November 23
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

Future<void> _edge(Logic clk) async {
  await clk.nextPosedge;
  await clk.nextNegedge;
}

class _BankVectors {
  final Map<String, dynamic> inputs = {
    'clk': 0,
    'reset': 0,
    'write': 0,
    'writeAddress': 0,
    'writeData': 0,
    'writeMask': 0,
    'writeAccumulate': 0,
    'read': 0,
    'readAddress': 0,
    'readTag': 0,
    'consumeResponse': 0,
  };
  final List<Vector> vectors = [];

  void cycle([Map<String, dynamic> expected = const {}]) {
    inputs['clk'] = 0;
    vectors
      ..add(Vector(Map.of(inputs), expected))
      ..add(Vector({...inputs, 'clk': 1}, const {}));
  }

  void write({
    required int address,
    required BigInt data,
    required BigInt mask,
    required bool accumulate,
    required bool rmw,
    bool competingRead = false,
  }) {
    inputs.addAll({
      'write': 1,
      'writeAddress': address,
      'writeData': data,
      'writeMask': mask,
      'writeAccumulate': accumulate ? 1 : 0,
      'read': competingRead ? 1 : 0,
    });
    cycle({
      'canWrite': 1,
      if (competingRead) 'canRead': 0,
      'writePending': 0,
    });
    inputs['write'] = 0;
    inputs['read'] = 0;
    if (rmw) {
      cycle({'canWrite': 0, 'canRead': 0, 'writePending': 1});
    }
  }

  void read(int address, Object expected, {int tag = 2}) {
    inputs.addAll({
      'write': 0,
      'read': 1,
      'readAddress': address,
      'readTag': tag,
      'consumeResponse': 0,
    });
    cycle({'canRead': 1, 'responseValid': 0});
    inputs.addAll({'read': 0, 'write': 1, 'writeMask': 0});
    final response = <String, dynamic>{
      'responseValid': 1,
      'responseData': expected,
      'responseTag': tag,
      'canWrite': 0,
      'canRead': 0,
    };
    cycle(response);
    cycle(response);
    inputs.addAll({'write': 0, 'consumeResponse': 1});
    cycle(response);
    inputs['consumeResponse'] = 0;
    cycle({'responseValid': 0, 'canWrite': 1});
  }
}

TensorAccumulatingMemoryBank _bank(int width, int laneWidth) =>
    TensorAccumulatingMemoryBank(
      clk: Logic(),
      reset: Logic(),
      write: Logic(),
      writeAddress: Logic(width: 2),
      writeData: Logic(width: width),
      writeMask: Logic(width: width ~/ 8),
      writeAccumulate: Logic(),
      read: Logic(),
      readAddress: Logic(width: 2),
      readTag: Logic(width: 2),
      consumeResponse: Logic(),
      depth: 4,
      laneWidth: laneWidth,
    );

void main() {
  tearDown(Simulator.reset);

  test('protocol attachments retain lane-wrapped results and arbitrate no-ops',
      () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final writes = ReadyValidInterface(TensorAccumulatingWriteRequest(
      ByteMaskedWriteRequest(addressWidth: 2, dataWidth: 16),
    ));
    final reads = ReadyValidInterface(
      TensorScratchpadReadRequest(addressWidth: 2, tagWidth: 2),
    );
    final responses = ReadyValidInterface(TensorScratchpadReadResponse(
      data: TypedLogicArray<Logic, LogicValue>(
        [2],
        ({name}) => Logic(name: name, width: 8),
        numUnpackedDimensions: 1,
      ),
      tagWidth: 2,
    ));
    final dut = ReadyValidTensorAccumulatingMemoryBank(
      clk: clk,
      reset: reset,
      writes: writes,
      reads: reads,
      responses: responses,
      depth: 4,
      laneWidth: 8,
    );
    await dut.build();
    unawaited(Simulator.run());
    reset.inject(1);
    writes.valid.inject(0);
    writes.data.inject(0);
    reads.valid.inject(0);
    reads.data.inject(0);
    responses.ready.inject(0);
    await _edge(clk);
    reset.inject(0);
    writes.data.write.byteEnable.inject(3);
    writes.data.write.data.inject(0x34ff);
    writes.valid.inject(1);
    await _edge(clk);
    writes.data.write.data.inject(1);
    writes.data.accumulate.inject(1);
    reads.valid.inject(1);
    reads.data.tag.inject(2);
    await Simulator.tick();
    expect(reads.ready.value, LogicValue.zero);
    await _edge(clk);
    writes.valid.inject(0);
    expect(dut.writePending.value, LogicValue.one);
    expect(reads.ready.value, LogicValue.zero);
    await _edge(clk);
    expect(reads.ready.value, LogicValue.one);
    await _edge(clk);
    reads.valid.inject(0);
    expect(responses.valid.value, LogicValue.one);
    expect(responses.data.data.value.toInt(), 0x3400);
    expect(responses.data.tag.value.toInt(), 2);
    expect(responses.data.error.value, LogicValue.zero);
    final retained = responses.data.value;
    for (var cycle = 0; cycle < 3; cycle++) {
      await _edge(clk);
      expect(responses.valid.value, LogicValue.one);
      expect(responses.data.value, retained);
    }
    responses.ready.inject(1);
    await _edge(clk);
    responses.ready.inject(0);
    expect(responses.valid.value, LogicValue.zero);
    writes.data.write.byteEnable.inject(0);
    writes.data.accumulate.inject(0);
    writes.valid.inject(1);
    reads.valid.inject(1);
    reads.data.tag.inject(3);
    await Simulator.tick();
    expect(writes.ready.value, LogicValue.one);
    expect(reads.ready.value, LogicValue.zero);
    await _edge(clk);
    writes.valid.inject(0);
    await _edge(clk);
    reads.valid.inject(0);
    expect(responses.valid.value, LogicValue.one);
    expect(responses.data.data.value.toInt(), 0x3400);
    expect(responses.data.tag.value.toInt(), 3);
    await Simulator.endSimulation();
  });

  test('scratchpad byte masks, arbitration, response stalls and reset',
      () async {
    final dut = _bank(32, 8);
    await dut.build();
    final t = _BankVectors();
    t.inputs['reset'] = 1;
    t.cycle({'canRead': 0, 'canWrite': 0, 'responseValid': 0});
    t.inputs['reset'] = 0;
    t
      ..write(
        address: 1,
        data: BigInt.from(0x12345678),
        mask: BigInt.from(15),
        accumulate: false,
        rmw: false,
        competingRead: true,
      )
      ..write(
        address: 1,
        data: BigInt.from(0xaabbccdd),
        mask: BigInt.from(5),
        accumulate: false,
        rmw: true,
      )
      ..write(
        address: 1,
        data: BigInt.zero,
        mask: BigInt.zero,
        accumulate: true,
        rmw: false,
      )
      ..read(1, BigInt.from(0x12bb56dd));
    t.inputs['reset'] = 1;
    t.cycle({'canWrite': 0, 'canRead': 0});
    t.inputs['reset'] = 0;
    t
      ..read(1, BigInt.from(0x12bb56dd), tag: 3)
      ..write(
        address: 3,
        data: BigInt.from(0x55),
        mask: BigInt.one,
        accumulate: false,
        rmw: true,
      )
      ..read(3, LogicValue.ofString('xxxxxxxxxxxxxxxxxxxxxxxx01010101'));
    t.inputs.addAll({
      'write': 1,
      'writeAddress': 1,
      'writeData': 0,
      'writeMask': 1,
      'writeAccumulate': 0,
    });
    t.cycle({'canWrite': 1});
    t.inputs.addAll({'reset': 1, 'write': 0});
    t.cycle({'canWrite': 0, 'writePending': 0});
    t.inputs['reset'] = 0;
    t.read(1, BigInt.from(0x12bb56dd));
    await SimCompare.checkFunctionalVector(dut, t.vectors);
    SimCompare.checkIverilogVector(dut, t.vectors);
  });

  test('accumulator wraps per lane before applying byte masks', () async {
    final dut = _bank(64, 32);
    await dut.build();
    final t = _BankVectors();
    t.inputs['reset'] = 1;
    t.cycle();
    t.inputs['reset'] = 0;
    t
      ..write(
        address: 2,
        data: BigInt.parse('7fffffffffffffff', radix: 16),
        mask: BigInt.from(255),
        accumulate: false,
        rmw: false,
      )
      ..write(
        address: 2,
        data: BigInt.parse('0000000100000001', radix: 16),
        mask: BigInt.from(255),
        accumulate: true,
        rmw: true,
      )
      ..read(2, BigInt.parse('8000000000000000', radix: 16))
      ..write(
        address: 2,
        data: BigInt.parse('ffffffff01020304', radix: 16),
        mask: BigInt.from(0x12),
        accumulate: true,
        rmw: true,
      )
      ..read(2, BigInt.parse('800000ff00000300', radix: 16));
    await SimCompare.checkFunctionalVector(dut, t.vectors);
    SimCompare.checkIverilogVector(dut, t.vectors);
  });

  test('default accumulator row width preserves all 16 lanes', () async {
    final dut = _bank(512, 32);
    await dut.build();
    final t = _BankVectors();
    t.inputs['reset'] = 1;
    t.cycle();
    t.inputs['reset'] = 0;
    final initial = (BigInt.from(0xffffffff) << (15 * 32)) | BigInt.from(41);
    final increment = (BigInt.one << (15 * 32)) | BigInt.one;
    final mask = (BigInt.one << 64) - BigInt.one;
    t
      ..write(
          address: 0, data: initial, mask: mask, accumulate: false, rmw: false)
      ..write(
          address: 0, data: increment, mask: mask, accumulate: true, rmw: true)
      ..read(0, BigInt.from(42));
    await SimCompare.checkFunctionalVector(dut, t.vectors);
    SimCompare.checkIverilogVector(dut, t.vectors);
  });

  test('random masked accumulations agree with a per-byte model', () async {
    final dut = _bank(64, 32);
    await dut.build();
    final t = _BankVectors();
    t.inputs['reset'] = 1;
    t.cycle();
    t.inputs['reset'] = 0;
    final rows = List.filled(4, BigInt.zero);
    for (var address = 0; address < rows.length; address++) {
      t.write(
          address: address,
          data: BigInt.zero,
          mask: BigInt.from(255),
          accumulate: false,
          rmw: false);
    }

    final random = Random(3781);
    final laneMask = (BigInt.one << 32) - BigInt.one;
    for (var i = 0; i < 80; i++) {
      final address = random.nextInt(4);
      final data = (BigInt.from(random.nextInt(1 << 32)) << 32) |
          BigInt.from(random.nextInt(1 << 32));
      final mask = random.nextInt(256);
      final accumulate = random.nextBool();
      var update = data;
      if (accumulate) {
        final low = (rows[address] + data) & laneMask;
        final high = ((rows[address] >> 32) + (data >> 32)) & laneMask;
        update = (high << 32) | low;
      }
      for (var byte = 0; byte < 8; byte++) {
        if ((mask & (1 << byte)) != 0) {
          final byteMask = BigInt.from(255) << (byte * 8);
          rows[address] = (rows[address] & ~byteMask) | (update & byteMask);
        }
      }
      t
        ..write(
          address: address,
          data: data,
          mask: BigInt.from(mask),
          accumulate: accumulate,
          rmw: mask != 0 && (accumulate || mask != 255),
        )
        ..read(address, rows[address], tag: i % 4);
    }
    await SimCompare.checkFunctionalVector(dut, t.vectors);
    SimCompare.checkIverilogVector(dut, t.vectors);
  });
}
