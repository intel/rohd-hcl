// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_scratchpad_nested_icarus_test.dart
// Tests for Tensor Scratchpad Nested Icarus.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

import '../systemc_test_utils.dart';
import '../verilator_test_utils.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  for (final useSram in [false, true]) {
    test('nested unpacked rows retain shape and stalled data, SRAM=$useSram',
        () async {
      final row = LogicArray([2], 4, numUnpackedDimensions: 1);
      final harness = _TensorScratchpadHarness(
        clk: Logic(),
        reset: Logic(),
        readAddress: Logic(width: 3),
        readTag: Logic(width: 2),
        readValid: Logic(),
        readResponseReady: Logic(),
        writeAddress: Logic(width: 3),
        writeData: row,
        writeValid: Logic(),
        memoryFunctor: useSram ? inferredSramArray<LogicArray>() : null,
      );
      await harness.build();
      expect(harness.readResponseData.dimensions, [2]);
      expect(harness.readResponseData.numUnpackedDimensions, 1);
      final vectors = [
        Vector({
          'clk': 0,
          'reset': 1,
          'readAddress': 3,
          'readTag': 2,
          'readValid': 0,
          'readResponseReady': 0,
          'writeAddress': 3,
          'writeData': 0,
          'writeValid': 0,
        }, const {}),
        Vector({'clk': 1}, {'readResponseValid': 0}),
        Vector({'clk': 0, 'reset': 0, 'writeData': 0xa5, 'writeValid': 1},
            {'writeReady': 1}),
        Vector({'clk': 1}, const {}),
        Vector({'clk': 0, 'writeValid': 0, 'readValid': 1}, {'readReady': 1}),
        Vector({'clk': 1}, const {}),
        Vector({'clk': 0, 'readValid': 0}, {'readResponseValid': 0}),
        Vector({'clk': 1}, const {}),
        Vector({
          'clk': 0,
          'writeData': 0x3c
        }, {
          'readResponseValid': 1,
          'readResponseData': 0xa5,
          'readResponseTag': 2,
          'readResponseError': 0,
        }),
        Vector({'clk': 1}, {'readResponseData': 0xa5}),
        Vector({'clk': 0, 'readResponseReady': 1},
            {'readResponseValid': 1, 'readResponseData': 0xa5}),
        Vector({'clk': 1}, const {}),
        Vector({'clk': 0}, {'readResponseValid': 0}),
      ];
      await SimCompare.checkFunctionalVector(harness, vectors);
      SimCompare.checkIverilogVector(harness, vectors);
      if (useSram && canRunSystemC()) {
        await _checkBehavioralSystemC(vectors);
      }
      SimCompare.checkVerilatorVector(harness, vectors);
      expectNoVerilatorWarnings(harness, ['LATCH', 'UNOPTFLAT']);
    }, timeout: const Timeout(Duration(minutes: 5)));
  }

  test('nested tensor scratchpad compiles in Icarus', () async {
    final harness = _TensorScratchpadHarness(
      clk: Logic(),
      reset: Logic(),
      readAddress: Logic(width: 3),
      readTag: Logic(width: 2),
      readValid: Logic(),
      readResponseReady: Logic(),
      writeAddress: Logic(width: 3),
      writeData: Logic(width: 8),
      writeValid: Logic(),
    );
    await harness.build();

    expect(
      harness.inputs.keys,
      containsAll([
        'clk',
        'reset',
        'readAddress',
        'readTag',
        'readValid',
        'readResponseReady',
        'writeAddress',
        'writeData',
        'writeValid',
      ]),
    );
    expect(
      harness.outputs.keys,
      containsAll([
        'readReady',
        'readResponseData',
        'readResponseTag',
        'readResponseError',
        'readResponseValid',
        'writeReady',
        'blockedRequests',
        'bankConflicts',
        'invalidReadAddress',
        'invalidWriteAddress',
        'responseOverflow',
        'unexpectedResponse',
      ]),
    );

    final directory =
        Directory.systemTemp.createTempSync('rohd_hcl_tensor_scratchpad_');
    final sourcePath = '${directory.path}/tensor_scratchpad_harness.sv';
    try {
      final systemVerilog = harness.dumpSystemVerilog();
      expect(systemVerilog, contains('module TensorScratchpadHarness'));
      expect(systemVerilog, contains('module TensorScratchpad_'));
      File(sourcePath).writeAsStringSync(systemVerilog);
      final result =
          Process.runSync('iverilog', ['-g2012', '-tnull', sourcePath]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('nested tensor scratchpad preserves request and response behavior',
      () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final readAddress = Logic(width: 3);
    final readTag = Logic(width: 2);
    final readValid = Logic();
    final readResponseReady = Logic();
    final writeAddress = Logic(width: 3);
    final writeData = Logic(width: 8);
    final writeValid = Logic();
    final harness = _TensorScratchpadHarness(
      clk: clk,
      reset: reset,
      readAddress: readAddress,
      readTag: readTag,
      readValid: readValid,
      readResponseReady: readResponseReady,
      writeAddress: writeAddress,
      writeData: writeData,
      writeValid: writeValid,
    );
    await harness.build();
    Simulator.setMaxSimTime(500);
    unawaited(Simulator.run());

    reset.inject(1);
    readValid.inject(0);
    readResponseReady.inject(0);
    writeValid.inject(0);
    await clk.nextPosedge;
    reset.inject(0);

    writeAddress.inject(3);
    writeData.inject(0xa5);
    writeValid.inject(1);
    await clk.nextNegedge;
    expect(harness.output('writeReady').value, LogicValue.one);
    await clk.nextPosedge;
    writeValid.inject(0);

    readAddress.inject(3);
    readTag.inject(2);
    readValid.inject(1);
    await clk.nextNegedge;
    expect(harness.output('readReady').value, LogicValue.one);
    await clk.nextPosedge;
    readValid.inject(0);
    for (var cycle = 0;
        cycle < 4 &&
            harness.output('readResponseValid').value != LogicValue.one;
        cycle++) {
      await clk.nextPosedge;
    }

    expect(harness.output('readResponseValid').value, LogicValue.one);
    expect(harness.output('readResponseData').value.toInt(), 0xa5);
    expect(harness.output('readResponseTag').value.toInt(), 2);
    expect(harness.output('readResponseError').value, LogicValue.zero);
    expect(harness.output('responseOverflow').value, LogicValue.zero);
    expect(harness.output('unexpectedResponse').value, LogicValue.zero);

    readResponseReady.inject(1);
    await clk.nextPosedge;
    expect(harness.output('readResponseValid').value, LogicValue.zero);
    await Simulator.endSimulation();
  });
}

Future<void> _checkBehavioralSystemC(List<Vector> vectors) async {
  final harness = _PackedSystemCScratchpadHarness();
  await harness.build();
  final hierarchy = generateBehavioralSystemCHierarchy(
    harness,
    select: (module) => module is InferredSram,
    unknownOutputs: SystemCUnknownOutputPolicy.zeroUntilReset,
  );
  final cpp = StringBuffer('''
${hierarchy.source}
int sc_main(int, char**) {
''');
  for (final port in {...harness.inputs, ...harness.outputs}.entries) {
    final width = port.value.width;
    cpp.writeln('sc_signal<${width == 1 ? 'bool' : 'sc_uint<$width>'}> '
        '${port.key};');
  }
  cpp.writeln('${hierarchy.topClassName} dut("dut");');
  for (final port in [...harness.inputs.keys, ...harness.outputs.keys]) {
    cpp.writeln('dut.$port($port);');
  }
  for (final (step, vector) in vectors.indexed) {
    for (final input in vector.inputValues.entries) {
      cpp.writeln('${input.key}=${input.value};');
    }
    cpp.writeln('sc_start(10, SC_NS);');
    for (final expected in vector.expectedOutputValues.entries) {
      cpp.writeln('if (${expected.key}.read() != ${expected.value}) { '
          'std::cerr << "vector $step ${expected.key}" << std::endl; '
          'return 1; }');
    }
  }
  cpp.writeln('return 0;\n}');
  final directory =
      await Directory.systemTemp.createTemp('tensor_scratchpad_systemc_');
  try {
    final source = File('${directory.path}/test.cpp');
    await source.writeAsString(cpp.toString());
    final compile = await Process.run('g++', [
      '-std=c++17',
      source.path,
      '-lsystemc',
      '-o',
      '${directory.path}/test',
    ]);
    expect(compile.exitCode, 0, reason: '${compile.stdout}\n${compile.stderr}');
    final run = await Process.run('${directory.path}/test', []);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
  } finally {
    await directory.delete(recursive: true);
  }
}

class _PackedSystemCScratchpadHarness extends Module {
  _PackedSystemCScratchpadHarness() {
    final row = LogicArray([2], 4, numUnpackedDimensions: 1)
      ..gets(addInput('writeData', Logic(width: 8), width: 8));
    final child = _TensorScratchpadHarness(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      readAddress: addInput('readAddress', Logic(width: 3), width: 3),
      readTag: addInput('readTag', Logic(width: 2), width: 2),
      readValid: addInput('readValid', Logic()),
      readResponseReady: addInput('readResponseReady', Logic()),
      writeAddress: addInput('writeAddress', Logic(width: 3), width: 3),
      writeData: row,
      writeValid: addInput('writeValid', Logic()),
      memoryFunctor: inferredSramArray<LogicArray>(),
    );
    for (final port in child.outputs.entries) {
      addOutput(port.key, width: port.value.width) <= port.value;
    }
  }
}

class _TensorScratchpadHarness<T extends Logic> extends Module {
  late final T readResponseData;

  _TensorScratchpadHarness({
    required Logic clk,
    required Logic reset,
    required Logic readAddress,
    required Logic readTag,
    required Logic readValid,
    required Logic readResponseReady,
    required Logic writeAddress,
    required T writeData,
    required Logic writeValid,
    MemoryArrayFunctor<T>? memoryFunctor,
  }) : super(definitionName: 'TensorScratchpadHarness') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    readAddress = addInput('readAddress', readAddress, width: 3);
    readTag = addInput('readTag', readTag, width: 2);
    readValid = addInput('readValid', readValid);
    readResponseReady = addInput('readResponseReady', readResponseReady);
    writeAddress = addInput('writeAddress', writeAddress, width: 3);
    writeData = addTypedInput<T>('writeData', writeData);
    writeValid = addInput('writeValid', writeValid);

    final readRequest = ValidThenReadyInterface(
      TensorScratchpadReadRequest(
        addressWidth: 3,
        tagWidth: 2,
        name: 'readRequest',
      ),
    );
    final readResponse = ReadyValidInterface(
      TensorScratchpadReadResponse(
        data: writeData,
        tagWidth: 2,
        name: 'readResponse',
      ),
    );
    final writeRequest = ValidThenReadyInterface(
      TensorScratchpadWriteRequest(
        addressWidth: 3,
        data: writeData,
        name: 'writeRequest',
      ),
    );

    readRequest.data.address <= readAddress;
    readRequest.data.tag <= readTag;
    readRequest.valid <= readValid;
    readResponse.ready <= readResponseReady;
    writeRequest.data.address <= writeAddress;
    writeRequest.data.data <= writeData;
    writeRequest.valid <= writeValid;

    final scratchpad = TensorScratchpad(
      clk: clk,
      reset: reset,
      readRequests: [readRequest],
      readResponses: [readResponse],
      writeRequests: [writeRequest],
      depth: 6,
      bankCount: 2,
      memoryFunctor: memoryFunctor,
      name: 'scratchpad',
    );

    addOutput('readReady') <= readRequest.ready;
    readResponseData = addTypedOutput<T>(
        'readResponseData', readResponse.data.data.cloneTyped);
    readResponseData <= readResponse.data.data;
    addOutput('readResponseTag', width: 2) <= readResponse.data.tag;
    addOutput('readResponseError') <= readResponse.data.error;
    addOutput('readResponseValid') <= readResponse.valid;
    addOutput('writeReady') <= writeRequest.ready;
    addOutput('blockedRequests', width: 2) <= scratchpad.blockedRequests;
    addOutput('bankConflicts', width: 2) <= scratchpad.bankConflicts;
    addOutput('invalidReadAddress') <= scratchpad.invalidReadAddress;
    addOutput('invalidWriteAddress') <= scratchpad.invalidWriteAddress;
    addOutput('responseOverflow') <= scratchpad.responseOverflow;
    addOutput('unexpectedResponse') <= scratchpad.unexpectedResponse;
  }
}
