// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

@TestOn('vm')
library;

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Harness extends Module {
  _Harness({int banks = 1, int dataWidth = 32}) {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    for (var i = 0; i < banks; i++) {
      final reads = ValidThenReadyInterface(
          TensorScratchpadReadRequest(addressWidth: 3, tagWidth: 1));
      final writes = ValidThenReadyInterface(
          ByteMaskedWriteRequest(addressWidth: 3, dataWidth: dataWidth));
      final responses = ReadyAndValidInterface(
          TensorScratchpadReadResponse(dataWidth: dataWidth, tagWidth: 1));
      reads.valid <= addInput('readValid$i', Logic());
      reads.data.address <=
          addInput('readAddress$i', Logic(width: 3), width: 3);
      reads.data.tag <= addInput('readTag$i', Logic());
      writes.valid <= addInput('writeValid$i', Logic());
      writes.data.address <=
          addInput('writeAddress$i', Logic(width: 3), width: 3);
      writes.data.data <=
          addInput('writeData$i', Logic(width: dataWidth), width: dataWidth);
      writes.data.byteEnable <=
          addInput('writeMask$i', Logic(width: dataWidth ~/ 8),
              width: dataWidth ~/ 8);
      responses.ready <= addInput('responseReady$i', Logic());
      final bank = TensorMaskedSramBank(
        clk: clk,
        reset: reset,
        reads: reads,
        writes: writes,
        responses: responses,
        depth: 8,
        name: 'bank$i',
      );
      addOutput('readReady$i') <= reads.ready;
      addOutput('writeReady$i') <= writes.ready;
      addOutput('responseValid$i') <= responses.valid;
      addOutput('responseData$i', width: dataWidth) <= responses.data.data;
      addOutput('responseTag$i') <= responses.data.tag;
      addOutput('responseError$i') <= responses.data.error;
      addOutput('responseOverflow$i') <= bank.responseOverflow;
    }
  }
}

void main() {
  tearDown(Simulator.reset);
  final path = Platform.environment['GEMMINI_SCRATCHPAD_BANK_VECTORS'];
  test('matches upstream scratchpad bank timing and data', () async {
    final dut = _Harness();
    await dut.build();
    final vectors = <Vector>[];
    final lines = await File(path!).readAsLines();
    expect(lines.length, 360);
    for (final line in lines) {
      final f = line.split(',').map(int.parse).toList();
      expect(f.length, 14);
      final input = <String, dynamic>{
        'clk': 0,
        'reset': f[0],
        'readValid0': f[1],
        'readAddress0': f[2],
        'readTag0': f[3],
        'writeValid0': f[4],
        'writeAddress0': f[5],
        'writeData0': f[6],
        'writeMask0': f[7],
        'responseReady0': f[8],
      };
      vectors
        ..add(Vector(input, {
          if (f[0] == 0) ...{
            'readReady0': f[9],
            'writeReady0': f[10],
            'responseValid0': f[11],
            'responseOverflow0': 0,
            if (f[11] == 1) ...{
              'responseData0': f[12],
              'responseTag0': f[13],
              'responseError0': 0,
            },
          },
        }))
        ..add(Vector({...input, 'clk': 1}, const {}));
    }
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  },
      skip: path == null
          ? 'Set GEMMINI_SCRATCHPAD_BANK_VECTORS to upstream reference vectors.'
          : null);

  test('independent banks pipeline reads while another response is stalled',
      () async {
    final dut = _Harness(banks: 2);
    await dut.build();
    final input = <String, dynamic>{
      'clk': 0,
      'reset': 1,
      for (var i = 0; i < 2; i++) ...{
        'readValid$i': 0,
        'readAddress$i': 0,
        'readTag$i': i,
        'writeValid$i': 0,
        'writeAddress$i': 0,
        'writeData$i': 0,
        'writeMask$i': 15,
        'responseReady$i': 0,
      },
    };
    final vectors = <Vector>[];
    void cycle([Map<String, dynamic> expected = const {}]) {
      vectors
        ..add(Vector({...input, 'clk': 0}, expected))
        ..add(Vector({...input, 'clk': 1}, const {}));
    }

    cycle();
    input.addAll({
      'reset': 0,
      'writeValid0': 1,
      'writeValid1': 1,
      'writeData0': 0x11223344,
      'writeData1': 0xaabbccdd,
    });
    cycle({'writeReady0': 1, 'writeReady1': 1});
    input.addAll({
      'writeValid0': 0,
      'writeValid1': 0,
      'readValid0': 1,
      'readValid1': 1,
      'responseReady1': 1,
    });
    cycle({'readReady0': 1, 'readReady1': 1});
    input['readValid0'] = 0;
    cycle({
      'responseValid0': 1,
      'responseData0': 0x11223344,
      'responseValid1': 1,
      'responseData1': 0xaabbccdd,
      'responseTag1': 1,
      'readReady1': 1,
    });
    input.addAll({
      'readValid1': 0,
      'writeValid0': 1,
      'writeData0': 0x0000ee00,
      'writeMask0': 2,
    });
    cycle({
      'responseValid0': 1,
      'responseData0': 0x11223344,
      'responseValid1': 1,
      'responseData1': 0xaabbccdd,
      'writeReady0': 1,
    });
    input.addAll({'writeValid0': 0, 'readValid0': 1, 'responseReady0': 1});
    cycle({'responseValid0': 1, 'responseData0': 0x11223344, 'readReady0': 1});
    input['readValid0'] = 0;
    cycle({
      'responseValid0': 1,
      'responseData0': 0x1122ee44,
      'responseOverflow0': 0,
      'responseOverflow1': 0,
    });
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('reset discards a stalled response without clearing SRAM', () async {
    final dut = _Harness();
    await dut.build();
    final input = <String, dynamic>{
      'clk': 0,
      'reset': 1,
      'readValid0': 0,
      'readAddress0': 0,
      'readTag0': 1,
      'writeValid0': 0,
      'writeAddress0': 0,
      'writeData0': 0x11223344,
      'writeMask0': 15,
      'responseReady0': 0,
    };
    final vectors = <Vector>[];
    void cycle([Map<String, dynamic> expected = const {}]) {
      vectors
        ..add(Vector({...input, 'clk': 0}, expected))
        ..add(Vector({...input, 'clk': 1}, const {}));
    }

    cycle();
    input.addAll({'reset': 0, 'writeValid0': 1});
    cycle({'writeReady0': 1});
    input.addAll({'writeValid0': 0, 'readValid0': 1});
    cycle({'readReady0': 1});
    input['readValid0'] = 0;
    cycle({'responseValid0': 1, 'responseData0': 0x11223344});
    input['reset'] = 1;
    cycle({'responseValid0': 0});
    input.addAll({
      'reset': 0,
      'readValid0': 1,
      'writeValid0': 1,
      'writeMask0': 0,
      'responseReady0': 1,
    });
    cycle({'responseValid0': 0, 'readReady0': 0, 'writeReady0': 1});
    input['writeValid0'] = 0;
    cycle({'readReady0': 1});
    input['readValid0'] = 0;
    cycle({
      'responseValid0': 1,
      'responseData0': 0x11223344,
      'responseTag0': 1,
      'responseOverflow0': 0,
    });
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('128-bit rows preserve high and low masked byte writes', () async {
    final dut = _Harness(dataWidth: 128);
    await dut.build();
    final input = <String, dynamic>{
      'clk': 0,
      'reset': 1,
      'readValid0': 0,
      'readAddress0': 0,
      'readTag0': 0,
      'writeValid0': 0,
      'writeAddress0': 0,
      'writeData0': BigInt.zero,
      'writeMask0': 0xffff,
      'responseReady0': 1,
    };
    final vectors = <Vector>[];
    void cycle([Map<String, dynamic> expected = const {}]) {
      vectors
        ..add(Vector({...input, 'clk': 0}, expected))
        ..add(Vector({...input, 'clk': 1}, const {}));
    }

    cycle();
    input.addAll({
      'reset': 0,
      'writeValid0': 1,
      'writeData0': BigInt.parse('00112233445566778899aabbccddeeff', radix: 16),
    });
    cycle({'writeReady0': 1});
    input.addAll({
      'writeData0': BigInt.parse('ff000000000000000000000000000011', radix: 16),
      'writeMask0': 0x8001,
    });
    cycle({'writeReady0': 1});
    input.addAll({'writeValid0': 0, 'readValid0': 1});
    cycle({'readReady0': 1});
    input['readValid0'] = 0;
    cycle({
      'responseValid0': 1,
      'responseData0':
          BigInt.parse('ff112233445566778899aabbccddee11', radix: 16),
    });
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });
}
