// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// inferred_sram_test.dart
// Inferred SRAM behavioral and Verilog tests.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:io';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Harness extends Module {
  late final InferredSram<Logic> sram;

  _Harness() {
    final write = DataPortInterface<Logic>(8, 2);
    final read = DataPortInterface<Logic>(8, 2);
    write.en <= addInput('we', Logic());
    write.addr <= addInput('wa', Logic(width: 2), width: 2);
    write.data <= addInput('wd', Logic(width: 8), width: 8);
    read.en <= addInput('re', Logic());
    read.addr <= addInput('ra', Logic(width: 2), width: 2);
    sram = InferredSram<Logic>(
        addInput('clk', Logic()), addInput('reset', Logic()), [write], [read],
        entryCount: 3);
    addOutput('out', width: 8) <= read.data;
  }
}

String _bit(LogicValue bit) {
  if (bit == LogicValue.zero) {
    return '0';
  }
  if (bit == LogicValue.one) {
    return '1';
  }
  if (bit == LogicValue.z) {
    return 'Z';
  }
  return 'X';
}

String _bits(LogicValue value) =>
    [for (var bit = value.width - 1; bit >= 0; bit--) _bit(value[bit])].join();

Future<void> _checkSystemC(List<Vector> vectors,
    {required SystemCModelPortType portType}) async {
  final twoState = portType == SystemCModelPortType.twoState;
  final dir = await Directory.systemTemp.createTemp('inferred_sram_miter_');
  try {
    final model =
        InferredSramDescription(addressWidth: 2, dataWidth: 8, entryCount: 3)
            .generateSystemC(
                className: 'Sram',
                options: SystemCModelOptions(
                    portType: portType,
                    unknownOutputs: SystemCUnknownOutputPolicy.zeroUntilReset));
    await File('${dir.path}/model.h').writeAsString(model);
    final cpp = StringBuffer('''
#include "model.h"
#include <iostream>
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_signal<${twoState ? 'bool' : 'sc_logic'}> clk, reset, we, re;
  sc_signal<${twoState ? 'sc_uint<2>' : 'sc_lv<2>'}> wa, ra;
  sc_signal<${twoState ? 'sc_uint<8>' : 'sc_lv<8>'}> wd, out;
  Sram dut("dut");
  dut.clk(clk); dut.reset(reset); dut.wr_en_0(we); dut.wr_addr_0(wa);
  dut.wr_data_0(wd); dut.rd_en_0(re); dut.rd_addr_0(ra); dut.rd_data_0(out);
  Sram::image saved;
''');
    final expected = <String>[];
    void drive(Vector vector) {
      for (final input in vector.inputValues.entries) {
        final value = input.value as LogicValue;
        if (twoState) {
          cpp.writeln('  ${input.key}=${value.toInt()};');
        } else if (value.width == 1) {
          cpp.writeln('  ${input.key}=SC_LOGIC_${_bit(value)};');
        } else {
          cpp.writeln('  { sc_lv<${value.width}> v;');
          for (var bit = 0; bit < value.width; bit++) {
            cpp.writeln('    v[$bit]=SC_LOGIC_${_bit(value[bit])};');
          }
          cpp.writeln('    ${input.key}=v; }');
        }
      }
      cpp.writeln('  sc_start(1,SC_NS);');
    }

    void capture(String label, Vector vector) {
      final output = twoState
          ? 'sc_lv<8>(out.read()).to_string()'
          : 'out.read().to_string()';
      cpp.writeln('  std::cout << "M $label " << $output << ' r'"\n";');
      final value = _bits(vector.expectedOutputValues['out'] as LogicValue);
      expected.add('M $label $value');
    }

    for (final (step, vector) in vectors.indexed) {
      drive(vector);
      if (step == 20) {
        cpp.writeln('  saved=dut.snapshot();');
      }
      if (!(twoState && step == 0)) {
        capture('$step', vector);
      }
    }
    cpp.writeln('  dut.restore(saved);');
    drive(vectors[20]);
    capture('restore', vectors[20]);
    for (var step = 21; step <= 40; step++) {
      drive(vectors[step]);
      capture('replay$step', vectors[step]);
    }
    cpp.writeln('  return 0;\n}');
    await File('${dir.path}/test.cpp').writeAsString(cpp.toString());
    final compile = await Process.run('g++', [
      '-std=c++17',
      '${dir.path}/test.cpp',
      '-lsystemc',
      '-o',
      '${dir.path}/test'
    ]);
    expect(compile.exitCode, 0,
        reason: '$portType\n${compile.stdout}\n${compile.stderr}');
    final run = await Process.run('${dir.path}/test', []);
    expect(run.exitCode, 0, reason: '$portType\n${run.stdout}\n${run.stderr}');
    final actual = (run.stdout as String)
        .split('\n')
        .where((line) => line.startsWith('M '))
        .toList();
    expect(actual, expected, reason: '$portType SRAM trace mismatch');
  } finally {
    await dir.delete(recursive: true);
  }
}

void main() {
  tearDown(Simulator.reset);

  test('matches inferred Verilog timing, reset and four-state values',
      () async {
    final dut = _Harness();
    final x = LogicValue.filled(8, LogicValue.x);
    final vectors = [
      Vector(
          {'clk': 0, 'reset': 1, 'we': 0, 'wa': 0, 'wd': 0, 're': 0, 'ra': 0},
          {}),
      Vector({'clk': 1}, {'out': 0}),
      Vector({'clk': 0, 'reset': 0, 'we': 1, 'wa': 1, 'wd': 0x5a}, {}),
      Vector({'clk': 1}, {'out': 0}),
      Vector({'clk': 0, 'we': 0, 're': 1, 'ra': 1}, {'out': 0}),
      Vector({'clk': 1}, {'out': 0x5a}),
      Vector({'clk': 0, 're': 0, 'ra': 2}, {'out': 0x5a}),
      Vector({'clk': 1}, {'out': 0x5a}),
      Vector({'clk': 0, 'reset': 1, 'we': 1, 'wa': 1, 'wd': 0xff}, {}),
      Vector({'clk': 1}, {'out': 0}),
      Vector({'clk': 0, 'reset': 0, 'we': 0, 're': 1, 'ra': 1}, {}),
      Vector({'clk': 1}, {'out': 0x5a}),
      Vector({'clk': 0, 'ra': 3}, {}),
      Vector({'clk': 1}, {'out': x}),
      Vector({'clk': 0, 'ra': LogicValue.ofString('x1')}, {}),
      Vector({'clk': 1}, {'out': x}),
      Vector({
        'clk': 0,
        're': 0,
        'we': 1,
        'wa': 2,
        'wd': LogicValue.ofString('10zz0011')
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'we': 0, 're': 1, 'ra': 2}, {}),
      Vector({'clk': 1}, {'out': LogicValue.ofString('10xx0011')}),
      Vector({'clk': 0, 'we': LogicValue.x, 're': 1, 'ra': 1}, {}),
      Vector({'clk': 1}, {'out': 0x5a}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('snapshots restore storage and registered output', () async {
    final dut = _Harness();
    final incompatible = InferredSram<Logic>(Logic(), Logic(),
        [DataPortInterface<Logic>(8, 2)], [DataPortInterface<Logic>(8, 2)],
        entryCount: 4)
      ..poke(1, LogicValue.ofInt(0x77, 8));
    await dut.build();
    late InferredSramImage image;
    Simulator.registerAction(1, () {
      dut.sram.poke(1, LogicValue.ofInt(0xa5, 8));
      dut.input('clk').put(0);
      dut.input('reset').put(0);
      dut.input('we').put(0);
      dut.input('re').put(1);
      dut.input('ra').put(1);
      dut.input('wa').put(0);
      dut.input('wd').put(0);
    });
    Simulator.registerAction(2, () => dut.input('clk').put(1));
    Simulator.registerAction(3, () {
      expect(dut.output('out').value.toInt(), 0xa5);
      image = dut.sram.stateTransactions
          .transact(StateTransactionRequest<InferredSramImage>.snapshot(
              transactionId: 1))
          .image!;
      expect(() => incompatible.restore(image), throwsArgumentError);
      expect(incompatible.peek(1)!.toInt(), 0x77);
      dut.sram.poke(1, LogicValue.ofInt(0x33, 8));
      dut.input('clk').put(0);
    });
    Simulator.registerAction(4, () => dut.input('clk').put(1));
    Simulator.registerAction(5, () {
      expect(dut.output('out').value.toInt(), 0x33);
      dut.sram.stateTransactions.transact(
          StateTransactionRequest<InferredSramImage>.restore(
              transactionId: 2, image: image));
      expect(dut.sram.peek(1)!.toInt(), 0xa5);
      expect(dut.output('out').value.toInt(), 0xa5);
      expect(() => dut.sram.peek(3), throwsRangeError);
    });
    await Simulator.run();
  });

  test('two-state SystemC reports unknown read outputs',
      timeout: const Timeout(Duration(minutes: 2)), () async {
    final dir =
        await Directory.systemTemp.createTemp('inferred_sram_boundary_');
    try {
      final description =
          InferredSramDescription(addressWidth: 2, dataWidth: 8, entryCount: 3);
      for (final policy in SystemCUnknownOutputPolicy.values) {
        await File('${dir.path}/model.h').writeAsString(
            description.generateSystemC(
                className: 'Sram',
                options: SystemCModelOptions(
                    portType: SystemCModelPortType.twoState,
                    unknownOutputs: policy)));
        final cpp = '''
#include "model.h"
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_report_handler::set_actions(SC_ERROR, SC_THROW);
  sc_signal<bool> clk, reset, we, re;
  sc_signal<sc_uint<2>> wa, ra;
  sc_signal<sc_uint<8>> wd, out;
  Sram dut("dut");
  dut.clk(clk); dut.reset(reset); dut.wr_en_0(we); dut.wr_addr_0(wa);
  dut.wr_data_0(wd); dut.rd_en_0(re); dut.rd_addr_0(ra); dut.rd_data_0(out);
  clk=false; reset=true; we=false; re=false; wa=0; ra=0; wd=0;
  int stage=0;
  try {
    sc_start(1,SC_NS);
    ${policy == SystemCUnknownOutputPolicy.error ? 'return 1;' : ''}
    stage=1; clk=true; sc_start(1,SC_NS);
    clk=false; reset=false; re=true; sc_start(1,SC_NS);
    stage=2; clk=true; sc_start(1,SC_NS);
    return 2;
  } catch(const sc_report&) {
    return stage==${policy == SystemCUnknownOutputPolicy.error ? 0 : 2} ? 0 : 3;
  }
}
''';
        await File('${dir.path}/test.cpp').writeAsString(cpp);
        final compile = await Process.run('g++', [
          '-std=c++17',
          '${dir.path}/test.cpp',
          '-lsystemc',
          '-o',
          '${dir.path}/test'
        ]);
        expect(compile.exitCode, 0,
            reason: '$policy\n${compile.stdout}\n${compile.stderr}');
        final run = await Process.run('${dir.path}/test', []);
        expect(run.exitCode, 0,
            reason: '$policy\n${run.stdout}\n${run.stderr}');
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('factory enforces a single shared read/write port', () {
    final factory = inferredSramArray<Logic>();
    Memory<Logic> build(int accesses) => factory(
          clk: Logic(),
          reset: Logic(),
          readPorts: [DataPortInterface<Logic>(8, 2)],
          writePorts: [DataPortInterface<Logic>(8, 2)],
          entryCount: 3,
          readLatency: 1,
          maxConcurrentReads: 1,
          maxConcurrentWrites: 1,
          maxConcurrentAccesses: accesses,
          name: 'sram',
        );
    expect(build(1), isA<InferredSram<Logic>>());
    expect(() => build(2), throwsArgumentError);
  });

  test('SystemC supports scalar and wide SRAM ports',
      timeout: const Timeout(Duration(minutes: 2)), () async {
    final dir = await Directory.systemTemp.createTemp('inferred_sram_width_');
    try {
      for (final (addressWidth, dataWidth, entryCount) in [
        (2, 1, 4),
        (70, 80, 3)
      ]) {
        final description = InferredSramDescription(
            addressWidth: addressWidth,
            dataWidth: dataWidth,
            entryCount: entryCount);
        for (final portType in SystemCModelPortType.values) {
          final twoState = portType == SystemCModelPortType.twoState;
          String type(int width) => twoState
              ? width == 1
                  ? 'bool'
                  : width <= 64
                      ? 'sc_uint<$width>'
                      : 'sc_biguint<$width>'
              : width == 1
                  ? 'sc_logic'
                  : 'sc_lv<$width>';
          final one = twoState ? 'true' : 'SC_LOGIC_1';
          final zero = twoState ? 'false' : 'SC_LOGIC_0';
          await File('${dir.path}/model.h').writeAsString(
              description.generateSystemC(
                  className: 'Sram',
                  options: SystemCModelOptions(
                      portType: portType,
                      unknownOutputs:
                          SystemCUnknownOutputPolicy.zeroUntilReset)));
          final dataValue = dataWidth == 1 ? one : '0xf5';
          final result = dataWidth == 1
              ? 'out.read()==$one'
              : 'out.read().to_uint64()==0xf5';
          final cpp = '''
#include "model.h"
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_signal<${type(1)}> clk, reset, we, re;
  sc_signal<${type(addressWidth)}> wa, ra;
  sc_signal<${type(dataWidth)}> wd, out;
  Sram dut("dut");
  dut.clk(clk); dut.reset(reset); dut.wr_en_0(we); dut.wr_addr_0(wa);
  dut.wr_data_0(wd); dut.rd_en_0(re); dut.rd_addr_0(ra); dut.rd_data_0(out);
  clk=$zero; reset=$one; we=$zero; re=$zero; wa=0; ra=0; wd=$dataValue;
  sc_start(1,SC_NS); clk=$one; sc_start(1,SC_NS);
  clk=$zero; reset=$zero; we=$one; wa=${entryCount - 1}; sc_start(1,SC_NS);
  clk=$one; sc_start(1,SC_NS);
  clk=$zero; we=$zero; re=$one; ra=${entryCount - 1}; sc_start(1,SC_NS);
  clk=$one; sc_start(1,SC_NS);
  return $result ? 0 : 1;
}
''';
          await File('${dir.path}/test.cpp').writeAsString(cpp);
          final compile = await Process.run('g++', [
            '-std=c++17',
            '${dir.path}/test.cpp',
            '-lsystemc',
            '-o',
            '${dir.path}/test'
          ]);
          expect(compile.exitCode, 0,
              reason: '$addressWidth/$dataWidth $portType\n${compile.stderr}');
          final run = await Process.run('${dir.path}/test', []);
          expect(run.exitCode, 0,
              reason:
                  '$addressWidth/$dataWidth $portType\n${run.stdout}\n${run.stderr}');
        }
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('Dart, Verilog and SystemC SRAM miter with snapshot replay',
      timeout: const Timeout(Duration(minutes: 3)), () async {
    final dut = _Harness();
    await dut.build();
    final random = Random(4968);
    LogicValue randomValue(int width) => LogicValue.of([
          for (var bit = 0; bit < width; bit++)
            if (random.nextBool()) LogicValue.one else LogicValue.zero
        ]);
    final vectors = <Vector>[];
    for (var cycle = 0; cycle < 120; cycle++) {
      final write = random.nextBool();
      final inputs = <String, LogicValue>{
        'reset': cycle % 20 == 0 ? LogicValue.one : LogicValue.zero,
        'we': LogicValue.ofInt(write ? 1 : 0, 1),
        're': LogicValue.ofInt(!write && random.nextBool() ? 1 : 0, 1),
        'wa': randomValue(2),
        'ra': randomValue(2),
        'wd': randomValue(8),
      };
      if (cycle < 30) {
        inputs['wa'] = LogicValue.ofInt(random.nextInt(3), 2);
        inputs['ra'] = LogicValue.ofInt(random.nextInt(3), 2);
        if (cycle == 0) {
          inputs['we'] = LogicValue.zero;
          inputs['re'] = LogicValue.zero;
        } else if (cycle <= 3) {
          inputs['we'] = LogicValue.one;
          inputs['re'] = LogicValue.zero;
          inputs['wa'] = LogicValue.ofInt(cycle - 1, 2);
        }
      }
      if (cycle >= 30 && cycle % 3 != 0 && cycle % 20 != 0) {
        final names = inputs.keys.where((name) => name != 'reset').toList();
        final name = names[random.nextInt(names.length)];
        final value = inputs[name]!;
        final bits = [for (var i = 0; i < value.width; i++) value[i]];
        bits[random.nextInt(bits.length)] =
            random.nextBool() ? LogicValue.x : LogicValue.z;
        inputs[name] = LogicValue.of(bits);
      }
      if (cycle >= 30 && cycle % 29 == 5) {
        inputs['reset'] = LogicValue.x;
      }
      for (var phase = 0; phase < 2; phase++) {
        final step = {...inputs, 'clk': LogicValue.ofInt(phase, 1)};
        final time = cycle * 8 + phase * 4 + 1;
        Simulator.registerAction(time, () {
          for (final input in step.entries) {
            dut.input(input.key).put(input.value);
          }
        });
        Simulator.registerAction(time + 1, () {
          vectors.add(Vector(step, {'out': dut.output('out').value}));
        });
      }
    }
    await Simulator.run();
    expect(vectors.length, 240);
    SimCompare.checkIverilogVector(dut, vectors);
    await _checkSystemC(vectors, portType: SystemCModelPortType.fourState);
    await _checkSystemC(vectors.take(60).toList(),
        portType: SystemCModelPortType.twoState);
  });
}
