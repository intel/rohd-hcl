// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// associative_software_systemc_test.dart
// Tests compiled SystemC associative software exports.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:io';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

AssociativeMemoryRequest _config({
  AssociativeMatchMode mode = AssociativeMatchMode.exact,
  AssociativeDuplicateKeyPolicy duplicates =
      AssociativeDuplicateKeyPolicy.allow,
}) =>
    AssociativeMemoryRequest(
      keyWidth: 4,
      indexWidth: 2,
      entryCount: 3,
      updatePortCount: 1,
      lookupPortCount: 1,
      lookupLatency: 2,
      updateLatency: 1,
      duplicateKeyPolicy: duplicates,
      matchSelection: AssociativeMatchSelection.lowestIndex,
      resultShape: AssociativeResultShape.matchVectorAndSelectedIndex,
      matchMode: mode,
      lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
      updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
      requiredResetBehavior: AssociativeMemoryResetBehavior.clearValidity,
    );

void main() {
  test('wide masked SystemC keys and full-capacity indices',
      timeout: const Timeout(Duration(minutes: 2)), () async {
    const width = 80;
    final config = AssociativeMemoryRequest(
      keyWidth: width,
      indexWidth: 1,
      entryCount: 2,
      updatePortCount: 1,
      lookupPortCount: 1,
      lookupLatency: 0,
      duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
      matchSelection: AssociativeMatchSelection.highestIndex,
      resultShape: AssociativeResultShape.matchVectorAndSelectedIndex,
      matchMode: AssociativeMatchMode.masked,
      lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
      updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
      requiredResetBehavior: AssociativeMemoryResetBehavior.clearValidity,
    );
    final model = AssociativeSoftwareModel(config);
    final high = LogicValue.ofBigInt((BigInt.one << 79) | BigInt.one, width);
    final low = LogicValue.ofBigInt(BigInt.one, width);
    final all = LogicValue.ofBigInt((BigInt.one << width) - BigInt.one, width);
    final cases = [
      (
        update: AssociativeSoftwareUpdate(
            index: 1, key: high, valid: LogicValue.one),
        query: AssociativeSoftwareLookup(key: high, mask: all)
      ),
      (
        update: AssociativeSoftwareUpdate(
            index: 0, key: low, valid: LogicValue.one),
        query: AssociativeSoftwareLookup(key: low, mask: all)
      ),
      (update: null, query: AssociativeSoftwareLookup(key: low, mask: low)),
      (
        update: AssociativeSoftwareUpdate(
            index: 1, key: high, valid: LogicValue.zero),
        query: AssociativeSoftwareLookup(key: high, mask: all)
      ),
    ];
    final results = [
      for (final item in cases)
        model.step(lookups: [item.query], updates: [item.update]).single!
    ];
    expect(results[0].index, LogicValue.one);
    expect(results[1].index, LogicValue.zero);
    expect(results[2].matchVector, LogicValue.ofInt(3, 2));
    expect(results[2].index, LogicValue.one);
    expect(results[3].hit, LogicValue.zero);

    String binary(LogicValue value) =>
        MemoryValueCodec.binary(value).toUpperCase();
    final cpp = StringBuffer('''
#include "model.h"
#include <iostream>
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_signal<sc_logic> clk, reset, we, wvalid, qe, valid, hit;
  sc_signal<sc_lv<1>> wi, index;
  sc_signal<sc_lv<80>> wk, qk, mask;
  sc_signal<sc_lv<2>> matches;
  Cam cam("cam");
  cam.clk(clk); cam.reset(reset); cam.update_0_en(we);
  cam.update_0_index(wi); cam.update_0_key(wk); cam.update_0_valid(wvalid);
  cam.lookup_0_en(qe); cam.lookup_0_key(qk); cam.lookup_0_mask(mask);
  cam.lookup_0_valid(valid); cam.lookup_0_hit(hit);
  cam.lookup_0_index(index); cam.lookup_0_matches(matches);
  clk=SC_LOGIC_0; reset=SC_LOGIC_1; we=SC_LOGIC_0; wvalid=SC_LOGIC_0;
  qe=SC_LOGIC_0; wi=sc_lv<1>(0); wk=sc_lv<80>(0); qk=sc_lv<80>(0);
  mask=sc_lv<80>(0); sc_start(1,SC_NS);
  auto pulse=[&]() {
    clk=SC_LOGIC_1; sc_start(1,SC_NS);
    clk=SC_LOGIC_0; sc_start(1,SC_NS);
  };
  pulse(); reset=SC_LOGIC_0;
''');
    for (final (step, item) in cases.indexed) {
      final update = item.update;
      final result = results[step];
      cpp.writeln('we=SC_LOGIC_${update == null ? '0' : '1'};');
      if (update != null) {
        cpp.writeln('wi=sc_lv<1>(${update.index}); '
            'wk=sc_lv<80>("${binary(update.key)}"); '
            'wvalid=SC_LOGIC_${binary(update.valid)};');
      }
      cpp
        ..writeln('qe=SC_LOGIC_1; qk=sc_lv<80>("${binary(item.query.key)}"); '
            'mask=sc_lv<80>("${binary(item.query.mask!)}"); pulse();')
        ..writeln('''
  if(valid.read()!=SC_LOGIC_1 ||
     hit.read().to_char()!='${binary(result.hit)}' ||
     index.read().to_string()!="${binary(result.index)}" ||
     matches.read().to_string()!="${binary(result.matchVector)}") {
    std::cerr << "case $step: " << hit.read() << " " << index.read()
              << " " << matches.read() << "\\n"; return 1;
  }
''');
    }
    cpp.writeln('return 0;\n}');
    final dir = await Directory.systemTemp.createTemp('assoc_wide_mask_');
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
      expect(compile.exitCode, 0,
          reason: '${compile.stdout}\n${compile.stderr}');
      final run = await Process.run('${dir.path}/test', []);
      expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('wide SystemC indices reject high-bit aliases and replay state',
      timeout: const Timeout(Duration(minutes: 3)), () async {
    final config = AssociativeMemoryRequest(
      keyWidth: 80,
      indexWidth: 80,
      entryCount: 3,
      updatePortCount: 1,
      lookupPortCount: 1,
      lookupLatency: 0,
      duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
      matchSelection: AssociativeMatchSelection.lowestIndex,
      resultShape: AssociativeResultShape.matchVectorAndSelectedIndex,
      lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
      updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
      requiredResetBehavior: AssociativeMemoryResetBehavior.clearValidity,
    );
    final model = AssociativeSoftwareModel(config);
    final key = LogicValue.ofBigInt((BigInt.one << 75) + BigInt.one, 80);
    final result = model.step(
      updates: [
        AssociativeSoftwareUpdate(index: 1, key: key, valid: LogicValue.one)
      ],
      lookups: [AssociativeSoftwareLookup(key: key)],
    ).single!;
    expect(result.hit, LogicValue.one);
    expect(result.index.toBigInt(), BigInt.one);
    final lowKey = LogicValue.ofBigInt(BigInt.one, 80);
    final distinct = model.step(
      updates: [
        AssociativeSoftwareUpdate(index: 2, key: lowKey, valid: LogicValue.one)
      ],
      lookups: [AssociativeSoftwareLookup(key: lowKey)],
    ).single!;
    expect(distinct.hit, LogicValue.one);
    expect(distinct.index.toBigInt(), BigInt.two);
    final directory =
        await Directory.systemTemp.createTemp('hcl_assoc_wide_systemc_');
    try {
      await File('${directory.path}/model.h')
          .writeAsString(model.generateSystemC(className: 'Cam'));
      await File('${directory.path}/test.cpp').writeAsString('''
#include "model.h"
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_signal<sc_logic> clk, reset, wen, wvalid, qen, valid, hit;
  sc_signal<sc_lv<80>> windex, index, wkey, qkey;
  sc_signal<sc_lv<3>> matches;
  Cam cam("cam");
  cam.clk(clk); cam.reset(reset); cam.update_0_en(wen);
  cam.update_0_index(windex); cam.update_0_key(wkey); cam.update_0_valid(wvalid);
  cam.lookup_0_en(qen); cam.lookup_0_key(qkey);
  cam.lookup_0_valid(valid); cam.lookup_0_hit(hit);
  cam.lookup_0_index(index); cam.lookup_0_matches(matches);
  sc_report_handler::set_actions("ASSOCIATIVE_UPDATE", SC_DO_NOTHING);
  clk=SC_LOGIC_0; reset=SC_LOGIC_0; wen=SC_LOGIC_1; wvalid=SC_LOGIC_1;
  qen=SC_LOGIC_1;
  sc_lv<80> high(0); high[75]=SC_LOGIC_1; high[0]=SC_LOGIC_1;
  windex=high; wkey=high; qkey=high; sc_start(1,SC_NS);
  auto pulse=[&]() {
    clk=SC_LOGIC_1; sc_start(1,SC_NS);
    clk=SC_LOGIC_0; sc_start(1,SC_NS);
  };
  pulse();
  if(sc_report_handler::get_count(SC_ERROR)!=1) return 1;
  windex=sc_lv<80>(1); sc_start(1,SC_NS); pulse();
  if(valid.read()!=SC_LOGIC_1 || hit.read()!=SC_LOGIC_1 ||
     index.read()!=sc_lv<80>(1) || matches.read()!=sc_lv<3>(2)) return 2;
  windex=sc_lv<80>(2); wkey=sc_lv<80>(1); qkey=sc_lv<80>(1);
  sc_start(1,SC_NS); pulse();
  if(hit.read()!=SC_LOGIC_1 || index.read()!=sc_lv<80>(2) ||
     matches.read()!=sc_lv<3>(4)) return 5;
  qkey=high; wen=SC_LOGIC_0; sc_start(1,SC_NS); pulse();
  if(hit.read()!=SC_LOGIC_1 || index.read()!=sc_lv<80>(1)) return 6;
  auto saved=cam.snapshot();
  reset=SC_LOGIC_1; sc_start(1,SC_NS); pulse();
  reset=SC_LOGIC_0; wen=SC_LOGIC_0; sc_start(1,SC_NS); pulse();
  if(hit.read()!=SC_LOGIC_0) return 3;
  cam.restore(saved); sc_start(1,SC_NS); pulse();
  if(hit.read()!=SC_LOGIC_1 || index.read()!=sc_lv<80>(1)) return 4;
  return 0;
}
''');
      final compile = await Process.run('g++', [
        '-std=c++17',
        '-O0',
        '${directory.path}/test.cpp',
        '-lsystemc',
        '-o',
        '${directory.path}/test',
      ]);
      expect(compile.exitCode, 0,
          reason: '${compile.stdout}\n${compile.stderr}');
      final run = await Process.run('${directory.path}/test', []);
      expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('unsupported exports fail explicitly', () {
    final duplicate = AssociativeSoftwareModel(
        _config(duplicates: AssociativeDuplicateKeyPolicy.disallow));
    expect(() => duplicate.generateSystemC(className: 'Cam'),
        throwsUnsupportedError);
    final model = AssociativeSoftwareModel(_config());
    expect(
        () => model.generateSystemC(
            className: 'Cam',
            options: const SystemCModelOptions(
                portType: SystemCModelPortType.twoState)),
        throwsUnsupportedError);
    expect(() => model.generateSystemC(className: 'bad-name'),
        throwsArgumentError);
    expect(generateBehavioralSystemC(model, 'Cam'), contains('SC_MODULE(Cam)'));
  });

  test('compiled SystemC replays in-flight four-state transactions',
      timeout: const Timeout(Duration(minutes: 3)), () async {
    final model = AssociativeSoftwareModel(_config());
    final query = AssociativeSoftwareLookup(key: LogicValue.ofString('10x0'));
    model.step(lookups: [
      query
    ], updates: [
      AssociativeSoftwareUpdate(index: 1, key: query.key, valid: LogicValue.one)
    ]);
    final image = model.snapshotExecution();
    model.step(lookups: [query], updates: [null]);
    final first = model.step(lookups: [null], updates: [null]).single!;
    final second = model.step(lookups: [null], updates: [null]).single!;
    model
      ..restoreExecution(image)
      ..step(lookups: [query], updates: [null]);
    expect(model.step(lookups: [null], updates: [null]).single, first);
    expect(model.step(lookups: [null], updates: [null]).single, second);

    String binary(LogicValue value) =>
        MemoryValueCodec.binary(value).toUpperCase();
    final source = '''
#include "model.h"
#include <iostream>
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_signal<sc_logic> clk, reset, wen, wvalid, qen, valid, hit;
  sc_signal<sc_lv<2>> windex, index;
  sc_signal<sc_lv<4>> wkey, qkey;
  sc_signal<sc_lv<3>> matches;
  Cam cam("cam");
  cam.clk(clk); cam.reset(reset); cam.update_0_en(wen);
  cam.update_0_index(windex); cam.update_0_key(wkey); cam.update_0_valid(wvalid);
  cam.lookup_0_en(qen); cam.lookup_0_key(qkey);
  cam.lookup_0_valid(valid); cam.lookup_0_hit(hit);
  cam.lookup_0_index(index); cam.lookup_0_matches(matches);
  clk=SC_LOGIC_0; reset=SC_LOGIC_0; wen=SC_LOGIC_1; windex=sc_lv<2>(1);
  wkey=sc_lv<4>("10X0"); wvalid=SC_LOGIC_1; qen=SC_LOGIC_1; qkey=sc_lv<4>("10X0");
  sc_start(1,SC_NS);
  auto pulse=[&]() {
    clk=SC_LOGIC_1; sc_start(1,SC_NS);
    clk=SC_LOGIC_0; sc_start(1,SC_NS);
  };
  auto check=[&](char h, const char* i, const char* m) {
    if(valid.read()!=SC_LOGIC_1 || hit.read().to_char()!=h ||
       index.read().to_string()!=i || matches.read().to_string()!=m) {
      std::cerr << "unexpected output " << valid.read() << " " << hit.read()
                << " " << index.read() << " " << matches.read() << "\\n";
      return false;
    }
    return true;
  };
  pulse();
  auto saved=cam.snapshot();
  for(int replay=0; replay<2; ++replay) {
    if(replay) { cam.restore(saved); sc_start(1,SC_NS); }
    wen=SC_LOGIC_0; qen=SC_LOGIC_1; pulse();
    qen=SC_LOGIC_0; pulse();
    if(!check('${binary(first.hit)}', "${binary(first.index)}", "${binary(first.matchVector)}")) return 1;
    pulse();
    if(!check('${binary(second.hit)}', "${binary(second.index)}", "${binary(second.matchVector)}")) return 2;
  }
  return 0;
}
''';
    final directory =
        await Directory.systemTemp.createTemp('hcl_assoc_systemc_');
    try {
      await File('${directory.path}/model.h')
          .writeAsString(model.generateSystemC(className: 'Cam'));
      await File('${directory.path}/test.cpp').writeAsString(source);
      final compile = await Process.run('g++', [
        '-std=c++17',
        '-O0',
        '${directory.path}/test.cpp',
        '-lsystemc',
        '-o',
        '${directory.path}/test'
      ]);
      expect(compile.exitCode, 0,
          reason: '${compile.stdout}\n${compile.stderr}');
      final run = await Process.run('${directory.path}/test', []);
      expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('compiled masked multiport SystemC matches the software model',
      timeout: const Timeout(Duration(minutes: 3)), () async {
    final config = AssociativeMemoryRequest(
      keyWidth: 4,
      indexWidth: 2,
      entryCount: 3,
      updatePortCount: 2,
      lookupPortCount: 2,
      lookupLatency: 1,
      updateLatency: 2,
      duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
      matchSelection: AssociativeMatchSelection.highestIndex,
      resultShape: AssociativeResultShape.matchVectorAndSelectedIndex,
      matchMode: AssociativeMatchMode.masked,
      lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupBeforeUpdate,
      updateCollisionPolicy: AssociativeUpdateCollisionPolicy.lowestPortWins,
      requiredResetBehavior: AssociativeMemoryResetBehavior.clearValidity,
    );
    final model = AssociativeSoftwareModel(config);
    final random = Random(87);
    final values = [
      for (final text in ['0000', '1010', '10x0', '1z01', 'xxxx'])
        LogicValue.ofString(text)
    ];
    String binary(LogicValue value) =>
        MemoryValueCodec.binary(value).toUpperCase();
    final source = StringBuffer('''
#include "model.h"
#include <iostream>
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_signal<sc_logic> clk, reset;
  sc_signal<sc_logic> wen[2], wvalid[2], qen[2], valid[2], hit[2];
  sc_signal<sc_lv<2>> windex[2], index[2];
  sc_signal<sc_lv<4>> wkey[2], qkey[2], mask[2];
  sc_signal<sc_lv<3>> matches[2];
  Cam cam("cam"); cam.clk(clk); cam.reset(reset);
''');
    for (var i = 0; i < 2; i++) {
      source.writeln('''
  cam.update_${i}_en(wen[$i]); cam.update_${i}_index(windex[$i]);
  cam.update_${i}_key(wkey[$i]); cam.update_${i}_valid(wvalid[$i]);
  cam.lookup_${i}_en(qen[$i]); cam.lookup_${i}_key(qkey[$i]);
  cam.lookup_${i}_mask(mask[$i]); cam.lookup_${i}_valid(valid[$i]);
  cam.lookup_${i}_hit(hit[$i]); cam.lookup_${i}_index(index[$i]);
  cam.lookup_${i}_matches(matches[$i]);
  wen[$i]=SC_LOGIC_0; windex[$i]=sc_lv<2>(0); wkey[$i]=sc_lv<4>(0);
  wvalid[$i]=SC_LOGIC_0; qen[$i]=SC_LOGIC_0; qkey[$i]=sc_lv<4>(0);
  mask[$i]=sc_lv<4>(0);
''');
    }
    source.writeln('''
  clk=SC_LOGIC_0; reset=SC_LOGIC_1; sc_start(1,SC_NS);
  auto pulse=[&]() {
    clk=SC_LOGIC_1; sc_start(1,SC_NS);
    clk=SC_LOGIC_0; sc_start(1,SC_NS);
  };
  pulse(); reset=SC_LOGIC_0; sc_start(1,SC_NS);
''');
    for (var cycle = 0; cycle < 40; cycle++) {
      final updates = List<AssociativeSoftwareUpdate?>.generate(2, (_) {
        if (random.nextBool()) {
          return null;
        }
        return AssociativeSoftwareUpdate(
            index: random.nextInt(3),
            key: values[random.nextInt(values.length)],
            valid: [
              LogicValue.zero,
              LogicValue.one,
              LogicValue.x
            ][random.nextInt(3)]);
      });
      final queries = List<AssociativeSoftwareLookup?>.generate(2, (_) {
        if (random.nextBool()) {
          return null;
        }
        return AssociativeSoftwareLookup(
            key: values[random.nextInt(values.length)],
            mask: values[random.nextInt(values.length)]);
      });
      final expected = model.step(lookups: queries, updates: updates);
      for (var port = 0; port < 2; port++) {
        final update = updates[port];
        source.writeln('  wen[$port]=SC_LOGIC_${update == null ? '0' : '1'};');
        if (update != null) {
          source.writeln('''
  windex[$port]=sc_lv<2>(${update.index});
  wkey[$port]=sc_lv<4>("${binary(update.key)}");
  wvalid[$port]=SC_LOGIC_${binary(update.valid)};
''');
        }
        final query = queries[port];
        source.writeln('  qen[$port]=SC_LOGIC_${query == null ? '0' : '1'};');
        if (query != null) {
          source.writeln('''
  qkey[$port]=sc_lv<4>("${binary(query.key)}");
  mask[$port]=sc_lv<4>("${binary(query.mask!)}");
''');
        }
      }
      source.writeln('  pulse();');
      for (var port = 0; port < 2; port++) {
        final result = expected[port];
        final conditions = result == null
            ? 'valid[$port].read()!=SC_LOGIC_0'
            : 'valid[$port].read()!=SC_LOGIC_1 || '
                "hit[$port].read().to_char()!='${binary(result.hit)}' || "
                'index[$port].read().to_string()!="${binary(result.index)}" || '
                'matches[$port].read().to_string()!='
                '"${binary(result.matchVector)}"';
        source.writeln('''
  if($conditions) {
    std::cerr << "cycle $cycle port $port: " << valid[$port].read() << " "
      << hit[$port].read() << " " << index[$port].read() << " "
      << matches[$port].read() << "\\n"; return 1;
  }
''');
      }
    }
    source.writeln('''
  wen[0]=SC_LOGIC_X; wen[1]=SC_LOGIC_0;
  try { pulse(); }
  catch(const sc_report& error) {
    return std::string(error.get_msg_type())=="ASSOCIATIVE_UPDATE" ? 0 : 2;
  }
  return 3;
}
''');
    final directory =
        await Directory.systemTemp.createTemp('hcl_assoc_matrix_');
    try {
      await File('${directory.path}/model.h')
          .writeAsString(model.generateSystemC(className: 'Cam'));
      await File('${directory.path}/test.cpp').writeAsString(source.toString());
      final compile = await Process.run('g++', [
        '-std=c++17',
        '-O0',
        '${directory.path}/test.cpp',
        '-lsystemc',
        '-o',
        '${directory.path}/test'
      ]);
      expect(compile.exitCode, 0,
          reason: '${compile.stdout}\n${compile.stderr}');
      final run = await Process.run('${directory.path}/test', []);
      expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
