// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// associative_four_state_miter_test.dart
// Four-state associative matching across Dart, Verilog, and SystemC.
//
// 2026 November 8
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Harness extends Module {
  _Harness(AssociativeMatchSelection selection) {
    final update = AssociativeUpdatePortInterface(keyWidth: 4, indexWidth: 2);
    final lookup = AssociativeLookupPortInterface(
        keyWidth: 4, indexWidth: 2, matchEntryCount: 3);
    update.en <= addInput('we', Logic());
    update.index <= addInput('wa', Logic(width: 2), width: 2);
    update.key <= addInput('wd', Logic(width: 4), width: 4);
    update.entryValid <= Const(1);
    lookup.en <= Const(1);
    lookup.key <= addInput('query', Logic(width: 4), width: 4);
    ParallelAssociativeMemory(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      updates: [update],
      lookups: [lookup],
      entryCount: 3,
      contract: AssociativeMemoryContract(
        lookupLatency: 0,
        updateLatency: 0,
        duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
        matchSelection: selection,
        resultShape: AssociativeResultShape.matchVectorAndSelectedIndex,
        lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
        updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
        resetBehavior: AssociativeMemoryResetBehavior.clearValidity,
        implementationKind: AssociativeMemoryImplementationKind.synthesizable,
      ),
    );
    addOutput('hit') <= lookup.hit;
    addOutput('index', width: 2) <= lookup.index;
    addOutput('matchBits', width: 3) <= lookup.matchVector!;
  }
}

AssociativeMemoryRequest _config(AssociativeMatchSelection selection) =>
    AssociativeMemoryRequest(
      keyWidth: 4,
      indexWidth: 2,
      entryCount: 3,
      updatePortCount: 1,
      lookupPortCount: 1,
      lookupLatency: 0,
      duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
      matchSelection: selection,
      resultShape: AssociativeResultShape.matchVectorAndSelectedIndex,
      lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
      updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
      requiredResetBehavior: AssociativeMemoryResetBehavior.clearValidity,
    );

String _bits(LogicValue value) => MemoryValueCodec.binary(value).toUpperCase();

Future<void> _checkSystemC(
  AssociativeSoftwareModel model,
  List<LogicValue> keys,
  List<LogicValue> queries,
  List<AssociativeSoftwareResult> results,
) async {
  final dir = await Directory.systemTemp.createTemp('associative_miter_');
  try {
    await File('${dir.path}/model.h')
        .writeAsString(model.generateSystemC(className: 'Cam'));
    final source = StringBuffer('''
#include "model.h"
#include <iostream>
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_signal<sc_logic> clk, reset, we, wvalid, qe, valid, hit;
  sc_signal<sc_lv<2>> wa, index;
  sc_signal<sc_lv<4>> wd, query;
  sc_signal<sc_lv<3>> matches;
  Cam cam("cam");
  cam.clk(clk); cam.reset(reset); cam.update_0_en(we);
  cam.update_0_index(wa); cam.update_0_key(wd); cam.update_0_valid(wvalid);
  cam.lookup_0_en(qe); cam.lookup_0_key(query);
  cam.lookup_0_valid(valid); cam.lookup_0_hit(hit);
  cam.lookup_0_index(index); cam.lookup_0_matches(matches);
  clk=SC_LOGIC_0; reset=SC_LOGIC_1; we=SC_LOGIC_0; wvalid=SC_LOGIC_1;
  qe=SC_LOGIC_0; wa=sc_lv<2>(0); wd=sc_lv<4>(0); query=sc_lv<4>(0);
  sc_start(1,SC_NS);
  auto pulse=[&]() {
    clk=SC_LOGIC_1; sc_start(1,SC_NS);
    clk=SC_LOGIC_0; sc_start(1,SC_NS);
  };
  pulse(); reset=SC_LOGIC_0;
''');
    for (final (index, key) in keys.indexed) {
      source.writeln('we=SC_LOGIC_1; wa=sc_lv<2>($index); '
          'wd=sc_lv<4>("${_bits(key)}"); pulse();');
    }
    source.writeln('we=SC_LOGIC_0; qe=SC_LOGIC_1;');
    for (final (step, query) in queries.indexed) {
      final result = results[step];
      source.writeln('''
  query=sc_lv<4>("${_bits(query)}"); pulse();
  if(valid.read()!=SC_LOGIC_1 ||
     hit.read().to_char()!='${_bits(result.hit)}' ||
     index.read().to_string()!="${_bits(result.index)}" ||
     matches.read().to_string()!="${_bits(result.matchVector)}") {
    std::cerr << "query $step: " << hit.read() << " " << index.read()
              << " " << matches.read() << "\\n"; return 1;
  }
''');
    }
    source.writeln('return 0;\n}');
    await File('${dir.path}/test.cpp').writeAsString(source.toString());
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

  for (final selection in AssociativeMatchSelection.values) {
    test('four-state associative keys match RTL and SystemC: $selection',
        timeout: const Timeout(Duration(minutes: 2)), () async {
      final model = AssociativeSoftwareModel(_config(selection));
      final keys = ['0000', '1x10', '10z1'].map(LogicValue.ofString).toList();
      final queries = [
        '0000',
        '1x00',
        '10x0',
        '1x10',
        '10x1',
        '1z11',
        '1111',
        'xxxx',
      ].map(LogicValue.ofString).toList();
      for (final (index, key) in keys.indexed) {
        model.step(lookups: [
          null
        ], updates: [
          AssociativeSoftwareUpdate(
              index: index, key: key, valid: LogicValue.one)
        ]);
      }
      final results = [
        for (final query in queries)
          model.step(
              lookups: [AssociativeSoftwareLookup(key: query)],
              updates: [null]).single!
      ];
      expect(results[1].hit, LogicValue.zero);
      expect(results[2].hit, LogicValue.x);

      final vectors = <Vector>[
        Vector(
            {'clk': 0, 'reset': 1, 'we': 0, 'wa': 0, 'wd': 0, 'query': 0}, {}),
        Vector({'clk': 1}, {}),
        for (final (index, key) in keys.indexed) ...[
          Vector({'clk': 0, 'reset': 0, 'we': 1, 'wa': index, 'wd': key}, {}),
          Vector({'clk': 1}, {}),
        ],
        for (final (step, query) in queries.indexed)
          Vector({
            'clk': 0,
            'we': 0,
            'query': query
          }, {
            'hit': results[step].hit,
            'index': results[step].index,
            'matchBits': results[step].matchVector,
          }),
      ];
      final dut = _Harness(selection);
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
      await _checkSystemC(model, keys, queries, results);
    });
  }
}
