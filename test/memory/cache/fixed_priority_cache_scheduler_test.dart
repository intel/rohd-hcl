// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_priority_cache_scheduler_test.dart
// Tests resource scheduling against an independent reference model.
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
  _Harness({bool behavioral = false}) {
    final ports = CacheSchedulerPorts(requestCount: 3, capacities: [2, 3]);
    for (var resource = 0; resource < 2; resource++) {
      ports.available[resource] <=
          addInput('a$resource', Logic(width: 2), width: 2);
    }
    for (var index = 0; index < 3; index++) {
      ports.requests[index].valid <= addInput('v$index', Logic());
      ports.conflicts[index] <= addInput('c$index', Logic(width: 3), width: 3);
      for (var resource = 0; resource < 2; resource++) {
        ports.requests[index].demand[resource] <=
            addInput('d${index}_$resource', Logic(width: 2), width: 2);
      }
    }
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    if (behavioral) {
      BehavioralFixedPriorityCacheScheduler(
          clk: clk, reset: reset, ports: ports);
    } else {
      FixedPriorityCacheScheduler(clk: clk, reset: reset, ports: ports);
    }
    addOutput('invalid') <= ports.invalidInputs;
    for (var index = 0; index < 3; index++) {
      addOutput('g$index') <= ports.requests[index].grant;
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

Future<void> _checkBehavioralSystemC(
    List<Vector> vectors, SystemCModelPortType portType) async {
  final twoState = portType == SystemCModelPortType.twoState;
  final dir = await Directory.systemTemp.createTemp('scheduler_miter_');
  try {
    final model = CacheSchedulerDescription(requestCount: 3, capacities: [2, 3])
        .generateSystemC(
            className: 'Scheduler',
            options: SystemCModelOptions(portType: portType));
    await File('${dir.path}/model.h').writeAsString(model);
    final cpp = StringBuffer('''
#include "model.h"
#include <iostream>
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_signal<${twoState ? 'bool' : 'sc_logic'}> clk, reset, invalid, v[3], g[3];
  sc_signal<${twoState ? 'sc_uint<2>' : 'sc_lv<2>'}> a[2], d[3][2];
  sc_signal<${twoState ? 'sc_uint<3>' : 'sc_lv<3>'}> c[3];
  Scheduler dut("dut");
  dut.clk(clk); dut.reset(reset); dut.invalidInputs(invalid);
  dut.available_0(a[0]); dut.available_1(a[1]);
''');
    for (var i = 0; i < 3; i++) {
      cpp.writeln('  dut.request_${i}_valid(v[$i]); '
          'dut.request_${i}_conflicts(c[$i]); dut.request_${i}_grant(g[$i]);');
      for (var r = 0; r < 2; r++) {
        cpp.writeln('  dut.request_${i}_demand_$r(d[$i][$r]);');
      }
    }
    void assign(String target, LogicValue value) {
      if (twoState) {
        cpp.writeln('  $target=${value.toInt()};');
      } else if (value.width == 1) {
        cpp.writeln('  $target=SC_LOGIC_${_bit(value)};');
      } else {
        cpp.writeln('  { sc_lv<${value.width}> value;');
        for (var bit = 0; bit < value.width; bit++) {
          cpp.writeln('    value[$bit]=SC_LOGIC_${_bit(value[bit])};');
        }
        cpp.writeln('    $target=value; }');
      }
    }

    for (final (index, vector) in vectors.indexed) {
      final values = vector.inputValues;
      assign('clk', values['clk'] as LogicValue);
      assign('reset', values['reset'] as LogicValue);
      for (var r = 0; r < 2; r++) {
        assign('a[$r]', values['a$r'] as LogicValue);
      }
      for (var i = 0; i < 3; i++) {
        assign('v[$i]', values['v$i'] as LogicValue);
        assign('c[$i]', values['c$i'] as LogicValue);
        for (var r = 0; r < 2; r++) {
          assign('d[$i][$r]', values['d${i}_$r'] as LogicValue);
        }
      }
      cpp.writeln('  sc_start(1,SC_NS);');
      final actual = twoState
          ? 'invalid.read() << g[0].read() << g[1].read() << g[2].read()'
          : 'invalid.read().to_char() << g[0].read().to_char()'
              ' << g[1].read().to_char() << g[2].read().to_char()';
      cpp.writeln('  std::cout << "M $index " << $actual << "\\n";');
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
    expect(compile.exitCode, 0, reason: '${compile.stdout}\n${compile.stderr}');
    final run = await Process.run('${dir.path}/test', []);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    final actual = (run.stdout as String)
        .split('\n')
        .where((line) => line.startsWith('M '))
        .toList();
    expect(actual, [
      for (final (index, vector) in vectors.indexed)
        'M $index ${[
          vector.expectedOutputValues['invalid'] as LogicValue,
          for (var i = 0; i < 3; i++)
            vector.expectedOutputValues['g$i'] as LogicValue
        ].map(_bit).join()}'
    ]);
  } finally {
    await dir.delete(recursive: true);
  }
}

void main() {
  tearDown(Simulator.reset);

  test('matches greedy arbitration for resources and asymmetric conflicts',
      () async {
    final dut = _Harness();
    final random = Random(629);
    final vectors = <Vector>[];
    for (var iteration = 0; iteration < 300; iteration++) {
      final valid = List.generate(3, (_) => random.nextInt(2));
      final available = [random.nextInt(4), random.nextInt(4)];
      final demand =
          List.generate(3, (_) => [random.nextInt(4), random.nextInt(4)]);
      final conflicts = List.generate(3, (_) => random.nextInt(8));
      final reset = random.nextInt(9) == 0 ? 1 : 0;
      final invalid = available[0] > 2 ||
          List.generate(3, (i) => i)
              .any((i) => valid[i] == 1 && demand[i][0] > 2);
      final remaining = List<int>.of(available);
      final grants = [0, 0, 0];
      for (var i = 0; i < 3; i++) {
        final conflict = List.generate(i, (j) => j).any((j) =>
            grants[j] == 1 &&
            (((conflicts[i] >> j) & 1) == 1 || ((conflicts[j] >> i) & 1) == 1));
        if (reset == 0 &&
            !invalid &&
            valid[i] == 1 &&
            !conflict &&
            demand[i][0] <= remaining[0] &&
            demand[i][1] <= remaining[1]) {
          grants[i] = 1;
          remaining[0] -= demand[i][0];
          remaining[1] -= demand[i][1];
        }
      }
      vectors.add(Vector({
        'clk': iteration % 2,
        'reset': reset,
        for (var r = 0; r < 2; r++) 'a$r': available[r],
        for (var i = 0; i < 3; i++) 'v$i': valid[i],
        for (var i = 0; i < 3; i++) 'c$i': conflicts[i],
        for (var i = 0; i < 3; i++)
          for (var r = 0; r < 2; r++) 'd${i}_$r': demand[i][r],
      }, {
        'invalid': invalid ? 1 : 0,
        for (var i = 0; i < 3; i++) 'g$i': grants[i],
      }));
    }
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(SimCompare.checkSystemCVector(dut, vectors), isTrue);
  });

  test('unknown demand propagates instead of producing a definite grant',
      () async {
    final dut = _Harness();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 0,
        'a0': 2,
        'a1': 3,
        'v0': 1,
        'v1': 0,
        'v2': 0,
        'd0_0': LogicValue.ofString('x1'),
        'd0_1': 0,
        'd1_0': 0,
        'd1_1': 0,
        'd2_0': 0,
        'd2_1': 0,
        'c0': 0,
        'c1': 0,
        'c2': 0,
      }, {
        'invalid': LogicValue.x,
        'g0': LogicValue.x,
        'g1': 0,
        'g2': 0
      }),
      Vector({'reset': 1}, {'g0': 0, 'g1': 0, 'g2': 0}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('behavioral Dart and SystemC match Verilog for four-state arbitration',
      timeout: const Timeout(Duration(minutes: 3)), () async {
    final rtl = _Harness();
    final behavioral = _Harness(behavioral: true);
    await rtl.build();
    await behavioral.build();
    final random = Random(83952);
    LogicValue randomValue(int width, {required bool fourState}) =>
        LogicValue.of([
          for (var i = 0; i < width; i++)
            [
              LogicValue.zero,
              LogicValue.one,
              if (fourState) ...[LogicValue.x, LogicValue.z]
            ][random.nextInt(fourState ? 4 : 2)]
        ]);
    final vectors = <Vector>[];
    for (var iteration = 0; iteration < 600; iteration++) {
      final fourState = iteration >= 400;
      final inputs = <String, LogicValue>{
        'clk': randomValue(1, fourState: false),
        'reset': randomValue(1, fourState: fourState),
        for (var r = 0; r < 2; r++) 'a$r': randomValue(2, fourState: fourState),
        for (var i = 0; i < 3; i++) 'v$i': randomValue(1, fourState: fourState),
        for (var i = 0; i < 3; i++) 'c$i': randomValue(3, fourState: fourState),
        for (var i = 0; i < 3; i++)
          for (var r = 0; r < 2; r++)
            'd${i}_$r': randomValue(2, fourState: fourState),
      };
      if (iteration >= 200 && iteration < 400) {
        final names = inputs.keys.where((name) => name != 'clk').toList();
        final name = names[random.nextInt(names.length)];
        final value = inputs[name]!;
        final bits = [for (var bit = 0; bit < value.width; bit++) value[bit]];
        bits[random.nextInt(bits.length)] =
            random.nextBool() ? LogicValue.x : LogicValue.z;
        inputs[name] = LogicValue.of(bits);
      }
      final time = 2 + iteration * 4;
      Simulator.registerAction(time, () {
        for (final input in inputs.entries) {
          rtl.input(input.key).put(input.value);
          behavioral.input(input.key).put(input.value);
        }
      });
      Simulator.registerAction(time + 1, () {
        final outputs = <String, LogicValue>{
          for (final name in ['invalid', 'g0', 'g1', 'g2'])
            name: rtl.output(name).value
        };
        for (final output in outputs.entries) {
          expect(behavioral.output(output.key).value, output.value,
              reason: 'vector $iteration: $inputs, output ${output.key}');
        }
        vectors.add(Vector(inputs, outputs));
      });
    }
    await Simulator.run();
    expect(vectors.length, 600);
    SimCompare.checkIverilogVector(rtl, vectors);
    await _checkBehavioralSystemC(vectors, SystemCModelPortType.fourState);
    await _checkBehavioralSystemC(
        vectors.take(200).toList(), SystemCModelPortType.twoState);
  });

  test('SystemC scheduler supports scalar and wide conflict ports',
      timeout: const Timeout(Duration(minutes: 3)), () async {
    final dir = await Directory.systemTemp.createTemp('scheduler_geometry_');
    try {
      for (final requestCount in [1, 65]) {
        final description = CacheSchedulerDescription(
            requestCount: requestCount, capacities: [1]);
        for (final portType in SystemCModelPortType.values) {
          final twoState = portType == SystemCModelPortType.twoState;
          final header = description.generateSystemC(
              className: 'Scheduler',
              options: SystemCModelOptions(portType: portType));
          await File('${dir.path}/model.h').writeAsString(header);
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
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  Scheduler dut("dut");
''');
          for (final port in [
            ...description.inputPorts.entries,
            ...description.outputPorts.entries
          ]) {
            cpp
              ..writeln('  sc_signal<${type(port.value)}> s_${port.key};')
              ..writeln('  dut.${port.key}(s_${port.key});');
          }
          for (final port in description.inputPorts.entries) {
            final zero = !twoState && port.value == 1 ? 'SC_LOGIC_0' : '0';
            cpp.writeln('  s_${port.key}=$zero;');
          }
          cpp
            ..writeln(
                '  s_request_0_valid=${twoState ? 'true' : 'SC_LOGIC_1'};')
            ..writeln('  sc_start(1,SC_NS);')
            ..writeln('  return s_request_0_grant.read()=='
                '${twoState ? 'true' : 'SC_LOGIC_1'} ? 0 : 1;')
            ..writeln('}');
          await File('${dir.path}/test.cpp').writeAsString(cpp.toString());
          final compile = await Process.run('g++', [
            '-std=c++17',
            '${dir.path}/test.cpp',
            '-lsystemc',
            '-o',
            '${dir.path}/test'
          ]);
          expect(compile.exitCode, 0,
              reason: '$requestCount $portType:\n${compile.stderr}');
          final run = await Process.run('${dir.path}/test', []);
          expect(run.exitCode, 0,
              reason: '$requestCount $portType:\n${run.stdout}\n${run.stderr}');
        }
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
