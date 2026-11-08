// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory_model_miter_test.dart
// Cross-simulator tests for addressed memories.
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

typedef _Write = ({bool enable, int address, int data, int mask});
typedef _Step = ({
  bool reset,
  bool check,
  List<_Write> writes,
  List<int> reads,
  List<bool> readEnabled,
});

_Write _write(int address, int data, int mask, {bool enable = true}) =>
    (enable: enable, address: address, data: data, mask: mask);

List<_Step> _stimulus() {
  final steps = <_Step>[];
  void initialize({bool first = false}) {
    steps
      ..add((
        reset: true,
        check: !first,
        writes: [
          _write(0, 0, 0, enable: false),
          _write(1, 0, 0, enable: false)
        ],
        reads: [0, 1],
        readEnabled: [true, true],
      ))
      ..add((
        reset: false,
        check: true,
        writes: [
          _write(0, 0, 0, enable: false),
          _write(1, 0, 0, enable: false)
        ],
        reads: [0, 1],
        readEnabled: [true, true],
      ));
    for (var address = 0; address < 3; address++) {
      steps.add((
        reset: false,
        check: true,
        writes: [
          _write(address, 0x1200 + address, 3),
          _write(address + 3, 0xa000 + address, 3)
        ],
        reads: [0, 1],
        readEnabled: [true, false],
      ));
    }
  }

  initialize(first: true);
  // Both full-word writes target the same address; the later port wins.
  steps
    ..add((
      reset: false,
      check: true,
      writes: [_write(2, 0x1234, 3), _write(2, 0xabcd, 3)],
      reads: [2, 2],
      readEnabled: [true, true],
    ))
    ..add((
      reset: false,
      check: true,
      writes: [_write(2, 0x00ef, 1), _write(4, 0x5600, 2)],
      reads: [2, 4],
      readEnabled: [true, true],
    ));
  final random = Random(1977);
  for (var cycle = 0; cycle < 100; cycle++) {
    if (cycle == 50) {
      initialize();
    }
    final address0 = random.nextInt(8);
    final address1 = random.nextInt(8);
    steps.add((
      reset: false,
      check: true,
      writes: [
        _write(address0, random.nextInt(65536), random.nextInt(4),
            enable: random.nextBool()),
        _write(address1, random.nextInt(65536), random.nextInt(4),
            enable: random.nextBool())
      ],
      reads: [random.nextInt(8), random.nextInt(8)],
      readEnabled: [random.nextBool(), random.nextBool()],
    ));
  }
  steps
    ..add((
      reset: false,
      check: true,
      writes: [_write(2, 0xabcd, 3), _write(3, 0, 0, enable: false)],
      reads: [2, 2],
      readEnabled: [true, true],
    ))
    ..add((
      reset: false,
      check: true,
      writes: [_write(2, 0x5600, 2), _write(2, 0x00ef, 1)],
      reads: [2, 2],
      readEnabled: [true, true],
    ));
  return steps;
}

Future<ProcessResult> _run(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  expect(result.exitCode, 0,
      reason: '$executable failed:\n${result.stdout}\n${result.stderr}');
  return result;
}

List<String> _trace(String output) => output
    .split('\n')
    .where((line) => line.startsWith('M '))
    .map((line) => line.trim())
    .toList();

void main() {
  tearDown(Simulator.reset);

  final missing = [
    for (final tool in ['iverilog', 'vvp', 'g++'])
      if (Process.runSync('which', [tool]).exitCode != 0) tool
  ];
  test('two-state Dart, Verilog and SystemC register-file miter',
      timeout: const Timeout(Duration(minutes: 3)),
      skip: missing.isEmpty ? null : 'Missing tools: ${missing.join(', ')}',
      () async {
    final steps = _stimulus();
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
    final resetValues = List.generate(6, (i) => 0x9000 + i);
    final software = MemoryModel<Logic>.registerFile(clk, reset, writes, reads,
        numEntries: 6,
        resetValues: [
          for (final value in resetValues) LogicValue.ofInt(value, 16)
        ]);
    final systemC = software.generateSystemC(className: 'BehavioralRam');
    await software.build();

    final rtl = RegisterFile<Logic>(
      Logic(),
      Logic(),
      List.generate(2, (_) => MaskedDataPortInterface<Logic>(16, 3)),
      List.generate(2, (_) => DataPortInterface<Logic>(16, 3)),
      numEntries: 6,
      resetValue: resetValues,
    );
    await rtl.build();

    final dartTrace = <String>[];
    void capture(int cycle, String phase) {
      for (final read in reads) {
        expect(read.data.value.isValid, isTrue,
            reason: 'Dart output is unknown at cycle $cycle $phase');
      }
      dartTrace.add('M $cycle $phase '
          '${reads[0].data.value.toInt()} ${reads[1].data.value.toInt()}');
    }

    for (final (cycle, step) in steps.indexed) {
      final time = 2 + cycle * 6;
      Simulator.registerAction(time, () {
        reset.put(step.reset ? 1 : 0);
        for (var port = 0; port < 2; port++) {
          final write = step.writes[port];
          writes[port]
            ..en.put(write.enable ? 1 : 0)
            ..addr.put(write.address)
            ..data.put(write.data)
            ..mask.put(write.mask);
          reads[port]
            ..en.put(step.readEnabled[port] ? 1 : 0)
            ..addr.put(step.reads[port]);
        }
      });
      if (step.check) {
        Simulator.registerAction(time + 1, () => capture(cycle, 'before'));
      }
      Simulator.registerAction(time + 2, () => clk.put(1));
      if (step.check) {
        Simulator.registerAction(time + 3, () => capture(cycle, 'after'));
      }
      Simulator.registerAction(time + 4, () => clk.put(0));
    }
    await Simulator.run();
    expect(dartTrace.length, steps.where((step) => step.check).length * 2);

    final verilog = StringBuffer('''
module tb;
  reg clk, reset;
  reg we0, we1, re0, re1;
  reg [2:0] wa0, wa1, ra0, ra1;
  reg [15:0] wd0, wd1;
  reg [1:0] mask0, mask1;
  wire [15:0] rd0, rd1;
  ${rtl.definitionName} dut(
    .clk(clk), .reset(reset),
    .wr_en_0(we0), .wr_addr_0(wa0), .wr_data_0(wd0), .wr_mask_0(mask0),
    .wr_en_1(we1), .wr_addr_1(wa1), .wr_data_1(wd1), .wr_mask_1(mask1),
    .rd_en_0(re0), .rd_addr_0(ra0), .rd_data_0(rd0),
    .rd_en_1(re1), .rd_addr_1(ra1), .rd_data_1(rd1)
  );
  initial begin
    clk=0; reset=0; we0=0; we1=0; re0=0; re1=0;
    wa0=0; wa1=0; ra0=0; ra1=0; wd0=0; wd1=0; mask0=0; mask1=0;
''');
    final cpp = StringBuffer(r'''
#include "model.h"
#include <iostream>
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_report_handler::set_actions(SC_WARNING,SC_DO_NOTHING);
  sc_signal<sc_logic> clk, reset, we[2], re[2];
  sc_signal<sc_lv<3>> wa[2], ra[2];
  sc_signal<sc_lv<16>> wd[2], rd[2];
  sc_signal<sc_lv<2>> mask[2];
  BehavioralRam dut("dut");
  dut.clk(clk); dut.reset(reset);
  dut.wr_en_0(we[0]); dut.wr_addr_0(wa[0]); dut.wr_data_0(wd[0]); dut.wr_mask_0(mask[0]);
  dut.wr_en_1(we[1]); dut.wr_addr_1(wa[1]); dut.wr_data_1(wd[1]); dut.wr_mask_1(mask[1]);
  dut.rd_en_0(re[0]); dut.rd_addr_0(ra[0]); dut.rd_data_0(rd[0]);
  dut.rd_en_1(re[1]); dut.rd_addr_1(ra[1]); dut.rd_data_1(rd[1]);
  clk=SC_LOGIC_0; reset=SC_LOGIC_0;
  for(int i=0;i<2;++i) {
    we[i]=SC_LOGIC_0; re[i]=SC_LOGIC_0; wa[i]=0; ra[i]=0; wd[i]=0; mask[i]=0;
  }
  sc_start(1,SC_NS);
  auto capture=[&](int cycle, const char* phase) {
    if(!rd[0].read().is_01() || !rd[1].read().is_01()) {
      std::cerr << "SystemC unknown at cycle " << cycle << " " << phase << "\n";
      return false;
    }
    std::cout << "M " << cycle << " " << phase << " "
              << rd[0].read().to_uint() << " " << rd[1].read().to_uint() << "\n";
    return true;
  };
''');
    for (final (cycle, step) in steps.indexed) {
      verilog.writeln('    reset=${step.reset ? 1 : 0};');
      cpp.writeln('  reset=SC_LOGIC_${step.reset ? 1 : 0};');
      for (var port = 0; port < 2; port++) {
        final write = step.writes[port];
        verilog.writeln('    we$port=${write.enable ? 1 : 0}; '
            'wa$port=${write.address}; wd$port=${write.data}; '
            'mask$port=${write.mask}; '
            're$port=${step.readEnabled[port] ? 1 : 0}; '
            'ra$port=${step.reads[port]};');
        cpp.writeln('  we[$port]=SC_LOGIC_${write.enable ? 1 : 0}; '
            'wa[$port]=${write.address}; wd[$port]=${write.data}; '
            'mask[$port]=${write.mask}; '
            're[$port]=SC_LOGIC_${step.readEnabled[port] ? 1 : 0}; '
            'ra[$port]=${step.reads[port]};');
      }
      verilog.writeln('    #1;');
      cpp.writeln('  sc_start(1,SC_NS);');
      if (step.check) {
        verilog.writeln('    \$display("M $cycle before %0d %0d",rd0,rd1);');
        cpp.writeln('  if(!capture($cycle,"before")) return 1;');
      }
      verilog.writeln('    #1 clk=1; #1;');
      cpp.writeln('  clk=SC_LOGIC_1; sc_start(1,SC_NS);');
      if (step.check) {
        verilog.writeln('    \$display("M $cycle after %0d %0d",rd0,rd1);');
        cpp.writeln('  if(!capture($cycle,"after")) return 1;');
      }
      verilog.writeln('    #1 clk=0; #1;');
      cpp.writeln('  clk=SC_LOGIC_0; sc_start(1,SC_NS);');
    }
    verilog.writeln('    \$finish;\n  end\nendmodule');
    cpp.writeln('  return 0;\n}');

    final directory = await Directory.systemTemp.createTemp('hcl_ram_miter_');
    try {
      await File('${directory.path}/dut.sv')
          .writeAsString(rtl.dumpSystemVerilog());
      await File('${directory.path}/tb.sv').writeAsString(verilog.toString());
      await File('${directory.path}/model.h').writeAsString(systemC);
      await File('${directory.path}/test.cpp').writeAsString(cpp.toString());
      await _run('iverilog', [
        '-g2012',
        '-o',
        '${directory.path}/sim',
        '${directory.path}/tb.sv',
        '${directory.path}/dut.sv'
      ]);
      await _run('g++', [
        '-std=c++17',
        '-O0',
        '${directory.path}/test.cpp',
        '-lsystemc',
        '-o',
        '${directory.path}/test'
      ]);
      final verilogRun = await _run('vvp', ['-n', '${directory.path}/sim']);
      final systemCRun = await _run('${directory.path}/test', []);
      expect(_trace(systemCRun.stdout as String), dartTrace,
          reason: 'SystemC memory differs from Dart memory');
      final collisionCycle = steps.length - 1;
      expect(dartTrace.last, 'M $collisionCycle after 44015 44015');
      expect(_trace(verilogRun.stdout as String), dartTrace,
          reason: 'Verilog register file differs from its behavioral model');
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
