// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// behavioral_parallel_associative_test.dart
// Cycle and four-state comparisons for parallel associative memories.
//
// 2026 November 8
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:test/test.dart';

class _Key extends LogicStructure {
  _Key({String name = 'key'})
      : super([Logic(name: 'low', width: 4), Logic(name: 'high', width: 4)],
            name: name);

  @override
  _Key clone({String? name}) => _Key(name: name ?? this.name);
}

class _Harness extends Module {
  late final AssociativeMemory memory;

  _Harness(
      {required bool behavioral,
      required int entries,
      required AssociativeMatchSelection selection,
      required AssociativeUpdateCollisionPolicy collision,
      int keyWidth = 4,
      int indexWidth = 2}) {
    final updates = List.generate(
        2,
        (_) => AssociativeUpdatePortInterface(
            keyWidth: keyWidth, indexWidth: indexWidth));
    final lookups = List.generate(
        2,
        (_) => AssociativeLookupPortInterface(
            keyWidth: keyWidth,
            indexWidth: indexWidth,
            matchEntryCount: entries));
    final sides = List.generate(
        2, (_) => AssociativeIndexedSideReadRequest(indexWidth: indexWidth));
    for (var i = 0; i < 2; i++) {
      updates[i].en <= addInput('we$i', Logic());
      updates[i].index <=
          addInput('wi$i', Logic(width: indexWidth), width: indexWidth);
      updates[i].key <=
          addInput('wk$i', Logic(width: keyWidth), width: keyWidth);
      updates[i].entryValid <= addInput('wv$i', Logic());
      lookups[i].en <= addInput('qe$i', Logic());
      lookups[i].key <=
          addInput('qk$i', Logic(width: keyWidth), width: keyWidth);
      sides[i].index <=
          addInput('side$i', Logic(width: indexWidth), width: indexWidth);
    }
    final factory = behavioral
        ? behavioralParallelAssociativeMemoryFunctor
        : parallelAssociativeMemoryFunctor;
    memory = factory(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      updatePorts: updates,
      lookupPorts: lookups,
      sideReadRequests: sides,
      requiresValidityMask: true,
      entryCount: entries,
      lookupLatency: 0,
      duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
      matchSelection: selection,
      resultShape: AssociativeResultShape.matchVectorAndSelectedIndex,
      lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
      updateCollisionPolicy: collision,
      name: 'memory',
    ).memory!;
    final sideProvider = memory as AssociativeMultiIndexedSideReadProvider;
    for (var i = 0; i < 2; i++) {
      addOutput('hit$i') <= lookups[i].hit;
      addOutput('index$i', width: indexWidth) <= lookups[i].index;
      addOutput('matches$i', width: entries) <= lookups[i].matchVector!;
      addOutput('sideKey$i', width: keyWidth) <=
          sideProvider.sideReadResponses[i].key;
      addOutput('sideValid$i') <= sideProvider.sideReadResponses[i].entryValid;
    }
    addOutput('validMask', width: entries) <=
        (memory as AssociativeValidityMaskProvider).validMask!;
    if (memory is ParallelAssociativeMemory) {
      final tracked = memory as ParallelAssociativeMemory;
      addOutput('count', width: (entries + 1).log2Ceil) <= tracked.validCount!;
      addOutput('full') <= tracked.full!;
      addOutput('empty') <= tracked.empty!;
    } else {
      final tracked = memory as BehavioralParallelAssociativeMemory;
      addOutput('count', width: (entries + 1).log2Ceil) <= tracked.validCount!;
      addOutput('full') <= tracked.full!;
      addOutput('empty') <= tracked.empty!;
    }
  }
}

Future<void> _checkSystemC(_Harness software, List<Vector> trace) async {
  final model = software.memory as BehavioralParallelAssociativeMemory;
  final inputNames = {
    'clk': 'clk',
    'reset': 'reset',
    for (var i = 0; i < 2; i++) ...{
      'update_en_$i': 'we$i',
      'update_index_$i': 'wi$i',
      'update_key_$i': 'wk$i',
      'update_entryValid_$i': 'wv$i',
      'lookup_en_$i': 'qe$i',
      'lookup_key_$i': 'qk$i',
      'side_read_index${i == 0 ? '' : '_$i'}': 'side$i',
    }
  };
  final outputNames = {
    for (var i = 0; i < 2; i++) ...{
      'lookup_hit_$i': 'hit$i',
      'lookup_index_$i': 'index$i',
      'lookup_matchVector_$i': 'matches$i',
      'side_read_key${i == 0 ? '' : '_$i'}': 'sideKey$i',
      'side_read_valid${i == 0 ? '' : '_$i'}': 'sideValid$i',
    },
    'valid_count': 'count',
    'full': 'full',
    'empty': 'empty',
    'valid_mask': 'validMask',
  };
  expect(model.description.inputPorts.keys, unorderedEquals(inputNames.keys));
  expect(model.description.outputPorts.keys, unorderedEquals(outputNames.keys));
  String binary(LogicValue value) =>
      MemoryValueCodec.binary(value).toUpperCase();
  final cpp = StringBuffer('''
#include "model.h"
#include <iostream>
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
''');
  for (final entry in {...software.inputs, ...software.outputs}.entries) {
    final width = entry.value.width;
    cpp.writeln('sc_signal<${width == 1 ? 'sc_logic' : 'sc_lv<$width>'}> '
        '${entry.key};');
  }
  cpp.writeln('Cam dut("dut");');
  for (final entry in {...inputNames, ...outputNames}.entries) {
    cpp.writeln('dut.${entry.key}(${entry.value});');
  }
  for (final (step, vector) in trace.indexed) {
    for (final input in vector.inputValues.entries) {
      final width = software.input(input.key).width;
      final value = LogicValue.of(input.value, width: width);
      if (width == 1) {
        cpp.writeln('${input.key}=SC_LOGIC_${binary(value)};');
      } else {
        cpp.writeln('{ sc_lv<$width> value;');
        for (var bit = 0; bit < width; bit++) {
          cpp.writeln('value[$bit]=SC_LOGIC_${binary(value[bit])};');
        }
        cpp.writeln('${input.key}=value; }');
      }
    }
    cpp.writeln('sc_start(1,SC_NS);');
    for (final expected in vector.expectedOutputValues.entries) {
      final value = expected.value as LogicValue;
      final check = value.width == 1
          ? "${expected.key}.read().to_char()!='${binary(value)}'"
          : '${expected.key}.read().to_string()!="${binary(value)}"';
      cpp.writeln('if($check) { std::cerr << "vector $step ${expected.key}: "'
          ' << ${expected.key}.read() << std::endl; return 1; }');
    }
  }
  cpp.writeln('return 0;\n}');
  final dir = await Directory.systemTemp.createTemp('parallel_assoc_miter_');
  try {
    await File('${dir.path}/model.h')
        .writeAsString(model.generateSystemC(className: 'Cam'));
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

  test('invalid clock transitions poison parallel associative state in ROHD',
      timeout: const Timeout(Duration(minutes: 2)), () async {
    final rtl = _Harness(
        behavioral: false,
        entries: 3,
        selection: AssociativeMatchSelection.lowestIndex,
        collision: AssociativeUpdateCollisionPolicy.highestPortWins);
    final software = _Harness(
        behavioral: true,
        entries: 3,
        selection: AssociativeMatchSelection.lowestIndex,
        collision: AssociativeUpdateCollisionPolicy.highestPortWins);
    await rtl.build();
    await software.build();
    final inputs = <Map<String, dynamic>>[
      {
        'clk': 0,
        'reset': 1,
        for (var i = 0; i < 2; i++) ...{
          'we$i': 0,
          'wi$i': 0,
          'wk$i': 0,
          'wv$i': 0,
          'qe$i': 1,
          'qk$i': 0,
          'side$i': 0,
        }
      },
      {'clk': 1},
      {'reset': 0},
      {'clk': LogicValue.x},
      {'clk': 0},
      {'reset': 1},
      {'clk': 1},
    ];
    final trace = List<Vector?>.filled(inputs.length, null);
    for (final (step, values) in inputs.indexed) {
      Simulator.registerAction(1 + step * 10, () {
        for (final input in values.entries) {
          rtl.input(input.key).put(input.value);
          software.input(input.key).put(input.value);
        }
        unawaited(Simulator.postTick.first.then((_) {
          for (final output in rtl.outputs.entries) {
            expect(software.output(output.key).value, output.value.value,
                reason: 'vector $step ${output.key}');
          }
          if (step == 3 || step == 4) {
            expect(rtl.output('sideValid0').value, LogicValue.x);
            expect(rtl.output('sideKey0').value,
                LogicValue.filled(4, LogicValue.x));
          }
          if (step == 6) {
            expect(rtl.output('validMask').value, LogicValue.ofInt(0, 3));
          }
          trace[step] = Vector(values, {
            for (final output in rtl.outputs.entries)
              output.key: output.value.value
          });
        }));
      });
    }
    await Simulator.run();
    final vectors = trace.map((item) => item!).toList();
    SimCompare.checkIverilogVector(rtl, [
      for (final (step, vector) in vectors.indexed)
        if (step >= 3 && step <= 5)
          Vector(vector.inputValues, vectors[1].expectedOutputValues)
        else
          vector,
    ]);
    await _checkSystemC(software, vectors);
  });

  for (final selection in AssociativeMatchSelection.values) {
    for (final collision in [
      AssociativeUpdateCollisionPolicy.lowestPortWins,
      AssociativeUpdateCollisionPolicy.highestPortWins
    ]) {
      test('wide concurrent associative miter $selection $collision',
          timeout: const Timeout(Duration(minutes: 3)), () async {
        const width = 80;
        final rtl = _Harness(
            behavioral: false,
            entries: 3,
            selection: selection,
            collision: collision,
            keyWidth: width,
            indexWidth: width);
        final software = _Harness(
            behavioral: true,
            entries: 3,
            selection: selection,
            collision: collision,
            keyWidth: width,
            indexWidth: width);
        await rtl.build();
        await software.build();
        LogicValue wide(BigInt value) => LogicValue.ofBigInt(value, width);
        final high = wide((BigInt.one << 79) | (BigInt.one << 64) | BigInt.one);
        final low = wide(BigInt.one);
        final alias = wide((BigInt.one << 75) | BigInt.one);
        final unknownHigh = LogicValue.ofString('x${'0' * 14}1${'0' * 63}1');
        final highMismatch = LogicValue.ofString('1x${'0' * 77}1');
        final unknownIndex = LogicValue.ofString('x${'0' * 78}1');
        final invalidUnknownIndex = LogicValue.ofString('1${'0' * 78}x');
        final stimuli = <Map<String, dynamic>>[
          {
            'clk': 0,
            'reset': 1,
            for (var i = 0; i < 2; i++) ...{
              'we$i': 0,
              'wi$i': 0,
              'wk$i': 0,
              'wv$i': 0,
              'qe$i': 0,
              'qk$i': 0,
              'side$i': 0,
            }
          },
          {'clk': 1},
          {
            'clk': 0,
            'reset': 0,
            'we0': 1,
            'wi0': 1,
            'wk0': high,
            'wv0': 1,
            'we1': 1,
            'wi1': 1,
            'wk1': low,
            'wv1': 1,
            'qe0': 1,
            'qk0': high,
            'qe1': 1,
            'qk1': low,
            'side0': 1,
            'side1': alias,
          },
          {'clk': 1},
          {
            'clk': 0,
            'wi0': 0,
            'wk0': high,
            'wi1': 2,
            'wk1': high,
          },
          {'clk': 1},
          {
            'clk': 0,
            'wi0': alias,
            'wk0': low,
            'we1': 0,
            'side0': alias,
          },
          {'clk': 1},
          {
            'clk': 0,
            'we0': 0,
            'qk0': unknownHigh,
            'qk1': highMismatch,
            'side0': 2,
          },
          {
            'we0': 1,
            'wi0': invalidUnknownIndex,
            'wk0': low,
            'qk0': high,
          },
          {'clk': 1},
          {
            'clk': 0,
            'wi0': unknownIndex,
            'we1': 1,
            'wi1': 1,
            'wk1': low,
            'side0': 1,
          },
          {'clk': 1},
        ];
        final trace = List<Vector?>.filled(stimuli.length, null);
        for (final (step, inputs) in stimuli.indexed) {
          Simulator.registerAction(1 + step * 10, () {
            for (final input in inputs.entries) {
              rtl.input(input.key).put(input.value);
              software.input(input.key).put(input.value);
            }
            unawaited(Simulator.postTick.first.then((_) {
              for (final output in rtl.outputs.entries) {
                expect(software.output(output.key).value, output.value.value,
                    reason: 'vector $step ${output.key}');
              }
              if (step == 3) {
                final lowWins = collision ==
                    AssociativeUpdateCollisionPolicy.lowestPortWins;
                expect(rtl.output('hit0').value, LogicValue.ofBool(lowWins));
                expect(rtl.output('hit1').value, LogicValue.ofBool(!lowWins));
                expect(rtl.output('sideValid1').value, LogicValue.zero);
                expect(rtl.output('sideKey1').value, wide(BigInt.zero));
              }
              if (step == 5 || step == 7 || step == 10) {
                final lowWins = collision ==
                    AssociativeUpdateCollisionPolicy.lowestPortWins;
                expect(rtl.output('matches0').value,
                    LogicValue.ofInt(lowWins ? 7 : 5, 3));
                expect(
                    rtl.output('index0').value,
                    wide(selection == AssociativeMatchSelection.lowestIndex
                        ? BigInt.zero
                        : BigInt.two));
              }
              if (step == 8) {
                expect(rtl.output('hit1').value, LogicValue.zero);
                expect(rtl.output('hit0').value, LogicValue.x);
                expect(rtl.output('sideKey0').value, high);
              }
              if (step == 12) {
                final lowWins = collision ==
                    AssociativeUpdateCollisionPolicy.lowestPortWins;
                expect(rtl.output('sideValid0').value,
                    lowWins ? LogicValue.x : LogicValue.one);
                expect(rtl.output('sideKey0').value,
                    lowWins ? LogicValue.filled(width, LogicValue.x) : low);
                expect(rtl.output('matches0').value,
                    LogicValue.ofString(lowWins ? '1x1' : '101'));
              }
              trace[step] = Vector(inputs, {
                for (final output in rtl.outputs.entries)
                  output.key: output.value.value
              });
            }));
          });
        }
        await Simulator.run();
        final vectors = trace.map((vector) => vector!).toList();
        SimCompare.checkIverilogVector(rtl, vectors);
        await _checkSystemC(software, vectors);
      });
    }
  }

  for (final entries in [1, 3]) {
    for (final selection in AssociativeMatchSelection.values) {
      for (final collision in [
        AssociativeUpdateCollisionPolicy.lowestPortWins,
        AssociativeUpdateCollisionPolicy.highestPortWins
      ]) {
        test('parallel behavioral miter $entries $selection $collision',
            () async {
          final rtl = _Harness(
              behavioral: false,
              entries: entries,
              selection: selection,
              collision: collision);
          final software = _Harness(
              behavioral: true,
              entries: entries,
              selection: selection,
              collision: collision);
          await rtl.build();
          await software.build();
          final random = Random(219 + entries);
          final bits = [
            LogicValue.zero,
            LogicValue.one,
            LogicValue.x,
            LogicValue.z
          ];
          LogicValue value(int width) => LogicValue.of(
              List.generate(width, (_) => bits[random.nextInt(4)]));
          final stimuli = <Map<String, dynamic>>[
            {
              'clk': 0,
              'reset': 1,
              for (var i = 0; i < 2; i++) ...{
                'we$i': 0,
                'wi$i': 0,
                'wk$i': 0,
                'wv$i': 0,
                'qe$i': 0,
                'qk$i': 0,
                'side$i': 0,
              }
            },
            {'clk': 1},
            {
              'clk': 0,
              'reset': 0,
              'we0': 1,
              'wi0': 0,
              'wk0': 5,
              'wv0': 1,
              'we1': 1,
              'wi1': 0,
              'wk1': 9,
              'wv1': 1,
              'qe0': 1,
              'qk0': 5,
              'qe1': 1,
              'qk1': 9,
              'side0': 0,
              'side1': 3,
            },
            {'clk': 1},
            for (var cycle = 0; cycle < 24; cycle++) ...[
              {
                'clk': 0,
                'reset': cycle == 9 ? LogicValue.x : 0,
                for (var i = 0; i < 2; i++) ...{
                  'we$i': value(1),
                  'wi$i': value(2),
                  'wk$i': value(4),
                  'wv$i': value(1),
                  'qe$i': value(1),
                  'qk$i': value(4),
                  'side$i': value(2),
                }
              },
              {'clk': 1},
            ],
            {'clk': 0, 'reset': 1},
            {'clk': 1},
            {
              'clk': 0,
              'reset': 0,
              'we0': 1,
              'wi0': 0,
              'wk0': 5,
              'wv0': 1,
              'we1': 1,
              'wi1': entries - 1,
              'wk1': 9,
              'wv1': 1,
              'qe0': 1,
              'qk0': 5,
              'qe1': 1,
              'qk1': 9,
              'side0': 0,
              'side1': entries - 1,
            },
            {'clk': 1},
          ];
          final trace = List<Vector?>.filled(stimuli.length, null);
          for (final (step, inputs) in stimuli.indexed) {
            Simulator.registerAction(1 + step * 10, () {
              for (final input in inputs.entries) {
                rtl.input(input.key).put(input.value);
                software.input(input.key).put(input.value);
              }
              unawaited(Simulator.postTick.first.then((_) {
                if (step == 3) {
                  final low = collision ==
                      AssociativeUpdateCollisionPolicy.lowestPortWins;
                  expect(rtl.output('hit0').value, LogicValue.ofBool(low));
                  expect(rtl.output('hit1').value, LogicValue.ofBool(!low));
                  expect(rtl.output('sideValid1').value, LogicValue.zero);
                }
                if (step == stimuli.length - 1) {
                  final lowWins = collision ==
                      AssociativeUpdateCollisionPolicy.lowestPortWins;
                  expect(rtl.output('hit0').value,
                      LogicValue.ofBool(entries > 1 || lowWins));
                  expect(rtl.output('hit1').value,
                      LogicValue.ofBool(entries > 1 || !lowWins));
                  expect(
                      rtl.output('count').value,
                      LogicValue.ofInt(
                          entries > 1 ? 2 : 1, (entries + 1).log2Ceil));
                }
                for (final output in rtl.outputs.entries) {
                  expect(software.output(output.key).value, output.value.value,
                      reason: 'vector $step ${output.key}');
                }
                trace[step] = Vector(inputs, {
                  for (final output in rtl.outputs.entries)
                    output.key: output.value.value
                });
              }));
            });
          }
          await Simulator.run();
          final vectors = trace.map((vector) => vector!).toList();
          SimCompare.checkIverilogVector(rtl, vectors);
          await _checkSystemC(software, vectors);
        });
      }
    }
  }

  test('snapshot restores entry state and combinational ports atomically',
      () async {
    final dut = _Harness(
        behavioral: true,
        entries: 3,
        selection: AssociativeMatchSelection.lowestIndex,
        collision: AssociativeUpdateCollisionPolicy.highestPortWins);
    await dut.build();
    final memory = dut.memory as BehavioralParallelAssociativeMemory;
    late AssociativeSoftwareExecutionImage image;
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        for (var i = 0; i < 2; i++) ...{
          'we$i': 0,
          'wi$i': 0,
          'wk$i': 0,
          'wv$i': 0,
          'qe$i': 1,
          'qk$i': 5,
          'side$i': 1,
        }
      }, {}),
      Vector({'clk': 1}, {}),
      Vector(
          {'clk': 0, 'reset': 0, 'we0': 1, 'wi0': 1, 'wk0': 5, 'wv0': 1}, {}),
      Vector({'clk': 1}, {'hit0': 1, 'index0': 1, 'sideKey0': 5}),
      Vector({'clk': 0, 'wk0': 9}, {}),
      Vector({'clk': 1}, {'hit0': 0, 'sideKey0': 9}),
      Vector({'clk': 0, 'we0': 0}, {'hit0': 1, 'sideKey0': 5}),
    ];
    Simulator.registerAction(35, () {
      image = memory.stateTransactions
          .transact(StateTransactionRequest<
              AssociativeSoftwareExecutionImage>.snapshot(transactionId: 1))
          .image!;
    });
    Simulator.registerAction(55, () {
      memory.stateTransactions.transact(
          StateTransactionRequest<AssociativeSoftwareExecutionImage>.restore(
              transactionId: 2, image: image));
    });
    await SimCompare.checkFunctionalVector(dut, vectors);
  });

  test('behavioral parallel model preserves structured key ports', () async {
    final clk = Logic();
    final reset = Logic();
    final update = TypedAssociativeUpdatePortInterface(_Key(), indexWidth: 1);
    final lookup = TypedAssociativeLookupPortInterface(_Key(),
        indexWidth: 1, matchEntryCount: 2);
    final binding = behavioralParallelAssociativeMemoryFunctor(
      clk: clk,
      reset: reset,
      updatePorts: [update],
      lookupPorts: [lookup],
      entryCount: 2,
      lookupLatency: 0,
      duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
      matchSelection: AssociativeMatchSelection.lowestIndex,
      resultShape: AssociativeResultShape.matchVectorAndSelectedIndex,
      lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
      updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
      name: 'typed_model',
    );
    final model = binding.memory!;
    expect(sameDeclaredPayloadShape(model.input('update_key_0'), update.key),
        isTrue);
    expect(sameDeclaredPayloadShape(model.input('lookup_key_0'), lookup.key),
        isTrue);
    await model.build();
    Simulator.registerAction(1, () {
      clk.put(0);
      reset.put(1);
      update.en.put(0);
      lookup.en.put(1);
      lookup.key.put(0x5a);
    });
    Simulator.registerAction(2, () => clk.put(1));
    Simulator.registerAction(3, () {
      clk.put(0);
      reset.put(0);
      update.en.put(1);
      update.index.put(1);
      update.key.put(0x5a);
      update.entryValid.put(1);
    });
    Simulator.registerAction(4, () => clk.put(1));
    Simulator.registerAction(5, () {
      expect(lookup.hit.value, LogicValue.one);
      expect(lookup.index.value, LogicValue.one);
      expect(lookup.matchVector!.value, LogicValue.ofInt(2, 2));
    });
    await Simulator.run();
  });

  test('SystemC snapshots restore combinational output and replay writes',
      timeout: const Timeout(Duration(minutes: 2)), () async {
    final dut = _Harness(
        behavioral: true,
        entries: 3,
        selection: AssociativeMatchSelection.lowestIndex,
        collision: AssociativeUpdateCollisionPolicy.highestPortWins);
    await dut.build();
    final memory = dut.memory as BehavioralParallelAssociativeMemory;
    final dir = await Directory.systemTemp.createTemp('assoc_snapshot_');
    try {
      for (final twoState in [false, true]) {
        await File('${dir.path}/model.h').writeAsString(memory.generateSystemC(
          className: 'Cam',
          options: SystemCModelOptions(
            portType: twoState
                ? SystemCModelPortType.twoState
                : SystemCModelPortType.fourState,
            unknownOutputs: SystemCUnknownOutputPolicy.zeroUntilReset,
          ),
        ));
        final bit = twoState ? 'bool' : 'sc_logic';
        final idx = twoState ? 'sc_uint<2>' : 'sc_lv<2>';
        final key = twoState ? 'sc_uint<4>' : 'sc_lv<4>';
        final mask = twoState ? 'sc_uint<3>' : 'sc_lv<3>';
        final one = twoState ? 'true' : 'SC_LOGIC_1';
        final zero = twoState ? 'false' : 'SC_LOGIC_0';
        final source = '''
#include "model.h"
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_signal<$bit> clk, reset, we[2], wv[2], qe[2], hit[2], sideValid[2], full, empty;
  sc_signal<$idx> wi[2], index[2], side[2], count;
  sc_signal<$key> wk[2], qk[2], sideKey[2];
  sc_signal<$mask> matches[2], validMask;
  Cam dut("dut"); dut.clk(clk); dut.reset(reset);
''';
        final cpp = StringBuffer(source);
        for (var i = 0; i < 2; i++) {
          final suffix = i == 0 ? '' : '_$i';
          cpp.writeln('''
  dut.update_en_$i(we[$i]); dut.update_index_$i(wi[$i]);
  dut.update_key_$i(wk[$i]); dut.update_entryValid_$i(wv[$i]);
  dut.lookup_en_$i(qe[$i]); dut.lookup_key_$i(qk[$i]);
  dut.lookup_hit_$i(hit[$i]); dut.lookup_index_$i(index[$i]);
  dut.lookup_matchVector_$i(matches[$i]);
  dut.side_read_index$suffix(side[$i]); dut.side_read_key$suffix(sideKey[$i]);
  dut.side_read_valid$suffix(sideValid[$i]);
  we[$i]=$zero; wi[$i]=0; wk[$i]=0; wv[$i]=$zero; qe[$i]=$one;
  qk[$i]=5; side[$i]=1;
''');
        }
        cpp.writeln('''
  dut.valid_count(count); dut.full(full); dut.empty(empty); dut.valid_mask(validMask);
  clk=$zero; reset=$one; sc_start(1,SC_NS);
  auto pulse=[&]() { clk=$one; sc_start(1,SC_NS); clk=$zero; sc_start(1,SC_NS); };
  pulse(); reset=$zero; we[0]=$one; wi[0]=1; wk[0]=5; wv[0]=$one; pulse();
  auto saved=dut.snapshot();
  wk[0]=9; pulse();
  if(hit[0].read()!=$zero) return 1;
  dut.restore(saved); sc_start(1,SC_NS);
  if(hit[0].read()!=$one || sideKey[0].read().to_uint()!=5) return 2;
  pulse();
  if(hit[0].read()!=$zero || sideKey[0].read().to_uint()!=9) return 3;
  return 0;
}
''');
        await File('${dir.path}/test.cpp').writeAsString(cpp.toString());
        final compile = await Process.run('g++', [
          '-std=c++17',
          '${dir.path}/test.cpp',
          '-lsystemc',
          '-o',
          '${dir.path}/test'
        ]);
        expect(compile.exitCode, 0,
            reason: '$twoState\n${compile.stdout}\n${compile.stderr}');
        final run = await Process.run('${dir.path}/test', []);
        expect(run.exitCode, 0,
            reason: '$twoState\n${run.stdout}\n${run.stderr}');
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('two-state SystemC reports unknown outputs at the chosen boundary',
      timeout: const Timeout(Duration(minutes: 2)), () async {
    final description = BehavioralParallelAssociativeDescription(
      entryCount: 2,
      keyWidth: 4,
      indexWidth: 1,
      updateCount: 0,
      matchVectors: [false],
      sideReadCount: 0,
      trackValidity: true,
      selection: AssociativeMatchSelection.lowestIndex,
      collision: AssociativeUpdateCollisionPolicy.highestPortWins,
    );
    final dir = await Directory.systemTemp.createTemp('assoc_boundary_');
    try {
      for (final allowUntilReset in [false, true]) {
        await File('${dir.path}/model.h')
            .writeAsString(description.generateSystemC(
          className: 'Cam',
          options: SystemCModelOptions(
            portType: SystemCModelPortType.twoState,
            unknownOutputs: allowUntilReset
                ? SystemCUnknownOutputPolicy.zeroUntilReset
                : SystemCUnknownOutputPolicy.error,
          ),
        ));
        final source = '''
#include "model.h"
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_signal<bool> clk, reset, en, hit, index, full, empty;
  sc_signal<sc_uint<4>> query;
  sc_signal<sc_uint<2>> count, valid;
  Cam dut("dut");
  dut.clk(clk); dut.reset(reset); dut.lookup_en_0(en); dut.lookup_key_0(query);
  dut.lookup_hit_0(hit); dut.lookup_index_0(index);
  dut.valid_count(count); dut.full(full); dut.empty(empty); dut.valid_mask(valid);
  clk=false; reset=false; en=true; query=0;
  try {
    sc_start(1,SC_NS);
    if(!${allowUntilReset ? 'true' : 'false'}) return 1;
    reset=true; sc_start(1,SC_NS); clk=true; sc_start(1,SC_NS);
    clk=false; reset=false; sc_start(1,SC_NS);
    auto image=dut.snapshot();
    image.entries.entries["0"]=sc_lv<5>(SC_LOGIC_X);
    dut.restore(image); sc_start(1,SC_NS);
  } catch(const sc_report& error) {
    return std::string(error.get_msg_type())=="Cam" ? 0 : 2;
  }
  return 3;
}
''';
        await File('${dir.path}/test.cpp').writeAsString(source);
        final compile = await Process.run('g++', [
          '-std=c++17',
          '${dir.path}/test.cpp',
          '-lsystemc',
          '-o',
          '${dir.path}/test'
        ]);
        expect(compile.exitCode, 0,
            reason: '$allowUntilReset\n${compile.stdout}\n${compile.stderr}');
        final run = await Process.run('${dir.path}/test', []);
        expect(run.exitCode, 0,
            reason: '$allowUntilReset\n${run.stdout}\n${run.stderr}');
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('SystemC parallel ports handle scalar and wide values',
      timeout: const Timeout(Duration(minutes: 2)), () async {
    final dir = await Directory.systemTemp.createTemp('assoc_width_');
    try {
      for (final keyWidth in [1, 80]) {
        for (final twoState in [false, true]) {
          final description = BehavioralParallelAssociativeDescription(
            entryCount: 2,
            keyWidth: keyWidth,
            indexWidth: 70,
            updateCount: 1,
            matchVectors: [true],
            sideReadCount: 1,
            trackValidity: false,
            selection: AssociativeMatchSelection.lowestIndex,
            collision: AssociativeUpdateCollisionPolicy.highestPortWins,
          );
          await File('${dir.path}/model.h').writeAsString(
              description.generateSystemC(
                  className: 'Cam',
                  options: SystemCModelOptions(
                      portType: twoState
                          ? SystemCModelPortType.twoState
                          : SystemCModelPortType.fourState,
                      unknownOutputs:
                          SystemCUnknownOutputPolicy.zeroUntilReset)));
          final bit = twoState ? 'bool' : 'sc_logic';
          final idx = twoState ? 'sc_biguint<70>' : 'sc_lv<70>';
          final key = keyWidth == 1
              ? bit
              : twoState
                  ? 'sc_biguint<80>'
                  : 'sc_lv<80>';
          final mask = twoState ? 'sc_uint<2>' : 'sc_lv<2>';
          final one = twoState ? 'true' : 'SC_LOGIC_1';
          final zero = twoState ? 'false' : 'SC_LOGIC_0';
          final keyOne = keyWidth == 1 ? one : '$key(1)';
          final keyZero = keyWidth == 1 ? zero : '$key(0)';
          final sideCheck = keyWidth == 1
              ? 'sideKey.read()!=$one'
              : 'sideKey.read().to_uint64()!=1';
          final source = '''
#include "model.h"
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_signal<$bit> clk, reset, we, wv, qe, hit, sideValid;
  sc_signal<$idx> wi, index, side;
  sc_signal<$key> wk, qk, sideKey;
  sc_signal<$mask> matches;
  Cam dut("dut");
  dut.clk(clk); dut.reset(reset); dut.update_en_0(we); dut.update_index_0(wi);
  dut.update_key_0(wk); dut.update_entryValid_0(wv);
  dut.lookup_en_0(qe); dut.lookup_key_0(qk); dut.lookup_hit_0(hit);
  dut.lookup_index_0(index); dut.lookup_matchVector_0(matches);
  dut.side_read_index(side); dut.side_read_key(sideKey); dut.side_read_valid(sideValid);
  clk=$zero; reset=$one; we=$zero; wi=$idx(1); wk=$keyZero; wv=$one;
  qe=$one; qk=$keyOne; side=$idx(1); sc_start(1,SC_NS);
  auto pulse=[&]() { clk=$one; sc_start(1,SC_NS); clk=$zero; sc_start(1,SC_NS); };
  pulse(); reset=$zero; we=$one; wk=$keyOne; pulse();
  if(hit.read()!=$one || index.read().to_uint64()!=1 ||
     matches.read().to_uint()!=2 || sideValid.read()!=$one || $sideCheck) return 1;
  ${keyWidth == 80 ? '''
  $key high(1); high[79]=1; high[64]=1;
  $idx alias(1); alias[69]=1;
  wi=alias; wk=high; qk=high; side=alias; pulse();
  if(hit.read()!=$zero || sideValid.read()!=$zero ||
     sideKey.read()!=$keyZero) return 2;
  wi=$idx(0); side=$idx(0); pulse();
  if(hit.read()!=$one || index.read()!=$idx(0) ||
     sideValid.read()!=$one || sideKey.read()!=high) return 3;
  qk=$keyOne; we=$zero; sc_start(1,SC_NS);
  if(hit.read()!=$one || index.read()!=$idx(1)) return 4;
  auto saved=dut.snapshot();
  reset=$one; pulse(); reset=$zero; sc_start(1,SC_NS);
  if(hit.read()!=$zero) return 5;
  dut.restore(saved); sc_start(1,SC_NS);
  if(hit.read()!=$one || sideKey.read()!=high) return 6;
  ''' : ''}
  return 0;
}
''';
          await File('${dir.path}/test.cpp').writeAsString(source);
          final compile = await Process.run('g++', [
            '-std=c++17',
            '${dir.path}/test.cpp',
            '-lsystemc',
            '-o',
            '${dir.path}/test'
          ]);
          expect(compile.exitCode, 0,
              reason:
                  '$keyWidth/$twoState\n${compile.stdout}\n${compile.stderr}');
          final run = await Process.run('${dir.path}/test', []);
          expect(run.exitCode, 0,
              reason: '$keyWidth/$twoState\n${run.stdout}\n${run.stderr}');
        }
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
