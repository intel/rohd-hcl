// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory_model_systemc_test.dart
// Tests behavioral SystemC addressed-memory models.
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

Future<void> _compileAndRun(String header, String source) async {
  final directory = await Directory.systemTemp.createTemp('hcl_ram_systemc_');
  try {
    await File('${directory.path}/model.h').writeAsString(header);
    await File('${directory.path}/test.cpp').writeAsString(source);
    final compile = await Process.run('g++', [
      '-std=c++17',
      '-O0',
      '${directory.path}/test.cpp',
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

void main() {
  tearDown(Simulator.reset);

  test('custom storage and two-state exports are rejected', () {
    final read = DataPortInterface<Logic>(8, 3);
    final model = MemoryModel<Logic>(Logic(), Logic(), [], [read]);
    expect(generateBehavioralSystemC(model, 'Ram'), contains('SC_MODULE(Ram)'));
    expect(
        () => model.generateSystemC(
            className: 'Ram',
            options: const SystemCModelOptions(
                portType: SystemCModelPortType.twoState)),
        throwsUnsupportedError);
    final custom = MemoryModel<Logic>(
        Logic(), Logic(), [], [DataPortInterface<Logic>(8, 3)],
        storage: SparseMemoryStorage(addrWidth: 3, dataWidth: 8));
    expect(
        () => custom.generateSystemC(className: 'Ram'), throwsUnsupportedError);
  });

  test('scalar register-file SystemC restores reset and output state',
      timeout: const Timeout(Duration(minutes: 3)), () async {
    final model = MemoryModel<Logic>.registerFile(
      Logic(),
      Logic(),
      [DataPortInterface<Logic>(1, 1)],
      [DataPortInterface<Logic>(1, 1)],
      numEntries: 1,
      resetValues: [LogicValue.one],
    );
    await _compileAndRun(model.generateSystemC(className: 'Ram'), '''
#include "model.h"
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_signal<sc_logic> clk,reset,we,wa,wd,re,ra,rd;
  Ram dut("dut");
  dut.clk(clk); dut.reset(reset); dut.wr_en_0(we); dut.wr_addr_0(wa);
  dut.wr_data_0(wd); dut.rd_en_0(re); dut.rd_addr_0(ra); dut.rd_data_0(rd);
  clk=SC_LOGIC_0; reset=SC_LOGIC_1; we=SC_LOGIC_0; wa=SC_LOGIC_0;
  wd=SC_LOGIC_0; re=SC_LOGIC_1; ra=SC_LOGIC_0; sc_start(1,SC_NS);
  auto pulse=[&]() {
    clk=SC_LOGIC_1; sc_start(1,SC_NS);
    clk=SC_LOGIC_0; sc_start(1,SC_NS);
  };
  pulse();
  if(rd.read()!=SC_LOGIC_1) return 1;
  reset=SC_LOGIC_0; re=SC_LOGIC_0; sc_start(1,SC_NS);
  if(rd.read()!=SC_LOGIC_0) return 2;
  re=SC_LOGIC_1; ra=SC_LOGIC_1; sc_start(1,SC_NS);
  if(rd.read()!=SC_LOGIC_0) return 3;
  ra=SC_LOGIC_0; we=SC_LOGIC_1; sc_start(1,SC_NS); pulse();
  if(rd.read()!=SC_LOGIC_0) return 4;
  auto saved=dut.snapshot();
  wd=SC_LOGIC_1; sc_start(1,SC_NS); pulse();
  if(rd.read()!=SC_LOGIC_1) return 5;
  dut.restore(saved); sc_start(1,SC_NS);
  if(rd.read()!=SC_LOGIC_0 || dut.peek("0")[0]!=SC_LOGIC_0) return 6;
  return 0;
}
''');
  });

  test('register-file SystemC handles four-state masked collisions',
      timeout: const Timeout(Duration(minutes: 3)), () async {
    final model = MemoryModel<Logic>.registerFile(
      Logic(),
      Logic(),
      List.generate(2, (_) => MaskedDataPortInterface<Logic>(16, 2)),
      [DataPortInterface<Logic>(16, 2)],
      numEntries: 2,
      resetValues: [LogicValue.ofInt(0x1234, 16), LogicValue.ofInt(0xabcd, 16)],
    );
    await _compileAndRun(model.generateSystemC(className: 'Ram'), '''
#include "model.h"
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_signal<sc_logic> clk,reset,we[2],re;
  sc_signal<sc_lv<2>> wa[2],mask[2],ra;
  sc_signal<sc_lv<16>> wd[2],rd;
  Ram dut("dut");
  dut.clk(clk); dut.reset(reset);
  dut.wr_en_0(we[0]); dut.wr_addr_0(wa[0]); dut.wr_data_0(wd[0]); dut.wr_mask_0(mask[0]);
  dut.wr_en_1(we[1]); dut.wr_addr_1(wa[1]); dut.wr_data_1(wd[1]); dut.wr_mask_1(mask[1]);
  dut.rd_en_0(re); dut.rd_addr_0(ra); dut.rd_data_0(rd);
  clk=SC_LOGIC_0; reset=SC_LOGIC_1; re=SC_LOGIC_1; ra=0;
  for(int i=0;i<2;++i) { we[i]=SC_LOGIC_0; wa[i]=0; wd[i]=0; mask[i]=0; }
  sc_start(1,SC_NS);
  auto pulse=[&]() {
    clk=SC_LOGIC_1; sc_start(1,SC_NS);
    clk=SC_LOGIC_0; sc_start(1,SC_NS);
  };
  pulse();
  sc_lv<2> uncertain; uncertain[1]=SC_LOGIC_0; uncertain[0]=SC_LOGIC_X;
  reset=SC_LOGIC_0; we[0]=SC_LOGIC_X; wa[0]=uncertain; mask[0]=1; wd[0]=65535;
  we[1]=SC_LOGIC_1; wa[1]=1; mask[1]=0; sc_start(1,SC_NS); pulse();
  if(rd.read()!=sc_lv<16>("00010010XXXXXXXX")) return 1;
  ra=1; sc_start(1,SC_NS);
  if(rd.read()!=sc_lv<16>(0xabcd)) return 2;
  return 0;
}
''');
  });

  test('masked symbolic writes and delayed reads replay in SystemC and Dart',
      timeout: const Timeout(Duration(minutes: 3)), () async {
    final clk = Logic()..put(0);
    final reset = Logic()..put(0);
    final write = MaskedDataPortInterface<Logic>(16, 4)
      ..en.put(1)
      ..addr.put(2)
      ..data.put(0x1234)
      ..mask.put(3);
    final read = DataPortInterface<Logic>(16, 4)
      ..en.put(1)
      ..addr.put(2);
    final model = MemoryModel<Logic>(clk, reset, [write], [read],
        readLatency: 2, asyncReset: false);
    final header = model.generateSystemC(className: 'Ram');
    await model.build();
    late MemoryModelImage image;
    Simulator.registerAction(2, () => clk.put(1));
    Simulator.registerAction(3, () => clk.put(0));
    Simulator.registerAction(4, () {
      image = model.snapshot();
      write
        ..addr.put(LogicValue.ofString('00x0'))
        ..mask.put(1);
    });
    Simulator.registerAction(6, () => clk.put(1));
    Simulator.registerAction(7, () {
      expect(read.data.value, LogicValue.ofInt(0x1234, 16));
      clk.put(0);
      write.en.put(0);
    });
    Simulator.registerAction(9, () => clk.put(1));
    Simulator.registerAction(10, () {
      expect(read.data.value, LogicValue.ofString('00010010xxxxxxxx'));
      clk.put(0);
    });
    Simulator.registerAction(11, () {
      model.restore(image);
      write
        ..en.put(1)
        ..addr.put(LogicValue.ofString('00x0'))
        ..mask.put(1);
    });
    Simulator.registerAction(13, () => clk.put(1));
    Simulator.registerAction(14, () {
      expect(read.data.value, LogicValue.ofInt(0x1234, 16));
      clk.put(0);
      write.en.put(0);
    });
    Simulator.registerAction(16, () => clk.put(1));
    Simulator.registerAction(17, () {
      expect(read.data.value, LogicValue.ofString('00010010xxxxxxxx'));
    });
    await Simulator.run();
    await _compileAndRun(header, r'''
#include "model.h"
#include <iostream>
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_report_handler::set_actions(SC_WARNING,SC_DO_NOTHING);
  sc_signal<sc_logic> clk,reset,we,re;
  sc_signal<sc_lv<4>> wa,ra;
  sc_signal<sc_lv<16>> wd,rd;
  sc_signal<sc_lv<2>> mask;
  Ram dut("dut");
  dut.clk(clk); dut.reset(reset); dut.wr_en_0(we); dut.wr_addr_0(wa);
  dut.wr_data_0(wd); dut.wr_mask_0(mask); dut.rd_en_0(re);
  dut.rd_addr_0(ra); dut.rd_data_0(rd);
  clk=SC_LOGIC_0; reset=SC_LOGIC_0; we=SC_LOGIC_1; re=SC_LOGIC_1;
  wa=sc_lv<4>(2); ra=sc_lv<4>(2); wd=sc_lv<16>(0x1234); mask=sc_lv<2>(3);
  sc_start(1,SC_NS);
  auto pulse=[&]() {
    clk=SC_LOGIC_1; sc_start(1,SC_NS);
    clk=SC_LOGIC_0; sc_start(1,SC_NS);
  };
  pulse();
  auto saved=dut.snapshot();
  for(int replay=0; replay<2; ++replay) {
    if(replay) { dut.restore(saved); sc_start(1,SC_NS); }
    we=SC_LOGIC_1; wa=sc_lv<4>("00X0"); mask=sc_lv<2>(1);
    sc_start(1,SC_NS); pulse();
    if(rd.read()!=sc_lv<16>(0x1234)) {
      std::cerr << "first: " << rd.read() << "\n"; return 1;
    }
    we=SC_LOGIC_0; sc_start(1,SC_NS); pulse();
    if(rd.read()!=sc_lv<16>("00010010XXXXXXXX")) {
      std::cerr << "second: " << rd.read() << "\n"; return 2;
    }
  }
  return 0;
}
''');
  });

  test('scalar combinational reads retain values over asynchronous reset',
      timeout: const Timeout(Duration(minutes: 3)), () async {
    final model = MemoryModel<Logic>(
      Logic(),
      Logic(),
      [DataPortInterface<Logic>(1, 1)],
      [DataPortInterface<Logic>(1, 1)],
      readLatency: 0,
    );
    await _compileAndRun(model.generateSystemC(className: 'Ram'), '''
#include "model.h"
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_report_handler::set_actions(SC_WARNING,SC_DO_NOTHING);
  sc_signal<sc_logic> clk,reset,we,wa,wd,re,ra,rd;
  Ram dut("dut");
  dut.clk(clk); dut.reset(reset); dut.wr_en_0(we); dut.wr_addr_0(wa);
  dut.wr_data_0(wd); dut.rd_en_0(re); dut.rd_addr_0(ra); dut.rd_data_0(rd);
  clk=SC_LOGIC_0; reset=SC_LOGIC_0; we=SC_LOGIC_0; wa=SC_LOGIC_0;
  wd=SC_LOGIC_1; re=SC_LOGIC_0; ra=SC_LOGIC_0; sc_start(1,SC_NS);
  dut.poke("0",Ram::word("1"));
  re=SC_LOGIC_1; sc_start(1,SC_NS);
  if(rd.read()!=SC_LOGIC_1) return 1;
  reset=SC_LOGIC_1; sc_start(1,SC_NS);
  if(rd.read()!=SC_LOGIC_1 || dut.contains("0")) return 2;
  re=SC_LOGIC_0; sc_start(1,SC_NS);
  if(rd.read()!=SC_LOGIC_X) return 3;
  re=SC_LOGIC_1; reset=SC_LOGIC_0; we=SC_LOGIC_1; sc_start(1,SC_NS);
  clk=SC_LOGIC_1; sc_start(1,SC_NS);
  if(rd.read()!=SC_LOGIC_1) return 4;
  return 0;
}
''');
  });

  test('multiport four-state pipeline matches Dart across resets',
      timeout: const Timeout(Duration(minutes: 3)), () async {
    final clk = Logic()..put(0);
    final reset = Logic()..put(0);
    final writes = List.generate(
        2,
        (_) => MaskedDataPortInterface<Logic>(16, 3)
          ..en.put(0)
          ..addr.put(0)
          ..data.put(0)
          ..mask.put(0));
    final reads = List.generate(
        2,
        (_) => DataPortInterface<Logic>(16, 3)
          ..en.put(0)
          ..addr.put(0));
    final model = MemoryModel<Logic>(clk, reset, writes, reads,
        readLatency: 3, asyncReset: false);
    final header = model.generateSystemC(className: 'Ram');
    await model.build();
    final random = Random(765);
    final enables = [LogicValue.zero, LogicValue.one, LogicValue.x];
    final addresses = [
      for (final text in ['000', '001', '010', '011', '0x0', 'z01'])
        LogicValue.ofString(text)
    ];
    final values = [
      for (final text in [
        '0001001000110100',
        '1010101010101010',
        '1010zzzz0000xxxx'
      ])
        LogicValue.ofString(text)
    ];
    final masks = [
      for (final text in ['00', '01', '10', '11', 'x1'])
        LogicValue.ofString(text)
    ];
    final scenarios = List.generate(35, (cycle) {
      final writeInputs = List.generate(
          2,
          (_) => (
                en: enables[random.nextInt(enables.length)],
                addr: addresses[random.nextInt(addresses.length)],
                data: values[random.nextInt(values.length)],
                mask: masks[random.nextInt(masks.length)]
              ));
      final readInputs = List.generate(
          2,
          (_) => (
                en: enables[random.nextInt(enables.length)],
                addr: addresses[random.nextInt(addresses.length)]
              ));
      return (
        reset: cycle == 8 || cycle == 20,
        writes: writeInputs,
        reads: readInputs
      );
    });
    final outputs = <List<LogicValue>>[];
    for (final (cycle, input) in scenarios.indexed) {
      final time = 2 + cycle * 4;
      Simulator.registerAction(time, () {
        reset.put(input.reset ? 1 : 0);
        for (var port = 0; port < 2; port++) {
          writes[port]
            ..en.put(input.writes[port].en)
            ..addr.put(input.writes[port].addr)
            ..data.put(input.writes[port].data)
            ..mask.put(input.writes[port].mask);
          reads[port]
            ..en.put(input.reads[port].en)
            ..addr.put(input.reads[port].addr);
        }
      });
      Simulator.registerAction(time + 1, () => clk.put(1));
      Simulator.registerAction(time + 2, () {
        outputs.add([for (final read in reads) read.data.value]);
      });
      Simulator.registerAction(time + 3, () => clk.put(0));
    }
    await Simulator.run();
    String bits(LogicValue value) =>
        MemoryValueCodec.binary(value).toUpperCase();
    final source = StringBuffer('''
#include "model.h"
#include <iostream>
using namespace sc_core;
using namespace sc_dt;
template<int W> sc_lv<W> lv(const char* bits) {
  sc_lv<W> value;
  for(int i=0;i<W;++i) value[i]=sc_logic(bits[W-i-1]);
  return value;
}
int sc_main(int, char**) {
  sc_report_handler::set_actions(SC_WARNING,SC_DO_NOTHING);
  sc_signal<sc_logic> clk,reset,we[2],re[2];
  sc_signal<sc_lv<3>> wa[2],ra[2];
  sc_signal<sc_lv<16>> wd[2],rd[2];
  sc_signal<sc_lv<2>> mask[2];
  Ram dut("dut"); dut.clk(clk); dut.reset(reset);
''');
    for (var port = 0; port < 2; port++) {
      source.writeln('''
  dut.wr_en_$port(we[$port]); dut.wr_addr_$port(wa[$port]);
  dut.wr_data_$port(wd[$port]); dut.wr_mask_$port(mask[$port]);
  dut.rd_en_$port(re[$port]); dut.rd_addr_$port(ra[$port]); dut.rd_data_$port(rd[$port]);
  we[$port]=SC_LOGIC_0; wa[$port]=sc_lv<3>(0); wd[$port]=sc_lv<16>(0);
  mask[$port]=sc_lv<2>(0); re[$port]=SC_LOGIC_0; ra[$port]=sc_lv<3>(0);
''');
    }
    source.writeln('''
  clk=SC_LOGIC_0; reset=SC_LOGIC_0; sc_start(1,SC_NS);
  auto pulse=[&]() {
    clk=SC_LOGIC_1; sc_start(1,SC_NS);
    clk=SC_LOGIC_0; sc_start(1,SC_NS);
  };
''');
    for (final (cycle, input) in scenarios.indexed) {
      source.writeln('  reset=SC_LOGIC_${input.reset ? '1' : '0'};');
      for (var port = 0; port < 2; port++) {
        final wr = input.writes[port];
        final rd = input.reads[port];
        source.writeln('''
  we[$port]=SC_LOGIC_${bits(wr.en)}; wa[$port]=lv<3>("${bits(wr.addr)}");
  wd[$port]=lv<16>("${bits(wr.data)}"); mask[$port]=lv<2>("${bits(wr.mask)}");
  re[$port]=SC_LOGIC_${bits(rd.en)}; ra[$port]=lv<3>("${bits(rd.addr)}");
''');
      }
      source.writeln('  sc_start(1,SC_NS); pulse();');
      for (var port = 0; port < 2; port++) {
        final sampled = scenarios[max(0, cycle - 2)];
        final details = 'sample reset=${sampled.reset}, '
            'read=${bits(sampled.reads[port].en)}/${bits(sampled.reads[port].addr)}, '
            'w0=${bits(sampled.writes[0].en)}/${bits(sampled.writes[0].addr)}/'
            '${bits(sampled.writes[0].data)}/${bits(sampled.writes[0].mask)}, '
            'w1=${bits(sampled.writes[1].en)}/${bits(sampled.writes[1].addr)}/'
            '${bits(sampled.writes[1].data)}/${bits(sampled.writes[1].mask)}';
        source.writeln('''
  if(rd[$port].read()!=lv<16>("${bits(outputs[cycle][port])}")) {
    std::cerr << "cycle $cycle port $port expected ${bits(outputs[cycle][port])}: "
      << rd[$port].read() << " $details\\n"; return 1;
  }
''');
      }
    }
    source.writeln('  return 0;\n}');
    await _compileAndRun(header, source.toString());
  });
}
