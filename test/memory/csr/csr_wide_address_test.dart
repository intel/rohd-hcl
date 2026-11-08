// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_wide_address_test.dart
// Cross-backend CSR address and geometry regressions.
//
// 2026 November
// Author: ROHD-HCL contributors

@TestOn('vm')
library;

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/memory/csr/csr_container.dart';
import 'package:test/test.dart';

CsrInstanceConfig _register(String name, BigInt offset, int width) =>
    CsrInstanceConfig.wide(
        arch: CsrConfig(
            name: name, access: CsrAccess.readWrite, fields: const []),
        addr: offset,
        width: width);

Future<void> _run(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  expect(result.exitCode, 0,
      reason: '$executable: ${result.stdout}\n${result.stderr}');
}

void main() {
  tearDown(Simulator.reset);

  test('CSR configurations reject invalid and overlapping wide geometry', () {
    final huge = BigInt.one << 72;
    expect(() => _register('negative', -BigInt.one, 8),
        throwsA(isA<CsrValidationException>()));
    expect(
        () => CsrBlockConfig.wide(
            name: 'negative',
            baseAddr: -BigInt.one,
            registers: [_register('r', BigInt.zero, 8)]),
        throwsA(isA<CsrValidationException>()));
    expect(
        () => CsrTopConfig.wide(name: 'zero', blockSize: BigInt.zero, blocks: [
              CsrBlockConfig.wide(
                  name: 'b',
                  baseAddr: BigInt.zero,
                  registers: [_register('r', BigInt.zero, 8)])
            ]),
        throwsA(isA<CsrValidationException>()));

    final first = CsrBlockConfig.wide(
        name: 'a',
        baseAddr: huge,
        blockSize: BigInt.from(7),
        registers: [_register('r', BigInt.zero, 8)]);
    final overlapping = CsrBlockConfig.wide(
        name: 'b',
        baseAddr: huge + BigInt.from(6),
        registers: [_register('r', BigInt.zero, 8)]);
    expect(
        () => CsrTopConfig.wide(
            name: 'top', blockSize: BigInt.one, blocks: [first, overlapping]),
        throwsA(isA<CsrValidationException>()));
    final adjacent = CsrBlockConfig.wide(
        name: 'b',
        baseAddr: huge + BigInt.from(7),
        registers: [_register('r', BigInt.zero, 8)]);
    final config = CsrTopConfig.wide(
        name: 'top', blockSize: BigInt.one, blocks: [first, adjacent]);
    expect(config.minAddrBits(), 73);
    expect(config.clone().blocks.last.baseAddr, huge + BigInt.from(7));
    expect(config.getBlockByBigIntAddr(huge), first);
  });

  test('RTL and software reject write-only chunk collisions and overflow', () {
    final wide = _register('wide', BigInt.zero, 32);
    final collision = _register('collision', BigInt.one, 16);
    for (final config in [
      CsrTopConfig(name: 'collision', blockSize: 4, blocks: [
        CsrBlockConfig(name: 'b', baseAddr: 0, registers: [wide, collision])
      ]),
      CsrTopConfig(name: 'overflow', blockSize: 1, blocks: [
        CsrBlockConfig(name: 'b', baseAddr: 0, registers: [wide])
      ]),
    ]) {
      for (final implementation in CsrImplementation.values) {
        expect(
            () => CsrTop(
                config: config,
                clk: Logic(),
                reset: Logic(),
                frontRead: null,
                frontWrite: DataPortInterface<Logic>(16, 3),
                allowLargerRegisters: true,
                implementationConfiguration: CsrImplementationConfiguration(
                    implementation: implementation)),
            throwsA(isA<CsrValidationException>()),
            reason: '$implementation ${config.name}');
      }
    }
  });

  test('80-bit legal fields reject high-bit-distinct values', () async {
    final config = CsrTopConfig(name: 'legal_top', blockSize: 1, blocks: [
      CsrBlockConfig(name: 'b', baseAddr: 0, registers: [
        CsrInstanceConfig(
            arch: CsrConfig(name: 'r', access: CsrAccess.readWrite, fields: [
              CsrFieldConfig(
                  name: 'legal',
                  start: 0,
                  width: 80,
                  access: CsrFieldAccess.readWriteLegal,
                  legalValues: const [0, 1])
            ]),
            addr: 0,
            width: 80),
      ])
    ]);
    final clock = Logic()..put(0);
    final reset = Logic()..put(0);
    final writes = List.generate(2, (_) => DataPortInterface<Logic>(80, 1));
    final tops = [
      for (final implementation in CsrImplementation.values)
        CsrTop(
            config: config,
            clk: clock,
            reset: reset,
            frontRead: null,
            frontWrite: writes[implementation.index],
            implementationConfiguration:
                CsrImplementationConfiguration(implementation: implementation))
    ];
    for (var i = 0; i < tops.length; i++) {
      writes[i]
        ..en.put(1)
        ..addr.put(0)
        ..data.put(0);
      tops[i].getBackdoorPortsByName('b', 'r').wrEn!.put(0);
      tops[i].getBackdoorPortsByName('b', 'r').wrData!.put(0);
      await tops[i].build();
    }
    reset.inject(1);
    await Simulator.tick();
    clock.inject(1);
    await Simulator.tick();
    clock.inject(0);
    reset.inject(0);
    await Simulator.tick();
    for (final (value, expected) in [
      (BigInt.one, BigInt.one),
      ((BigInt.one << 75) + BigInt.one, BigInt.zero),
    ]) {
      for (final write in writes) {
        write.data.inject(value);
      }
      await Simulator.tick();
      clock.inject(1);
      await Simulator.tick();
      final hardware = tops.first.getBackdoorPortsByName('b', 'r').rdData!;
      expect(hardware.value.toBigInt(), expected);
      expect(tops.last.softwareModel!.peek(0).toBigInt(), expected);
      clock.inject(0);
      await Simulator.tick();
    }
  });

  for (final asyncReset in [false, true]) {
    test(
        '80-bit CSR maps match Dart RTL, Verilog and SystemC async=$asyncReset',
        timeout: const Timeout(Duration(minutes: 3)), () async {
      final highBase = (BigInt.one << 75) + BigInt.from(3);
      final highOffset = (BigInt.one << 68) + BigInt.one;
      final increment = (BigInt.one << 66) + BigInt.one;
      final lastBase = (BigInt.one << 80) - BigInt.from(4);
      final config = CsrTopConfig.wide(
        name: 'wide_csr',
        blockSize: BigInt.from(8),
        asyncReset: asyncReset,
        blocks: [
          CsrBlockConfig.wide(
              name: 'low',
              baseAddr: BigInt.from(7),
              registers: [_register('r0', BigInt.zero, 16)]),
          CsrBlockConfig.wide(
              name: 'high',
              baseAddr: highBase,
              blockSize: highOffset + increment + BigInt.one,
              registers: [
                _register('r1', BigInt.zero, 16),
                _register('r2', highOffset, 32),
              ]),
          CsrBlockConfig.wide(
              name: 'last',
              baseAddr: lastBase,
              blockSize: BigInt.from(4),
              registers: [_register('r3', BigInt.from(3), 16)]),
        ],
      );
      final clock = Logic()..put(0);
      final reset = Logic()..put(0);
      final reads =
          List.generate(2, (_) => DataPortInterface<Logic>(16, 80)..en.put(1));
      final writes = List.generate(2, (_) => DataPortInterface<Logic>(16, 80));
      final tops = [
        for (final implementation in CsrImplementation.values)
          CsrTop(
            config: config,
            clk: clock,
            reset: reset,
            frontRead: reads[implementation.index],
            frontWrite: writes[implementation.index],
            allowLargerRegisters: true,
            wideLogicalRegisterIncrement: increment,
            implementationConfiguration:
                CsrImplementationConfiguration(implementation: implementation),
          )
      ];
      for (var i = 0; i < tops.length; i++) {
        final CsrContainer container = tops[i];
        expect(container.logicalRegisterIncrement, increment);
        reads[i].addr.put(0);
        writes[i]
          ..en.put(0)
          ..addr.put(0)
          ..data.put(0);
        for (final port
            in tops[i].backdoorInterfaces.expand((ports) => ports)) {
          port.wrEn?.put(0);
          port.wrData?.put(0);
        }
        await tops[i].build();
      }
      final rtl = tops.first;
      final software = tops.last;
      final model = software.softwareModel!;
      expect(model.addressOf('high', 'r2'), highBase + highOffset);
      expect(software.getBackdoorPortsByBigIntAddr(highBase, highOffset),
          same(software.getBackdoorPortsByName('high', 'r2')));

      final verilog = StringBuffer('module tb;\n');
      final systemc = StringBuffer('''
#include "model.h"
#include "model2.h"
#include <systemc>
#include <iostream>
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
''');
      for (final port in {...rtl.inputs, ...rtl.outputs}.entries) {
        final width = port.value.width;
        verilog.writeln(
            '  logic ${width == 1 ? '' : '[${width - 1}:0] '}${port.key};');
        final fourStateType = width == 1 ? 'sc_logic' : 'sc_lv<$width>';
        systemc.writeln('  sc_signal<$fourStateType> s_${port.key};');
        final twoStateType = width == 1
            ? 'bool'
            : width <= 64
                ? 'sc_uint<$width>'
                : 'sc_biguint<$width>';
        systemc.writeln('  sc_signal<$twoStateType> t_${port.key};');
      }
      verilog
        ..writeln('  ${rtl.definitionName} dut('
            '${[
          ...rtl.inputs.keys,
          ...rtl.outputs.keys
        ].map((name) => '.$name($name)').join(',')});')
        ..writeln('  initial begin');
      systemc
        ..writeln('  WideCsr dut("dut");')
        ..writeln('  WideCsr2 dut2("dut2");');
      for (final name in [...software.inputs.keys, ...software.outputs.keys]) {
        systemc
          ..writeln('  dut.$name(s_$name);')
          ..writeln('  dut2.$name(t_$name);');
      }
      var phase = 0;
      var twoStateActive = true;
      void record({bool check = true}) {
        twoStateActive = twoStateActive &&
            software.inputs.values.every((input) => input.value.isValid);
        for (final input in software.inputs.entries) {
          final value = input.value.value;
          final bits = value.toString(includeWidth: false);
          verilog.writeln("    ${input.key}=${value.width}'b$bits;");
          systemc.writeln(value.width == 1
              ? "  s_${input.key}=sc_logic('${bits.toUpperCase()}');"
              : '  s_${input.key}=sc_lv<${value.width}> '
                  '("${bits.toUpperCase()}");');
          if (twoStateActive) {
            final literal = value.width == 1
                ? (value == LogicValue.one ? 'true' : 'false')
                : value.width <= 64
                    ? 'sc_uint<${value.width}>(${value.toBigInt()}ULL)'
                    : 'sc_biguint<${value.width}>("0b0$bits")';
            systemc.writeln('  t_${input.key}=$literal;');
          }
        }
        verilog.writeln('    #2;');
        systemc.writeln('  sc_start(2,SC_NS);');
        for (final output
            in check ? software.outputs.entries : <MapEntry<String, Logic>>[]) {
          final expected = rtl.output(output.key).value;
          expect(output.value.value, expected,
              reason: 'phase $phase ${output.key}');
          final bits = expected.toString(includeWidth: false);
          verilog.writeln("    if (${output.key} !== ${expected.width}'b$bits)"
              ' \$fatal(1,"phase $phase ${output.key}: got %b expected $bits", '
              '${output.key});');
          systemc.writeln(expected.width == 1
              ? '  if(s_${output.key}.read()!=sc_logic '
                  "('${bits.toUpperCase()}'))"
                  ' { std::cerr << "phase $phase ${output.key} got "'
                  ' << s_${output.key}.read() << "\\n"; return 1; }'
              : '  if(s_${output.key}.read()!=sc_lv<${expected.width}> '
                  '("${bits.toUpperCase()}"))'
                  ' { std::cerr << "phase $phase ${output.key} got "'
                  ' << s_${output.key}.read()'
                  ' << " expected $bits\\n"; return 1; }');
          if (twoStateActive) {
            final expectedTwo = expected.width == 1
                ? (expected == LogicValue.one ? 'true' : 'false')
                : 'sc_uint<${expected.width}>(${expected.toBigInt()}ULL)';
            systemc.writeln(
                '  if(t_${output.key}.read()!=$expectedTwo) return 4;');
          }
        }
        phase++;
      }

      Future<void> cycle(BigInt address,
          {bool write = false,
          int data = 0,
          bool rst = false,
          LogicValue? resetValue,
          int? highBackdoor,
          LogicValue? sampledAddress}) async {
        reset.inject(resetValue ?? (rst ? 1 : 0));
        for (var i = 0; i < tops.length; i++) {
          reads[i].addr.inject(sampledAddress ?? address);
          writes[i]
            ..addr.inject(sampledAddress ?? address)
            ..data.inject(data)
            ..en.inject(write ? 1 : 0);
          final hardware = tops[i].getBackdoorPortsByName('high', 'r1');
          hardware.wrEn!.inject(highBackdoor == null ? 0 : 1);
          hardware.wrData!.inject(highBackdoor ?? 0);
        }
        await Simulator.tick();
        record(check: phase != 0);
        clock.inject(1);
        await Simulator.tick();
        record();
        clock.inject(0);
        await Simulator.tick();
        record();
      }

      await cycle(BigInt.zero, rst: true);
      await cycle(BigInt.from(7), write: true, data: 0x1111);
      await cycle(highBase, write: true, data: 0x2222);
      await cycle(highBase + highOffset, write: true, data: 0x3333);
      await cycle(highBase + highOffset + increment, write: true, data: 0x4444);
      await cycle(lastBase + BigInt.from(3), write: true, data: 0x5555);
      await cycle(highBase, write: true, data: 0x7777, highBackdoor: 0x8888);
      expect(model.peekBigInt(highBase).toInt(), 0x7777);
      await cycle(BigInt.from(7),
          write: true, data: 0x1111, highBackdoor: 0x9999);
      expect(model.peekBigInt(highBase).toInt(), 0x9999);
      await cycle(highBase, write: true, data: 0x2222);
      for (final invalid in [
        highBase - BigInt.one,
        highBase + highOffset + increment + BigInt.one,
        lastBase - BigInt.one,
        BigInt.from(3),
      ]) {
        await cycle(invalid, write: true, data: 0xffff);
      }
      for (final (address, value) in [
        (BigInt.from(7), 0x1111),
        (highBase, 0x2222),
        (highBase + highOffset, 0x3333),
        (highBase + highOffset + increment, 0x4444),
        (lastBase + BigInt.from(3), 0x5555),
        (highBase - BigInt.one, 0),
        (highBase + highOffset + increment + BigInt.one, 0),
        (lastBase - BigInt.one, 0),
        (BigInt.from(3), 0),
      ]) {
        await cycle(address);
        expect(reads.first.data.value.toBigInt(), BigInt.from(value),
            reason: 'Read at $address');
      }
      final bits =
          LogicValue.ofBigInt(highBase, 80).toString(includeWidth: false);
      for (final unknown in ['x', 'z']) {
        await cycle(highBase,
            sampledAddress:
                LogicValue.ofString(bits.replaceRange(4, 5, unknown)));
      }
      final image = model.snapshot();
      final execution = model.snapshotExecution();
      expect(image[highBase + highOffset]!.toBigInt(), BigInt.from(0x44443333));
      expect(
          () => model.load({
                highBase: LogicValue.ofInt(1, 16),
                highBase + BigInt.one: LogicValue.ofInt(2, 16),
              }, replace: true),
          throwsArgumentError);
      expect(model.snapshot(), image);
      model
        ..pokeBigInt(highBase, LogicValue.ofInt(0xabcd, 16))
        ..load(image, replace: true);
      expect(model.peekBigInt(highBase).toInt(), 0x2222);
      model
        ..pokeBigInt(highBase, LogicValue.ofInt(0xabcd, 16))
        ..restoreExecution(execution);
      expect(model.peekBigInt(highBase).toInt(), 0x2222);
      systemc.writeln('''
  auto saved=dut.snapshot();
  WideCsr::address_type address("0x0${highBase.toRadixString(16)}");
  if(dut.peek(address)!=WideCsr::word(0x2222)) return 2;
  dut.poke(address,WideCsr::word(0xabcd));
  dut.restore(saved); sc_start(2,SC_NS);
  if(dut.peek(address)!=WideCsr::word(0x2222)) return 3;
''');
      await cycle(highBase,
          write: true,
          data: 0xa5a5,
          sampledAddress: LogicValue.ofString(bits.replaceRange(4, 5, 'x')));
      await cycle(BigInt.zero, rst: true);
      await cycle(highBase, write: true, data: 0x1234);
      await cycle(highBase, resetValue: LogicValue.x);
      if (!asyncReset) {
        await cycle(BigInt.zero, rst: true);
        await cycle(highBase, resetValue: LogicValue.x);
      }
      verilog.writeln(r'    $finish; end endmodule');
      systemc.writeln('  return 0;\n}');
      final directory = await Directory.systemTemp.createTemp('wide_csr_');
      try {
        await File('${directory.path}/dut.sv')
            .writeAsString(rtl.dumpSystemVerilog());
        await File('${directory.path}/tb.sv').writeAsString(verilog.toString());
        await File('${directory.path}/model.h')
            .writeAsString(software.generateModelSystemC(className: 'WideCsr'));
        await File('${directory.path}/model2.h').writeAsString(
            software.generateModelSystemC(
                className: 'WideCsr2',
                options: const SystemCModelOptions(
                    portType: SystemCModelPortType.twoState,
                    unknownOutputs:
                        SystemCUnknownOutputPolicy.zeroUntilReset)));
        await File('${directory.path}/test.cpp')
            .writeAsString(systemc.toString());
        await _run('iverilog', [
          '-g2012',
          '-o',
          '${directory.path}/sv',
          '${directory.path}/tb.sv',
          '${directory.path}/dut.sv'
        ]);
        await _run('vvp', ['${directory.path}/sv']);
        await _run('g++', [
          '-std=c++17',
          '${directory.path}/test.cpp',
          '-lsystemc',
          '-o',
          '${directory.path}/sc'
        ]);
        await _run('${directory.path}/sc', []);
      } finally {
        await directory.delete(recursive: true);
      }
    });
  }
}
