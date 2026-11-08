// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// replacement_miter_test.dart
// Cross-simulator replacement policy equivalence.
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
  _Harness(int count, BehavioralReplacementKind kind,
      {required bool software}) {
    final width = max(1, (count - 1).bitLength);
    final hits = List.generate(2, (_) => ReplacementAccessInterface(count));
    final commits = List.generate(2, (_) => ReplacementCommitInterface(count));
    final allocations =
        List.generate(2, (_) => ReplacementAllocationInterface(count));
    for (var i = 0; i < 2; i++) {
      hits[i].en <= addInput('access_${i}_en', Logic());
      hits[i].index <=
          addInput('access_${i}_index', Logic(width: width), width: width);
      commits[i].en <= addInput('commit_${i}_en', Logic());
      commits[i].index <=
          addInput('commit_${i}_index', Logic(width: width), width: width);
      allocations[i].en <= addInput('allocation_${i}_en', Logic());
      allocations[i].commit <= addInput('allocation_${i}_commit', Logic());
    }
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final valid = addInput('validMask', Logic(width: count), width: count);
    final eligible =
        addInput('eligibleMask', Logic(width: count), width: count);
    final ReplacementPolicy policy;
    if (software) {
      policy = BehavioralReplacementPolicy(
          clk: clk,
          reset: reset,
          validMask: valid,
          eligibleMask: eligible,
          accesses: hits,
          commits: commits,
          allocations: allocations,
          entryCount: count,
          kind: kind);
    } else if (kind == BehavioralReplacementKind.roundRobin) {
      policy = RoundRobinReplacement(
          clk: clk,
          reset: reset,
          validMask: valid,
          eligibleMask: eligible,
          accesses: hits,
          commits: commits,
          allocations: allocations,
          entryCount: count);
    } else {
      policy = TreePseudoLruReplacement(
          clk: clk,
          reset: reset,
          validMask: valid,
          eligibleMask: eligible,
          accesses: hits,
          commits: commits,
          allocations: allocations,
          entryCount: count);
    }
    addOutput('invalidAccess') <= policy.invalidAccess;
    addOutput('invalidCommit') <= policy.invalidCommit;
    for (var i = 0; i < 2; i++) {
      addOutput('allocation_${i}_valid') <= allocations[i].valid;
      addOutput('allocation_${i}_index', width: width) <= allocations[i].index;
      addOutput('allocation_${i}_evict') <= allocations[i].evict;
    }
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

String _binary(LogicValue value) =>
    [for (var bit = value.width - 1; bit >= 0; bit--) _bit(value[bit])].join();

Future<void> _checkSystemC(
  BehavioralReplacementDescription description,
  List<Vector> vectors, {
  required SystemCModelPortType portType,
}) async {
  final twoState = portType == SystemCModelPortType.twoState;
  final directory = await Directory.systemTemp.createTemp('replacement_miter_');
  try {
    final model = description.generateSystemC(
        className: 'Replacement',
        options: SystemCModelOptions(
            portType: portType,
            unknownOutputs: SystemCUnknownOutputPolicy.zeroUntilReset));
    await File('${directory.path}/model.h').writeAsString(model);
    String type(int width) => twoState
        ? width == 1
            ? 'bool'
            : width <= 64
                ? 'sc_uint<$width>'
                : 'sc_biguint<$width>'
        : width == 1
            ? 'sc_logic'
            : 'sc_lv<$width>';
    final cpp = StringBuffer('''
#include "model.h"
#include <iostream>
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  Replacement dut("dut");
  Replacement::image saved, beforeReset;
''');
    for (final port in [
      ...description.inputPorts.entries,
      ...description.outputPorts.entries
    ]) {
      cpp
        ..writeln('  sc_signal<${type(port.value)}> s_${port.key};')
        ..writeln('  dut.${port.key}(s_${port.key});');
    }

    void assign(String name, LogicValue value) {
      if (twoState) {
        cpp.writeln('  s_$name=${value.toBigInt()};');
      } else if (value.width == 1) {
        cpp.writeln('  s_$name=SC_LOGIC_${_bit(value)};');
      } else {
        cpp.writeln('  { sc_lv<${value.width}> v;');
        for (var bit = 0; bit < value.width; bit++) {
          cpp.writeln('    v[$bit]=SC_LOGIC_${_bit(value[bit])};');
        }
        cpp.writeln('    s_$name=v; }');
      }
    }

    final expected = <String>[];
    void capture(String label, Vector vector) {
      final fields = <String>[];
      for (final output in description.outputPorts.entries) {
        final signal = 's_${output.key}.read()';
        fields.add(twoState
            ? output.value == 1
                ? signal
                : 'sc_lv<${output.value}>($signal).to_string()'
            : output.value == 1
                ? '$signal.to_char()'
                : '$signal.to_string()');
      }
      cpp.writeln('  std::cout << "M $label " << '
          '${fields.join(' << " " << ')} << "\\n";');
      final values = description.outputPorts.keys
          .map((name) =>
              _binary(vector.expectedOutputValues[name] as LogicValue))
          .join(' ');
      expected.add('M $label $values');
    }

    for (final (step, vector) in vectors.indexed) {
      for (final input in vector.inputValues.entries) {
        assign(input.key, input.value as LogicValue);
      }
      cpp.writeln('  sc_start(1,SC_NS);');
      if (step == 0) {
        cpp.writeln('  beforeReset=dut.snapshot();');
      } else if (step == 10) {
        cpp.writeln('  saved=dut.snapshot();');
      }
      if (!(twoState && step == 0)) {
        capture('$step', vector);
      }
    }
    for (final input in vectors[10].inputValues.entries) {
      assign(input.key, input.value as LogicValue);
    }
    cpp.writeln('  dut.restore(saved); sc_start(1,SC_NS);');
    capture('restore', vectors[10]);
    if (!twoState) {
      for (final input in vectors[0].inputValues.entries) {
        assign(input.key, input.value as LogicValue);
      }
      cpp.writeln('  dut.restore(beforeReset); sc_start(1,SC_NS);');
      capture('restore_unknown', vectors[0]);
    }
    cpp.writeln('  return 0;\n}');
    await File('${directory.path}/test.cpp').writeAsString(cpp.toString());
    final compile = await Process.run('g++', [
      '-std=c++17',
      '${directory.path}/test.cpp',
      '-lsystemc',
      '-o',
      '${directory.path}/test'
    ]);
    expect(compile.exitCode, 0,
        reason: '$portType\n${compile.stdout}\n${compile.stderr}');
    final run = await Process.run('${directory.path}/test', []);
    expect(run.exitCode, 0, reason: '$portType\n${run.stdout}\n${run.stderr}');
    final actual = (run.stdout as String)
        .split('\n')
        .where((line) => line.startsWith('M '))
        .toList();
    expect(actual, expected, reason: 'SystemC trace differs for $portType');
  } finally {
    await directory.delete(recursive: true);
  }
}

void main() {
  tearDown(Simulator.reset);

  test('two-state SystemC reports unknown outputs at the configured boundary',
      timeout: const Timeout(Duration(minutes: 2)), () async {
    final directory = await Directory.systemTemp.createTemp('replacement_x_');
    try {
      final description = BehavioralReplacementDescription(
          replacementKind: BehavioralReplacementKind.roundRobin,
          entryCount: 3,
          accessCount: 0,
          commitCount: 0,
          allocationCount: 1);
      for (final policy in SystemCUnknownOutputPolicy.values) {
        await File('${directory.path}/model.h').writeAsString(
            description.generateSystemC(
                className: 'Replacement',
                options: SystemCModelOptions(
                    portType: SystemCModelPortType.twoState,
                    unknownOutputs: policy)));
        final cpp = '''
#include "model.h"
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_report_handler::set_actions(SC_ERROR, SC_THROW);
  sc_signal<bool> clk, reset, invalidAccess, invalidCommit, en, commit, valid, evict;
  sc_signal<sc_uint<3>> validMask, eligibleMask;
  sc_signal<sc_uint<2>> index;
  Replacement dut("dut");
  dut.clk(clk); dut.reset(reset); dut.validMask(validMask);
  dut.eligibleMask(eligibleMask); dut.invalidAccess(invalidAccess);
  dut.invalidCommit(invalidCommit); dut.allocation_0_en(en);
  dut.allocation_0_commit(commit); dut.allocation_0_valid(valid);
  dut.allocation_0_index(index); dut.allocation_0_evict(evict);
  clk=false; reset=true; validMask=7; eligibleMask=7; en=true; commit=false;
  int stage=0;
  try {
    sc_start(1,SC_NS);
    ${policy == SystemCUnknownOutputPolicy.error ? 'return 1;' : ''}
    stage=1;
    clk=true; sc_start(1,SC_NS);
    clk=false; sc_start(1,SC_NS);
    auto image=dut.snapshot();
    image.state=sc_lv<2>(SC_LOGIC_X);
    image.resetSeen=true;
    dut.restore(image); stage=2; sc_start(1,SC_NS);
    return 2;
  } catch(const sc_report&) {
    return stage==${policy == SystemCUnknownOutputPolicy.error ? 0 : 2} ? 0 : 3;
  }
}
''';
        await File('${directory.path}/test.cpp').writeAsString(cpp);
        final compile = await Process.run('g++', [
          '-std=c++17',
          '${directory.path}/test.cpp',
          '-lsystemc',
          '-o',
          '${directory.path}/test'
        ]);
        expect(compile.exitCode, 0,
            reason: '$policy\n${compile.stdout}\n${compile.stderr}');
        final run = await Process.run('${directory.path}/test', []);
        expect(run.exitCode, 0,
            reason: '$policy\n${run.stdout}\n${run.stderr}');
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('SystemC replacement supports masks wider than 64 bits',
      timeout: const Timeout(Duration(minutes: 2)), () async {
    final directory =
        await Directory.systemTemp.createTemp('replacement_wide_');
    try {
      final description = BehavioralReplacementDescription(
          replacementKind: BehavioralReplacementKind.roundRobin,
          entryCount: 70,
          accessCount: 0,
          commitCount: 0,
          allocationCount: 1);
      for (final portType in SystemCModelPortType.values) {
        final twoState = portType == SystemCModelPortType.twoState;
        await File('${directory.path}/model.h').writeAsString(
            description.generateSystemC(
                className: 'Replacement',
                options: SystemCModelOptions(
                    portType: portType,
                    unknownOutputs:
                        SystemCUnknownOutputPolicy.zeroUntilReset)));
        final bit = twoState ? 'bool' : 'sc_logic';
        final mask = twoState ? 'sc_biguint<70>' : 'sc_lv<70>';
        final index = twoState ? 'sc_uint<7>' : 'sc_lv<7>';
        final zero = twoState ? 'false' : 'SC_LOGIC_0';
        final one = twoState ? 'true' : 'SC_LOGIC_1';
        final cpp = '''
#include "model.h"
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_signal<$bit> clk, reset, invalidAccess, invalidCommit, en, commit, valid, evict;
  sc_signal<$mask> validMask, eligibleMask;
  sc_signal<$index> index;
  Replacement dut("dut");
  dut.clk(clk); dut.reset(reset); dut.validMask(validMask);
  dut.eligibleMask(eligibleMask); dut.invalidAccess(invalidAccess);
  dut.invalidCommit(invalidCommit); dut.allocation_0_en(en);
  dut.allocation_0_commit(commit); dut.allocation_0_valid(valid);
  dut.allocation_0_index(index); dut.allocation_0_evict(evict);
  $mask eligible=0; eligible[68]=1;
  clk=$zero; reset=$one; validMask=0; eligibleMask=eligible; en=$one; commit=$zero;
  sc_start(1,SC_NS);
  clk=$one; sc_start(1,SC_NS);
  return valid.read()==$one && index.read().to_uint()==68 && evict.read()==$zero
    ? 0 : 1;
}
''';
        await File('${directory.path}/test.cpp').writeAsString(cpp);
        final compile = await Process.run('g++', [
          '-std=c++17',
          '${directory.path}/test.cpp',
          '-lsystemc',
          '-o',
          '${directory.path}/test'
        ]);
        expect(compile.exitCode, 0,
            reason: '$portType\n${compile.stdout}\n${compile.stderr}');
        final run = await Process.run('${directory.path}/test', []);
        expect(run.exitCode, 0,
            reason: '$portType\n${run.stdout}\n${run.stderr}');
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  for (final (kind, count) in [
    (BehavioralReplacementKind.roundRobin, 1),
    (BehavioralReplacementKind.roundRobin, 3),
    (BehavioralReplacementKind.treePseudoLru, 1),
    (BehavioralReplacementKind.treePseudoLru, 4)
  ]) {
    test('$kind $count four-state Dart, Verilog and SystemC miter',
        timeout: const Timeout(Duration(minutes: 3)), () async {
      final rtl = _Harness(count, kind, software: false);
      final software = _Harness(count, kind, software: true);
      await rtl.build();
      await software.build();
      final random = Random(426 + count);
      final widths = {
        for (final port in rtl.inputs.values) port.name: port.width
      };
      final outputNames = rtl.outputs.keys.toList();
      final vectors = <Vector>[];
      for (var cycle = 0; cycle < 120; cycle++) {
        final inputs = <String, LogicValue>{};
        for (final port in widths.entries) {
          final bits = [
            for (var b = 0; b < port.value; b++)
              if (random.nextBool()) LogicValue.one else LogicValue.zero
          ];
          inputs[port.key] = LogicValue.of(bits);
        }
        inputs['reset'] = cycle % 20 == 0 ? LogicValue.one : LogicValue.zero;
        if (cycle >= 30 && cycle % 3 != 0 && cycle % 20 != 0) {
          final names = widths.keys
              .where((name) => name != 'clk' && name != 'reset')
              .toList();
          final name = names[random.nextInt(names.length)];
          final value = inputs[name]!;
          final bits = [for (var bit = 0; bit < value.width; bit++) value[bit]];
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
              rtl.input(input.key).put(input.value);
              software.input(input.key).put(input.value);
            }
          });
          Simulator.registerAction(time + 1, () {
            final outputs = {
              for (final name in outputNames) name: rtl.output(name).value
            };
            for (final output in outputs.entries) {
              expect(software.output(output.key).value, output.value,
                  reason: '$kind/$count cycle=$cycle phase=$phase '
                      'inputs=$step output=${output.key}');
            }
            vectors.add(Vector(step, outputs));
          });
        }
      }
      await Simulator.run();
      expect(vectors.length, 240);
      SimCompare.checkIverilogVector(rtl, vectors);
      final description = BehavioralReplacementDescription(
          replacementKind: kind,
          entryCount: count,
          accessCount: 2,
          commitCount: 2,
          allocationCount: 2);
      await _checkSystemC(description, vectors,
          portType: SystemCModelPortType.fourState);
      await _checkSystemC(description, vectors.take(60).toList(),
          portType: SystemCModelPortType.twoState);
    });
  }
}
