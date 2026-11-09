// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// structural_behavioral_miter_test.dart
// Structural CSR and associative-memory substitution across backends.
//
// 2026 November
// Author: ROHD-HCL contributors

@TestOn('vm')
library;

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Device extends Module {
  _Device({required bool behavioralCsr, required bool behavioralCam}) {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final csrValues = <Logic>[];
    for (final (name, initial) in [('a', 0x11), ('b', 0x22)]) {
      final read = DataPortInterface<Logic>(8, 2);
      final write = DataPortInterface<Logic>(8, 2);
      read.en <= Const(1);
      read.addr <= Const(0, width: 2);
      write.en <= addInput('${name}we', Logic());
      write.addr <= Const(0, width: 2);
      write.data <= addInput('${name}wd', Logic(width: 8), width: 8);
      final csr = CsrTop(
        config: CsrTopConfig(name: 'csr_$name', blockSize: 4, blocks: [
          CsrBlockConfig(name: 'block', baseAddr: 0, registers: [
            CsrInstanceConfig(
              arch: CsrConfig(
                  name: 'value', access: CsrAccess.readWrite, fields: const []),
              addr: 0,
              width: 8,
              resetValue: initial,
            )
          ])
        ]),
        clk: clk,
        reset: reset,
        frontRead: read,
        frontWrite: write,
        implementationConfiguration: CsrImplementationConfiguration(
            implementation: behavioralCsr
                ? CsrImplementation.software
                : CsrImplementation.rtl),
      );
      final hardware = csr.getBackdoorPortsByName('block', 'value');
      hardware.wrEn! <= Const(0);
      hardware.wrData! <= Const(0, width: 8);
      csrValues.add(hardware.rdData!);
      addOutput('${name}rd', width: 8) <= read.data;
    }

    final update = AssociativeUpdatePortInterface(keyWidth: 8, indexWidth: 2);
    final lookup = AssociativeLookupPortInterface(
        keyWidth: 8, indexWidth: 2, matchEntryCount: 3);
    update.en <= addInput('camwe', Logic());
    update.index <= addInput('camwi', Logic(width: 2), width: 2);
    update.entryValid <= addInput('camvalid', Logic());
    update.key <= csrValues.first;
    lookup.en <= addInput('qe', Logic());
    lookup.key <= addInput('qk', Logic(width: 8), width: 8);
    final factory = behavioralCam
        ? behavioralParallelAssociativeMemoryFunctor
        : parallelAssociativeMemoryFunctor;
    factory(
      clk: clk,
      reset: reset,
      updatePorts: [update],
      lookupPorts: [lookup],
      entryCount: 3,
      lookupLatency: 0,
      duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
      matchSelection: AssociativeMatchSelection.lowestIndex,
      resultShape: AssociativeResultShape.matchVectorAndSelectedIndex,
      lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
      updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
      name: 'cam',
    );
    addOutput('hit') <= lookup.hit;
    addOutput('index', width: 2) <= lookup.index;
    addOutput('matchBits', width: 3) <= lookup.matchVector!;
  }
}

Future<void> _checkSystemC(_Device device, List<Vector> vectors) async {
  final hierarchy = generateBehavioralSystemCHierarchy(
    device,
    select: (module) =>
        (module is CsrTop && module.softwareModel != null) ||
        module is BehavioralParallelAssociativeMemory,
    unknownOutputs: SystemCUnknownOutputPolicy.zeroUntilReset,
  );
  final cpp = StringBuffer('''
#include "model.h"
#include <iostream>
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
''');
  for (final port in {...device.inputs, ...device.outputs}.entries) {
    final width = port.value.width;
    cpp.writeln('sc_signal<${width == 1 ? 'bool' : 'sc_uint<$width>'}> '
        '${port.key};');
  }
  cpp.writeln('${hierarchy.topClassName} dut("dut");');
  for (final port in [...device.inputs.keys, ...device.outputs.keys]) {
    cpp.writeln('dut.$port($port);');
  }
  for (final (step, vector) in vectors.indexed) {
    for (final input in vector.inputValues.entries) {
      cpp.writeln('${input.key}=${input.value};');
    }
    cpp.writeln('sc_start(1,SC_NS);');
    for (final output in vector.expectedOutputValues.entries) {
      cpp.writeln('if(${output.key}.read()!=${output.value}) {'
          ' std::cerr << "vector $step ${output.key}: " << '
          '${output.key}.read() << "\\n"; return 1; }');
    }
  }
  cpp.writeln('return 0;\n}');
  final dir = await Directory.systemTemp.createTemp('structural_models_');
  try {
    await File('${dir.path}/model.h').writeAsString(hierarchy.source);
    await File('${dir.path}/test.cpp').writeAsString(cpp.toString());
    final compile = await Process.run('g++', [
      '-std=c++17',
      '${dir.path}/test.cpp',
      '-lsystemc',
      '-o',
      '${dir.path}/test'
    ]);
    expect(compile.exitCode, 0, reason: '${compile.stdout}\n${compile.stderr}');
    final run = await Process.run('${dir.path}/test', []);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
  } finally {
    await dir.delete(recursive: true);
  }
}

void main() {
  tearDown(Simulator.reset);
  final vectors = [
    Vector({
      'clk': 0,
      'reset': 1,
      'awe': 0,
      'awd': 0,
      'bwe': 0,
      'bwd': 0,
      'camwe': 0,
      'camwi': 0,
      'camvalid': 1,
      'qe': 1,
      'qk': 0x11,
    }, {}),
    Vector({'clk': 1}, {'ard': 0x11, 'brd': 0x22, 'hit': 0, 'matchBits': 0}),
    Vector({
      'clk': 0,
      'reset': 0,
      'awe': 1,
      'awd': 0xa5,
      'camwe': 1,
      'camwi': 1,
    }, {
      'ard': 0x11,
      'brd': 0x22,
      'hit': 0
    }),
    Vector({'clk': 1},
        {'ard': 0xa5, 'brd': 0x22, 'hit': 1, 'index': 1, 'matchBits': 2}),
    Vector({'clk': 0, 'awe': 0, 'bwe': 1, 'bwd': 0x44, 'camwi': 2, 'qk': 0xa5},
        {'hit': 0}),
    Vector({'clk': 1},
        {'ard': 0xa5, 'brd': 0x44, 'hit': 1, 'index': 2, 'matchBits': 4}),
    Vector({'clk': 0, 'bwe': 0, 'camwi': 1, 'camvalid': 0, 'qk': 0x11},
        {'hit': 1, 'index': 1, 'matchBits': 2}),
    Vector({'clk': 1}, {'hit': 0, 'matchBits': 0}),
    Vector({'clk': 0, 'reset': 1, 'awe': 1, 'awd': 0xff, 'camvalid': 1}, {}),
    Vector({'clk': 1}, {'ard': 0x11, 'brd': 0x22, 'hit': 0, 'matchBits': 0}),
  ];
  for (final behavioralCsr in [false, true]) {
    for (final behavioralCam in [false, true]) {
      test('structural CSR/CAM miter csr=$behavioralCsr cam=$behavioralCam',
          timeout: const Timeout(Duration(minutes: 3)), () async {
        final device =
            _Device(behavioralCsr: behavioralCsr, behavioralCam: behavioralCam);
        await device.build();
        await SimCompare.checkFunctionalVector(device, vectors);
        if (!behavioralCsr && !behavioralCam) {
          SimCompare.checkIverilogVector(device, vectors);
        }
        await _checkSystemC(device, vectors);
      });
    }
  }
}
