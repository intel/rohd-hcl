// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_software_model_test.dart
// Tests for CSR software models.
//
// 2026 October 16
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

CsrTopConfig csrSoftwareTestConfig({bool asyncReset = false}) => CsrTopConfig(
      name: 'software_test',
      blockSize: 64,
      asyncReset: asyncReset,
      blocks: [
        CsrBlockConfig(name: 'control', baseAddr: 0, registers: [
          CsrInstanceConfig(
            arch:
                CsrConfig(name: 'mixed', access: CsrAccess.readWrite, fields: [
              CsrFieldConfig(
                  start: 0,
                  width: 4,
                  name: 'rw',
                  access: CsrFieldAccess.readWrite),
              CsrFieldConfig(
                  start: 4,
                  width: 4,
                  name: 'wo',
                  access: CsrFieldAccess.writeOnly),
              CsrFieldConfig(
                  start: 8,
                  width: 4,
                  name: 'clear',
                  access: CsrFieldAccess.writeOnesClear),
              CsrFieldConfig(
                  start: 12,
                  width: 2,
                  name: 'legal',
                  access: CsrFieldAccess.readWriteLegal,
                  legalValues: const [0, 1]),
            ]),
            addr: 0,
            width: 16,
            resetValue: 0x0fa0,
          ),
          CsrInstanceConfig(
              arch: CsrConfig(
                  name: 'plain', access: CsrAccess.readWrite, fields: const []),
              addr: 4,
              width: 16,
              resetValue: 0x1234),
          CsrInstanceConfig(
              arch: CsrConfig(
                  name: 'wide', access: CsrAccess.readWrite, fields: const []),
              addr: 8,
              width: 32,
              resetValue: 0x12345678),
          CsrInstanceConfig(
              arch: CsrConfig(
                  name: 'ro', access: CsrAccess.readOnly, fields: const []),
              addr: 16,
              width: 16,
              resetValue: 0xabcd),
          CsrInstanceConfig(
              arch: CsrConfig(
                  name: 'command',
                  access: CsrAccess.readWrite,
                  fields: [
                    CsrFieldConfig(
                        start: 8,
                        width: 16,
                        name: 'pulse',
                        access: CsrFieldAccess.writeOnly),
                  ]),
              addr: 24,
              width: 32,
              resetValue: 0x00aabb00),
        ]),
        CsrBlockConfig(name: 'status', baseAddr: 64, registers: [
          CsrInstanceConfig(
              arch: CsrConfig(
                  name: 'value', access: CsrAccess.readWrite, fields: const []),
              addr: 0,
              width: 16),
        ]),
      ],
    );

void main() {
  tearDown(Simulator.reset);

  for (final (asyncReset, increment) in [(false, 1), (true, 1), (false, 4)]) {
    test(
        'RTL/software differential fields, priority, chunks, reset=$asyncReset increment=$increment',
        () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic()..put(0);
      final config = csrSoftwareTestConfig(asyncReset: asyncReset);
      final rtlRead = DataPortInterface(16, 8)..en.put(0);
      final modelRead = DataPortInterface(16, 8)..en.put(0);
      final rtlWrite = DataPortInterface(16, 8);
      final modelWrite = DataPortInterface(16, 8);
      final rtl = CsrTop(
          config: config,
          clk: clk,
          reset: reset,
          frontRead: rtlRead,
          frontWrite: rtlWrite,
          logicalRegisterIncrement: increment,
          allowLargerRegisters: true);
      final model = CsrTop(
          config: config,
          clk: clk,
          reset: reset,
          frontRead: modelRead,
          frontWrite: modelWrite,
          logicalRegisterIncrement: increment,
          allowLargerRegisters: true,
          implementationConfiguration: const CsrImplementationConfiguration(
              implementation: CsrImplementation.software));
      final rtlHardware = rtl.getBackdoorPortsByName('control', 'mixed');
      final modelHardware = model.getBackdoorPortsByName('control', 'mixed');
      for (final top in [rtl, model]) {
        for (final block in top.backdoorInterfaces) {
          for (final port in block) {
            port.wrEn?.put(0);
            port.wrData?.put(0);
          }
        }
      }
      for (final write in [rtlWrite, modelWrite]) {
        write.en.put(0);
        write.addr.put(0);
        write.data.put(0);
      }
      await rtl.build();
      await model.build();
      Simulator.setMaxSimTime(2000);
      unawaited(Simulator.run());
      reset.inject(1);
      await clk.nextPosedge;
      await clk.nextNegedge;
      reset.inject(0);
      final random = Random(47);
      final addresses = [
        0,
        4,
        8,
        8 + increment,
        16,
        24,
        24 + increment,
        64,
        65,
        128
      ];
      for (var cycle = 0; cycle < 70; cycle++) {
        final address = addresses[random.nextInt(addresses.length)];
        final data = random.nextInt(1 << 16);
        final enable = cycle % 3 != 0 ? 1 : 0;
        final hwEnable = cycle % 4 == 0 ? 1 : 0;
        final hwData = random.nextInt(1 << 16);
        for (final write in [rtlWrite, modelWrite]) {
          write.addr.inject(address);
          write.data.inject(data);
          write.en.inject(enable);
        }
        for (final hardware in [rtlHardware, modelHardware]) {
          hardware.wrEn!.inject(hwEnable);
          hardware.wrData!.inject(hwData);
        }
        rtlRead.addr.inject(address);
        modelRead.addr.inject(address);
        await Simulator.tick();
        expect(modelRead.data.value, rtlRead.data.value,
            reason: 'pre-edge $cycle');
        expect(modelHardware.rdData!.value, rtlHardware.rdData!.value,
            reason: 'hardware pre-edge $cycle');
        await clk.nextPosedge;
        await clk.nextNegedge;
        expect(modelRead.data.value, rtlRead.data.value,
            reason: 'post-edge $cycle');
        expect(modelHardware.rdData!.value, rtlHardware.rdData!.value,
            reason: 'hardware post-edge $cycle');
      }
      await Simulator.endSimulation();
    });
  }

  test('software state access validates atomically without register RTL',
      () async {
    final read = DataPortInterface(32, 8)..addr.put(4);
    final top = CsrTop(
        config: csrSoftwareTestConfig(),
        clk: Logic(),
        reset: Logic(),
        frontRead: read,
        frontWrite: null,
        implementationConfiguration: CsrImplementationConfiguration.software);
    await top.build();
    final state = top.softwareModel!;
    expect(state.hardwareRegisterCount, 0);
    expect(top.subModules, isEmpty);
    expect(top.backdoorInterfaces.expand((ports) => ports), isEmpty);
    state.load({}, replace: true);
    expect(read.data.value.toInt(), 0x1234);
    state.poke(4, LogicValue.ofInt(0xbeef, 16));
    expect(read.data.value.toInt(), 0xbeef);
    final before = state.snapshot();
    expect(
        () => state
            .load({4: LogicValue.ofInt(1, 16), 100: LogicValue.ofInt(0, 16)}),
        throwsArgumentError);
    expect(state.snapshot(), before);
    expect(state.addressOf('control', 'plain'), 4);
    expect(top.generateSynth, throwsUnsupportedError);
  });

  test('scope supports indirect concrete CsrTop construction', () {
    final top = CsrImplementationScope.run(
        CsrImplementationConfiguration.software,
        () => CsrTop(
            config: csrSoftwareTestConfig(),
            clk: Logic(),
            reset: Logic(),
            frontRead: null,
            frontWrite: null));
    expect(top.softwareModel, isNotNull);
    expect(top.softwareModel!.hardwareRegisterCount, 0);
    expect(
        CsrImplementationScope.current.implementation, CsrImplementation.rtl);
    final overridden = CsrImplementationScope.run(
        CsrImplementationConfiguration.software,
        () => CsrTop(
            config: csrSoftwareTestConfig(),
            clk: Logic(),
            reset: Logic(),
            frontRead: null,
            frontWrite: null,
            implementationConfiguration:
                const CsrImplementationConfiguration()));
    expect(overridden.softwareModel, isNull);
  });

  test('model samples old values from synchronous upstream logic', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);
    final enable = Logic();
    final data = Logic(width: 32);
    Sequential(clk, [
      If(reset, then: [
        enable < Const(0),
        data < Const(0, width: 32),
      ], orElse: [
        enable < Const(1),
        data < data + Const(1, width: 32),
      ]),
    ]);
    final reads = <DataPortInterface>[];
    for (final implementation in CsrImplementation.values) {
      final read = DataPortInterface(32, 8)..addr.put(4);
      final write = DataPortInterface(32, 8)..addr.put(4);
      write.en <= enable;
      write.data <= data;
      reads.add(read);
      final top = CsrTop(
        config: csrSoftwareTestConfig(),
        clk: clk,
        reset: reset,
        frontRead: read,
        frontWrite: write,
        implementationConfiguration: CsrImplementationConfiguration(
            implementation: implementation,
            hardwareRegisters:
                implementation == CsrImplementation.software ? {} : null),
      );
      for (final port in top.backdoorInterfaces.expand((ports) => ports)) {
        port.wrEn?.put(0);
        port.wrData?.put(0);
      }
      await top.build();
    }
    Simulator.setMaxSimTime(300);
    unawaited(Simulator.run());
    reset.inject(1);
    await clk.nextPosedge;
    await clk.nextNegedge;
    reset.inject(0);
    for (var cycle = 0; cycle < 20; cycle++) {
      await clk.nextPosedge;
      await clk.nextNegedge;
      expect(reads[1].data.value, reads[0].data.value, reason: 'cycle $cycle');
    }
    await Simulator.endSimulation();
  });

  test('selected exposure validates names and preserves structured reads',
      () async {
    final top = CsrTop(
        config: csrSoftwareTestConfig(),
        clk: Logic(),
        reset: Logic(),
        frontRead: null,
        frontWrite: null,
        implementationConfiguration: const CsrImplementationConfiguration(
            implementation: CsrImplementation.software,
            hardwareRegisters: {'control/mixed'}));
    await top.build();
    expect(top.softwareModel!.hardwareRegisterCount, 1);
    top.softwareModel!.load({}, replace: true);
    final read = top.getBackdoorPortsByName('control', 'mixed').rdData!;
    expect(read.getField('rw').value.toInt(), 0);
    expect(read.getField('clear').value.toInt(), 15);
    expect(
        () => CsrTop(
            config: csrSoftwareTestConfig(),
            clk: Logic(),
            reset: Logic(),
            frontRead: null,
            frontWrite: null,
            implementationConfiguration: const CsrImplementationConfiguration(
                implementation: CsrImplementation.software,
                hardwareRegisters: {'missing'})),
        throwsArgumentError);
  });

  for (final count in [1000, 6325]) {
    for (final selected in [
      <String>{},
      {'b0/r0', 'b1/r1'}
    ]) {
      test(
          '$count registers with ${selected.length} exposed'
          ' have no internal modules', () async {
        final config = CsrTopConfig(name: 'scale', blockSize: 256, blocks: [
          for (var block = 0; block < 109; block++)
            CsrBlockConfig(name: 'b$block', baseAddr: block * 256, registers: [
              for (var i = block; i < count; i += 109)
                CsrInstanceConfig(
                    arch: CsrConfig(
                      name: 'r$i',
                      access: CsrAccess.readWrite,
                      fields: const [],
                    ),
                    addr: i ~/ 109,
                    width: 32),
            ]),
        ]);
        final read = DataPortInterface(32, 16)..addr.put(0);
        final top = CsrTop(
            config: config,
            clk: Logic(),
            reset: Logic(),
            frontRead: read,
            frontWrite: null,
            implementationConfiguration: CsrImplementationConfiguration(
                implementation: CsrImplementation.software,
                hardwareRegisters: selected));
        await top.build();
        expect(top.softwareModel!.registerCount, count);
        expect(top.subModules, isEmpty);
        expect(top.softwareModel!.hardwareRegisterCount, selected.length);
        expect(top.inputs.length, 4 + selected.length * 2);
        expect(top.outputs.length, 1 + selected.length);
        top.softwareModel!.poke(0, LogicValue.ofInt(count, 32));
        expect(read.data.value.toInt(), count);
      });
    }
  }
}
