// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_software_model_systemc_test.dart
// Tests for CSR software model SystemC export.
//
// 2026 October 16
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

import 'csr_software_model_test.dart' show csrSoftwareTestConfig;

class _PortableFallbackField extends CsrFieldConfig {
  final List<int> fallback = [1];

  _PortableFallbackField()
      : super(
            name: 'legal',
            start: 0,
            width: 4,
            access: CsrFieldAccess.readWriteLegal,
            legalValues: [0, 1]);

  @override
  int transformIllegalValue() => fallback.single;
}

// Compiling and linking against SystemC can exceed the default 30s timeout
// when the full suite runs in parallel.
const _compileTimeout = Timeout(Duration(minutes: 3));

class _CsrParent extends Module {
  late final CsrTop csr;

  _CsrParent(CsrImplementation implementation, {bool asyncReset = false}) {
    final read = DataPortInterface<Logic>(8, 2);
    final write = DataPortInterface<Logic>(8, 2);
    read.en <= addInput('re', Logic());
    read.addr <= addInput('ra', Logic(width: 2), width: 2);
    write.en <= addInput('we', Logic());
    write.addr <= addInput('wa', Logic(width: 2), width: 2);
    write.data <= addInput('wd', Logic(width: 8), width: 8);
    csr = CsrTop(
      config: CsrTopConfig(
          name: 'csr',
          blockSize: 4,
          asyncReset: asyncReset,
          blocks: [
            CsrBlockConfig(name: 'b', baseAddr: 0, registers: [
              CsrInstanceConfig(
                arch: CsrConfig(
                    name: 'r', access: CsrAccess.readWrite, fields: const []),
                addr: 0,
                width: 8,
              )
            ])
          ]),
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      frontRead: read,
      frontWrite: write,
      implementationConfiguration:
          CsrImplementationConfiguration(implementation: implementation),
    );
    final backdoor = csr.getBackdoorPortsByName('b', 'r');
    backdoor.wrEn! <= addInput('hwe', Logic());
    backdoor.wrData! <= addInput('hwd', Logic(width: 8), width: 8);
    addOutput('rd', width: 8) <= read.data;
    addOutput('hardware', width: 8) <= backdoor.rdData!;
  }
}

Future<void> _compileAndRun(String header, String source) async {
  final directory = await Directory.systemTemp.createTemp('hcl_csr_systemc_');
  try {
    await File('${directory.path}/csr.h').writeAsString(header);
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

  for (final asyncReset in [false, true]) {
    test('CSR unknown clock deassertion differs from Verilog async=$asyncReset',
        () async {
      final rtl = _CsrParent(CsrImplementation.rtl, asyncReset: asyncReset);
      await rtl.build();
      final initial = <Vector>[
        Vector({
          'clk': 0,
          'reset': 1,
          're': 1,
          'ra': 0,
          'we': 0,
          'wa': 0,
          'wd': 0,
          'hwe': 0,
          'hwd': 0,
        }, {}),
        Vector({'clk': 1}, {'rd': 0, 'hardware': 0}),
        Vector({'reset': 0}, {'rd': 0, 'hardware': 0}),
      ];
      final unknown = LogicValue.filled(8, LogicValue.x);
      await SimCompare.checkFunctionalVector(rtl, [
        ...initial,
        Vector({'clk': LogicValue.x}, {'rd': unknown, 'hardware': unknown}),
      ]);
      SimCompare.checkIverilogVector(rtl, [
        ...initial,
        Vector({'clk': LogicValue.x}, {'rd': 0, 'hardware': 0}),
      ]);
    });
  }

  test('CSR async reset 1 to X differs from Verilog', () async {
    final rtl = _CsrParent(CsrImplementation.rtl, asyncReset: true);
    await rtl.build();
    final initial = <Vector>[
      Vector({
        'clk': 0,
        'reset': 0,
        're': 1,
        'ra': 0,
        'we': 0,
        'wa': 0,
        'wd': 0,
        'hwe': 0,
        'hwd': 0,
      }, {}),
      Vector({'reset': 1}, {'rd': 0, 'hardware': 0}),
    ];
    final unknown = LogicValue.filled(8, LogicValue.x);
    await SimCompare.checkFunctionalVector(rtl, [
      ...initial,
      Vector({'reset': LogicValue.x}, {'rd': unknown, 'hardware': unknown}),
    ]);
    SimCompare.checkIverilogVector(rtl, [
      ...initial,
      Vector({'reset': LogicValue.x}, {'rd': 0, 'hardware': 0}),
    ]);
  });

  test('CSR behavioral leaf is substituted in a generated SystemC parent',
      timeout: _compileTimeout, () async {
    final rtl = _CsrParent(CsrImplementation.rtl);
    await rtl.build();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        're': 1,
        'ra': 0,
        'we': 0,
        'wa': 0,
        'wd': 0,
        'hwe': 0,
        'hwd': 0,
      }, {}),
      Vector({'clk': 1}, {'rd': 0, 'hardware': 0}),
      Vector({
        'clk': 0,
        'reset': 0,
        'we': 1,
        'wd': 0xa5,
        'hwe': 1,
        'hwd': 0x3c,
      }, {
        'rd': 0,
        'hardware': 0
      }),
      Vector({'clk': 1}, {'rd': 0xa5, 'hardware': 0xa5}),
      Vector({'clk': 0, 'we': 0, 'hwd': 0x5a}, {}),
      Vector({'clk': 1}, {'rd': 0x5a, 'hardware': 0x5a}),
      Vector({'clk': 0, 'hwe': 0, 'ra': 2}, {'rd': 0, 'hardware': 0x5a}),
    ];
    await SimCompare.checkFunctionalVector(rtl, vectors);
    SimCompare.checkIverilogVector(rtl, vectors);
    await Simulator.reset();
    final software = _CsrParent(CsrImplementation.software);
    await software.build();
    await SimCompare.checkFunctionalVector(software, vectors);
    expect(
        () => generateBehavioralSystemCHierarchy(rtl,
            select: (module) => module is CsrTop),
        throwsUnsupportedError);
    final hierarchy = generateBehavioralSystemCHierarchy(
      software,
      select: (module) => module is CsrTop,
      unknownOutputs: SystemCUnknownOutputPolicy.zeroUntilReset,
    );
    await _compileAndRun(hierarchy.source, '''
#include "csr.h"
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  sc_signal<bool> clk, reset, re, we, hwe;
  sc_signal<sc_uint<2>> ra, wa;
  sc_signal<sc_uint<8>> wd, hwd, rd, hardware;
  ${hierarchy.topClassName} parent("parent");
  parent.clk(clk); parent.reset(reset); parent.re(re); parent.ra(ra);
  parent.we(we); parent.wa(wa); parent.wd(wd);
  parent.hwe(hwe); parent.hwd(hwd); parent.rd(rd); parent.hardware(hardware);
  clk=0; reset=1; re=1; ra=0; we=0; wa=0; wd=0; hwe=0; hwd=0;
  sc_start(1,SC_NS);
  auto pulse=[&]() {
    clk=1; sc_start(1,SC_NS); clk=0; sc_start(1,SC_NS);
  };
  pulse();
  if(rd.read()!=0 || hardware.read()!=0) return 1;
  reset=0; we=1; wd=0xa5; hwe=1; hwd=0x3c; sc_start(1,SC_NS); pulse();
  if(rd.read()!=0xa5 || hardware.read()!=0xa5) return 2;
  we=0; hwd=0x5a; sc_start(1,SC_NS); pulse();
  if(rd.read()!=0x5a || hardware.read()!=0x5a) return 3;
  hwe=0; ra=2; sc_start(1,SC_NS);
  if(rd.read()!=0 || hardware.read()!=0x5a) return 4;
  return 0;
}
''');
  });

  test('RAM, CSR and associative exports share storage and replay CSR state',
      timeout: _compileTimeout, () async {
    final description = CsrModelDescription.fromConfig(
      CsrTopConfig(name: 'shared', blockSize: 4, blocks: [
        CsrBlockConfig(name: 'b', baseAddr: 0, registers: [
          CsrInstanceConfig(
              arch: CsrConfig(
                  name: 'r', access: CsrAccess.readWrite, fields: const []),
              addr: 0,
              width: 4),
        ]),
      ]),
      instanceName: 'shared',
    );
    final associative = AssociativeSoftwareModel(AssociativeMemoryRequest(
      keyWidth: 4,
      indexWidth: 2,
      entryCount: 3,
      updatePortCount: 1,
      lookupPortCount: 1,
      lookupLatency: 0,
      duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
      matchSelection: AssociativeMatchSelection.lowestIndex,
      resultShape: AssociativeResultShape.selectedIndex,
      lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
      updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
    ));
    final memory = MemoryModelDescription(
        addressWidth: 3,
        dataWidth: 8,
        readLatency: 1,
        asyncReset: false,
        writeMasked: [false],
        readMasked: [false]);
    final header = '${description.generateSystemC(className: 'CsrShared')}\n'
        '${associative.generateSystemC(className: 'AssocShared')}\n'
        '${memory.generateSystemC(className: 'RamShared')}';
    await _compileAndRun(header, '''
#include "csr.h"
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
  RohdHclSystemCSparseStorage<8> storage;
  storage.write_uncertain("0X",sc_lv<8>("00001111"));
  if(storage.contains("00") ||
     storage.read("00",sc_lv<8>(0))!=sc_lv<8>("0000XXXX")) return 5;
  storage.write("00",sc_lv<8>("10Z01010"));
  auto storage_image=storage.snapshot();
  storage.write_uncertain("X0",sc_lv<8>("11110000"));
  if(storage.read("00",sc_lv<8>(0))!=sc_lv<8>("XXXX1010")) return 6;
  storage.restore(storage_image);
  if(storage.read("00",sc_lv<8>(0))!=sc_lv<8>("10X01010") ||
     storage.read("01",sc_lv<8>(0))!=sc_lv<8>("0000XXXX")) return 7;
  auto invalid_image=storage_image;
  invalid_image.entries["00"]=sc_lv<8>(0);
  invalid_image.uncertain.push_back({"bad",sc_lv<8>(1)});
  bool rejected=false;
  try { storage.restore(invalid_image); }
  catch(const std::invalid_argument&) { rejected=true; }
  if(!rejected || storage.read("00",sc_lv<8>(0))!=sc_lv<8>("10X01010") ||
     storage.read("01",sc_lv<8>(0))!=sc_lv<8>("0000XXXX")) return 8;
  sc_signal<sc_logic> clk, reset;
  CsrShared dut("dut");
  dut.clk(clk); dut.reset(reset);
  clk=SC_LOGIC_0; reset=SC_LOGIC_0; sc_start(1,SC_NS);
  dut.poke(0,CsrShared::word("10Z1"));
  if(dut.peek(0)!=CsrShared::word("10X1")) return 1;
  auto saved=dut.snapshot();
  dut.poke(0,CsrShared::word("0000"));
  dut.restore(saved);
  if(dut.peek(0)!=CsrShared::word("10X1")) return 2;
  reset=SC_LOGIC_1; sc_start(1,SC_NS);
  clk=SC_LOGIC_1; sc_start(1,SC_NS);
  if(dut.peek(0)!=CsrShared::word("0000")) return 3;
  clk=SC_LOGIC_0; reset=SC_LOGIC_0; sc_start(1,SC_NS);
  dut.restore(saved); sc_start(1,SC_NS);
  if(dut.peek(0)!=CsrShared::word("10X1")) return 4;
  return 0;
}
''');
  });

  test('backdoor algorithms do not grow with register count', () {
    String algorithms(int count) {
      final description = CsrModelDescription.fromConfig(
        CsrTopConfig(name: 'compact', blockSize: 1024, blocks: [
          CsrBlockConfig(name: 'b', baseAddr: 0, registers: [
            for (var i = 0; i < count; i++)
              CsrInstanceConfig(
                  arch: CsrConfig(
                      name: 'r$i',
                      access: CsrAccess.readWrite,
                      fields: const []),
                  addr: i * 4,
                  width: 32),
          ]),
        ]),
        instanceName: 'compact',
        frontRead: MemoryPortGeometry(addressWidth: 10, dataWidth: 32),
        frontWrite: MemoryPortGeometry(addressWidth: 10, dataWidth: 32),
        hardwareRegisters: null,
      );
      final header = description.generateSystemC(className: 'Compact');
      for (final name in [
        ...description.inputPorts.keys,
        ...description.outputPorts.keys
      ]) {
        expect(header, contains('$name{"$name"};'));
      }
      return header.substring(header.indexOf('  void tick()'),
          header.indexOf('  static constexpr const char* register_metadata'));
    }

    expect(algorithms(128), algorithms(1));
  });

  for (final asynchronous in [false, true]) {
    for (final (label, registerWidth, dataWidth, addressWidth) in [
      ('fields', null, 16, 8),
      ('scalar', 1, 1, 1),
      ('wide', 80, 96, 8),
      ('wide-address', 16, 16, 80),
      ('padded', 16, 64, 8),
    ]) {
      test('compiled behavioral SystemC $label matches RTL async=$asynchronous',
          timeout: _compileTimeout, () async {
        final clk = Logic()..put(0);
        final reset = Logic()..put(0);
        final config = registerWidth == null
            ? csrSoftwareTestConfig(asyncReset: asynchronous)
            : CsrTopConfig(
                name: 'software_test',
                blockSize: addressWidth == 1 ? 2 : 128,
                asyncReset: asynchronous,
                blocks: [
                    CsrBlockConfig(name: 'control', baseAddr: 0, registers: [
                      CsrInstanceConfig(
                          arch: CsrConfig(
                              name: 'mixed',
                              access: CsrAccess.readWrite,
                              fields: const []),
                          addr: 0,
                          width: registerWidth),
                    ]),
                  ]);
        final reads = List.generate(
            2, (_) => DataPortInterface(dataWidth, addressWidth)..en.put(0));
        final writes =
            List.generate(2, (_) => DataPortInterface(dataWidth, addressWidth));
        final tops = [
          for (var i = 0; i < 2; i++)
            CsrTop(
              config: config,
              clk: clk,
              reset: reset,
              frontRead: reads[i],
              frontWrite: writes[i],
              allowLargerRegisters: true,
              implementationConfiguration: CsrImplementationConfiguration(
                implementation:
                    i == 0 ? CsrImplementation.rtl : CsrImplementation.software,
              ),
            ),
        ];
        for (var i = 0; i < 2; i++) {
          writes[i].en.put(0);
          writes[i].addr.put(0);
          writes[i].data.put(0);
          reads[i].addr.put(0);
          for (final hardware in tops[i].backdoorInterfaces.expand((p) => p)) {
            hardware.wrEn?.put(0);
            hardware.wrData?.put(0);
          }
          await tops[i].build();
        }
        final model = tops[1];
        final source = StringBuffer()
          ..writeln('#include "csr.h"')
          ..writeln('#include <iostream>')
          ..writeln('int sc_main(int, char**) {');
        for (final port in {...model.inputs, ...model.outputs}.entries) {
          final type = port.value.width == 1
              ? 'sc_dt::sc_logic'
              : 'sc_dt::sc_lv<${port.value.width}>';
          source.writeln('  sc_core::sc_signal<$type> s_${port.key};');
        }
        source.writeln('  BehavioralCsr dut("dut");');
        for (final port in {...model.inputs, ...model.outputs}.keys) {
          source.writeln('  dut.$port(s_$port);');
        }
        void setPort(String name, LogicValue value) {
          final literal = value.toString(includeWidth: false).toUpperCase();
          source.writeln(value.width == 1
              ? "  s_$name.write(sc_dt::sc_logic('$literal'));"
              : '  s_$name.write(sc_dt::sc_lv<${value.width}>("$literal"));');
        }

        void compare(int cycle) {
          final rtl = tops[0];
          for (final port in model.outputs.entries) {
            final expected = rtl.output(port.key).value;
            expect(port.value.value, expected,
                reason: 'Dart model cycle $cycle ${port.key}');
            final literal =
                expected.toString(includeWidth: false).toUpperCase();
            source.writeln(expected.width == 1
                ? "  if(s_${port.key}.read()!=sc_dt::sc_logic('$literal'))"
                    ' return 1;'
                : '  if(s_${port.key}.read()!=sc_dt::sc_lv<${expected.width}>'
                    ' ("$literal"))'
                    ' { std::cerr << "cycle $cycle ${port.key} got "'
                    ' << s_${port.key}.read() << " expected $literal\\n"; return 1; }');
          }
        }

        for (final port in model.inputs.entries) {
          setPort(port.key, LogicValue.ofInt(0, port.value.width));
        }
        source
          ..writeln('  s_reset.write(sc_dt::SC_LOGIC_1);')
          ..writeln('  sc_core::sc_start(1,sc_core::SC_NS);')
          ..writeln('  s_clk.write(sc_dt::SC_LOGIC_1);')
          ..writeln('  sc_core::sc_start(1,sc_core::SC_NS);')
          ..writeln('  s_clk.write(sc_dt::SC_LOGIC_0);')
          ..writeln('  s_reset.write(sc_dt::SC_LOGIC_0);')
          ..writeln('  sc_core::sc_start(1,sc_core::SC_NS);');
        Simulator.setMaxSimTime(1000);
        reset.inject(1);
        await Simulator.tick();
        clk.inject(1);
        await Simulator.tick();
        clk.inject(0);
        reset.inject(0);
        await Simulator.tick();
        final random = Random(991);
        final addresses = registerWidth == null
            ? [0, 4, 8, 9, 16, 24, 25, 64, 65, 128]
            : [0, if (addressWidth == 1) 1 else 128];
        for (var cycle = 0; cycle < 40; cycle++) {
          reset.inject(cycle == 22 || cycle == 32 ? 1 : 0);
          clk.inject(cycle == 30 ? LogicValue.x : LogicValue.zero);
          final address = addresses[cycle % addresses.length];
          final data = cycle % 7 == 0
              ? (dataWidth == 1
                  ? LogicValue.z
                  : LogicValue.ofString('0000xxxxzzzz1111')
                      .zeroExtend(dataWidth))
              : LogicValue.ofInt(
                  random.nextInt(1 << min(dataWidth, 16)), dataWidth);
          final requestedAddress = cycle == 16
              ? LogicValue.filled(addressWidth, LogicValue.x)
              : LogicValue.ofBigInt(
                  BigInt.from(address) +
                      (addressWidth > 64 && cycle % 4 == 1
                          ? BigInt.one << 75
                          : BigInt.zero),
                  addressWidth);
          for (var i = 0; i < 2; i++) {
            reads[i].addr.inject(requestedAddress);
            writes[i].addr.inject(requestedAddress);
            writes[i].en.inject(cycle == 9 ||
                    (registerWidth == null && (cycle == 10 || cycle == 15))
                ? LogicValue.x
                : LogicValue.ofInt(cycle % 3 == 0 ? 0 : 1, 1));
            writes[i].data.inject(data);
            final hardware = tops[i].getBackdoorPortsByName('control', 'mixed');
            hardware.wrEn!.inject(cycle == 13
                ? LogicValue.x
                : LogicValue.ofInt(cycle % 4 == 0 ? 1 : 0, 1));
            hardware.wrData!.inject(LogicValue.ofInt(
                registerWidth == 1 ? cycle % 2 : 0xf00 | cycle,
                hardware.wrData!.width));
          }
          await Simulator.tick();
          for (final port in model.inputs.entries) {
            setPort(port.key, port.value.value);
          }
          source.writeln('  sc_core::sc_start(1,sc_core::SC_NS);');
          compare(cycle * 2);
          clk.inject(1);
          await Simulator.tick();
          clk.inject(0);
          await Simulator.tick();
          source
            ..writeln('  s_clk.write(sc_dt::SC_LOGIC_1);')
            ..writeln('  sc_core::sc_start(1,sc_core::SC_NS);')
            ..writeln('  s_clk.write(sc_dt::SC_LOGIC_0);')
            ..writeln('  sc_core::sc_start(1,sc_core::SC_NS);');
          compare(cycle * 2 + 1);
        }
        source.writeln('  return 0;\n}');
        await Simulator.run();
        await _compileAndRun(
            model.behavioralModel!.description
                .generateSystemC(className: 'BehavioralCsr'),
            source.toString());
      });
    }
  }

  test('standalone SystemC uses frozen custom fallback without a ROHD runtime',
      timeout: _compileTimeout, () async {
    final field = _PortableFallbackField();
    final description = CsrModelDescription.fromConfig(
      CsrTopConfig(name: 'frozen', blockSize: 2, blocks: [
        CsrBlockConfig(name: 'b', baseAddr: 0, registers: [
          CsrInstanceConfig(
              arch: CsrConfig(
                  name: 'r', access: CsrAccess.readWrite, fields: [field]),
              addr: 0,
              width: 4),
        ]),
      ]),
      instanceName: 'frozen',
      frontRead: MemoryPortGeometry(addressWidth: 1, dataWidth: 4),
      frontWrite: MemoryPortGeometry(addressWidth: 1, dataWidth: 4),
    );
    field.fallback[0] = 0;
    await _compileAndRun(description.generateSystemC(className: 'Frozen'), '''
#include "csr.h"
int sc_main(int,char**) {
  Frozen dut("dut");
  sc_core::sc_signal<sc_dt::sc_logic> clk,reset,read_en,read_addr,en,addr;
  sc_core::sc_signal<sc_dt::sc_lv<4>> data,out;
  dut.clk(clk); dut.reset(reset); dut.frontRead_en(read_en);
  dut.frontRead_addr(read_addr); dut.frontRead_data(out);
  dut.frontWrite_en(en); dut.frontWrite_addr(addr); dut.frontWrite_data(data);
  clk.write(sc_dt::SC_LOGIC_0); reset.write(sc_dt::SC_LOGIC_0);
  read_addr.write(sc_dt::SC_LOGIC_0); addr.write(sc_dt::SC_LOGIC_0);
  en.write(sc_dt::SC_LOGIC_1); data.write("0010");
  sc_core::sc_start(1,sc_core::SC_NS);
  clk.write(sc_dt::SC_LOGIC_1);
  sc_core::sc_start(1,sc_core::SC_NS);
  return dut.peek(0)==Frozen::word("0001") &&
         out.read()==sc_dt::sc_lv<4>("0001") ? 0 : 1;
}
''');
  });

  test('strict two-state policy reports unknown output before first reset',
      timeout: _compileTimeout, () async {
    final description = CsrModelDescription.fromConfig(
      CsrTopConfig(name: 'strict', blockSize: 2, blocks: [
        CsrBlockConfig(name: 'b', baseAddr: 0, registers: [
          CsrInstanceConfig(
              arch: CsrConfig(
                  name: 'r', access: CsrAccess.readWrite, fields: const []),
              addr: 0,
              width: 1),
        ]),
      ]),
      instanceName: 'strict',
      frontRead: MemoryPortGeometry(addressWidth: 1, dataWidth: 1),
    );
    await _compileAndRun(
      description.generateSystemC(
        className: 'Strict',
        options:
            const SystemCModelOptions(portType: SystemCModelPortType.twoState),
      ),
      '''
#include "csr.h"
int sc_main(int,char**) {
  Strict dut("dut");
  sc_core::sc_signal<bool> clk,reset,en,addr,data;
  dut.clk(clk); dut.reset(reset); dut.frontRead_en(en);
  dut.frontRead_addr(addr); dut.frontRead_data(data);
  sc_core::sc_report_handler::set_actions(
      "CSR_UNKNOWN_OUTPUT",sc_core::SC_ERROR,sc_core::SC_THROW);
  try { sc_core::sc_start(1,sc_core::SC_NS); }
  catch(const sc_core::sc_report& report) {
    return std::string(report.get_msg_type())=="CSR_UNKNOWN_OUTPUT" ? 0 : 1;
  }
  return 2;
}
''',
    );
  });

  for (final (width, asynchronous) in [
    for (final width in [1, 32, 80])
      for (final asynchronous in [false, true]) (width, asynchronous),
  ]) {
    test('two-state $width-bit boundary async=$asynchronous rejects unknowns',
        timeout: _compileTimeout, () async {
      final top = CsrTop(
        config: CsrTopConfig(
            name: 'boundary',
            blockSize: 2,
            asyncReset: asynchronous,
            blocks: [
              CsrBlockConfig(name: 'b', baseAddr: 0, registers: [
                CsrInstanceConfig(
                    arch: CsrConfig(
                        name: 'value',
                        access: CsrAccess.readWrite,
                        fields: const []),
                    addr: 0,
                    width: width),
              ]),
            ]),
        clk: Logic()..put(0),
        reset: Logic()..put(0),
        frontRead: DataPortInterface(width, 1),
        frontWrite: DataPortInterface(width, 1),
        implementationConfiguration: const CsrImplementationConfiguration(
            implementation: CsrImplementation.software),
      );
      await top.build();
      final hardwareEnable =
          top.inputs.keys.singleWhere((name) => name.endsWith('_wrEn'));
      final hardwareData =
          top.inputs.keys.singleWhere((name) => name.endsWith('_wrData'));
      final hardwareRead =
          top.outputs.keys.singleWhere((name) => name != 'frontRead_data');
      final value =
          LogicValue.ofBigInt((BigInt.one << (width - 1)) | BigInt.one, width);
      final bits = value.toString(includeWidth: false);
      final type = width == 1
          ? 'bool'
          : width <= 64
              ? 'sc_dt::sc_uint<$width>'
              : 'sc_dt::sc_biguint<$width>';
      final one = width == 1 ? 'true' : '$type("0b$bits")';
      final source = StringBuffer()
        ..writeln('#include "csr.h"')
        ..writeln('int sc_main(int,char**) {')
        ..writeln('  Boundary dut("dut");');
      for (final port in {...top.inputs, ...top.outputs}.entries) {
        final portType = port.value.width == 1 ? 'bool' : type;
        source
          ..writeln('  sc_core::sc_signal<$portType> s_${port.key};')
          ..writeln('  dut.${port.key}(s_${port.key});');
      }
      source
        ..writeln('  sc_core::sc_start(1,sc_core::SC_NS);')
        ..writeln('  if(s_frontRead_data.read()!=0) return 1;')
        ..writeln('  s_reset.write(true);')
        ..writeln('  sc_core::sc_start(1,sc_core::SC_NS);')
        ..writeln('  if(dut.peek(0).is_01() != $asynchronous) return 7;')
        ..writeln('  s_clk.write(true);')
        ..writeln('  sc_core::sc_start(1,sc_core::SC_NS);')
        ..writeln('  s_clk.write(false); s_reset.write(false);')
        ..writeln('  s_$hardwareEnable.write(true);')
        ..writeln('  s_$hardwareData.write(0);')
        ..writeln('  s_frontWrite_en.write(true);')
        ..writeln('  s_frontWrite_data.write($one);')
        ..writeln('  sc_core::sc_start(1,sc_core::SC_NS);')
        ..writeln('  if(s_frontRead_data.read()!=0) return 2;')
        ..writeln('  s_clk.write(true);')
        ..writeln('  sc_core::sc_start(1,sc_core::SC_NS);')
        ..writeln('  if(s_frontRead_data.read()!=$one) return 3;')
        ..writeln('  if(s_$hardwareRead.read()!=$one) return 8;')
        ..writeln('  if(dut.peek(0)!=Boundary::word("$bits")) return 4;')
        ..writeln('  s_clk.write(false); s_frontWrite_en.write(false);')
        ..writeln('  sc_core::sc_start(1,sc_core::SC_NS);')
        ..writeln('  s_clk.write(true);')
        ..writeln('  sc_core::sc_start(1,sc_core::SC_NS);')
        ..writeln('  if(s_frontRead_data.read()!=0) return 9;')
        ..writeln('  sc_core::sc_report_handler::set_actions( '
            '"CSR_UNKNOWN_OUTPUT",sc_core::SC_ERROR,sc_core::SC_THROW);')
        ..writeln('  dut.poke(0,Boundary::word(sc_dt::SC_LOGIC_X));')
        ..writeln('  try { sc_core::sc_start(1,sc_core::SC_NS); }')
        ..writeln('  catch(const sc_core::sc_report& report) {')
        ..writeln('    return std::string(report.get_msg_type())'
            ' =="CSR_UNKNOWN_OUTPUT" ? 0 : 5; }')
        ..writeln('  return 6; }');
      await _compileAndRun(
          top.generateModelSystemC(
              className: 'Boundary',
              options: const SystemCModelOptions(
                  portType: SystemCModelPortType.twoState,
                  unknownOutputs: SystemCUnknownOutputPolicy.zeroUntilReset)),
          source.toString());
    });
  }
}
