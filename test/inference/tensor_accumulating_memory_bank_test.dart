// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _BankVectors {
  final Map<String, dynamic> inputs = {
    'clk': 0,
    'reset': 0,
    'writeValid': 0,
    'writeAddress': 0,
    'writeData': 0,
    'writeMask': 0,
    'writeAccumulate': 0,
    'readValid': 0,
    'readAddress': 0,
    'readTag': 0,
    'responseReady': 0,
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
      'writeValid': 1,
      'writeAddress': address,
      'writeData': data,
      'writeMask': mask,
      'writeAccumulate': accumulate ? 1 : 0,
      'readValid': competingRead ? 1 : 0,
    });
    cycle({
      'writeReady': 1,
      if (competingRead) 'readReady': 0,
      'writePending': 0,
    });
    inputs['writeValid'] = 0;
    inputs['readValid'] = 0;
    if (rmw) {
      cycle({'writeReady': 0, 'readReady': 0, 'writePending': 1});
    }
  }

  void read(int address, Object expected, {int tag = 2}) {
    inputs.addAll({
      'writeValid': 0,
      'readValid': 1,
      'readAddress': address,
      'readTag': tag,
      'responseReady': 0,
    });
    cycle({'readReady': 1, 'responseValid': 0});
    inputs.addAll({'readValid': 0, 'writeValid': 1, 'writeMask': 0});
    final response = <String, dynamic>{
      'responseValid': 1,
      'responseData': expected,
      'responseTag': tag,
      'writeReady': 0,
      'readReady': 0,
    };
    cycle(response);
    cycle(response);
    inputs.addAll({'writeValid': 0, 'responseReady': 1});
    cycle(response);
    inputs['responseReady'] = 0;
    cycle({'responseValid': 0, 'writeReady': 1});
  }
}

TensorAccumulatingMemoryBank _bank(int width, int laneWidth) =>
    TensorAccumulatingMemoryBank(
      clk: Logic(),
      reset: Logic(),
      writeValid: Logic(),
      writeAddress: Logic(width: 2),
      writeData: Logic(width: width),
      writeMask: Logic(width: width ~/ 8),
      writeAccumulate: Logic(),
      readValid: Logic(),
      readAddress: Logic(width: 2),
      readTag: Logic(width: 2),
      responseReady: Logic(),
      depth: 4,
      laneWidth: laneWidth,
    );

void main() {
  tearDown(Simulator.reset);

  test('scratchpad byte masks, arbitration, response stalls and reset',
      () async {
    final dut = _bank(32, 8);
    await dut.build();
    final t = _BankVectors();
    t.inputs['reset'] = 1;
    t.cycle({'readReady': 0, 'writeReady': 0, 'responseValid': 0});
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
    t.cycle({'writeReady': 0, 'readReady': 0});
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
      'writeValid': 1,
      'writeAddress': 1,
      'writeData': 0,
      'writeMask': 1,
      'writeAccumulate': 0,
    });
    t.cycle({'writeReady': 1});
    t.inputs.addAll({'reset': 1, 'writeValid': 0});
    t.cycle({'writeReady': 0, 'writePending': 0});
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
