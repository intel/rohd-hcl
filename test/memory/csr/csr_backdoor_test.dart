// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_backdoor_test.dart
// Tests that register level access rules apply only to frontdoor writes
//
// 2026 September 21
// Author: Shubham Padkonde <shubhampadkonde12@gmail.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:test/test.dart';

const _csrWidth = 32;

/// A status register: read only from the frontdoor, written by hardware
/// through the backdoor.
class StatusBlock extends CsrBlockConfig {
  StatusBlock({super.name = 'statusBlock'})
      : super(baseAddr: 0x0, registers: [
          CsrInstanceConfig(
            arch: CsrConfig(
                name: 'status', access: CsrAccess.readOnly, fields: const []),
            addr: 0x0,
            width: _csrWidth,
            isBackdoorReadable: true,
            isBackdoorWritable: true,
          ),
        ]);
}

class _CsrReadConsumer extends Module {
  _CsrReadConsumer(CsrBackdoorInterface source) {
    final local = addInterfacePorts(source,
        inputTags: {CsrBackdoorPortGroup.read},
        uniquify: (name) => 'local_$name');
    addOutput('field', width: 4) <= local.rdData!.getField('flags');
  }
}

class _InterfaceModule extends Module {}

class _ReadSource extends Interface<CsrBackdoorPortGroup> {
  _ReadSource(Logic data) {
    setPorts([data], [CsrBackdoorPortGroup.read]);
  }

  @override
  _ReadSource clone() => _ReadSource(port('status').cloneTyped());
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('backdoor read input preserves CSR fields across a module', () async {
    final config = CsrInstanceConfig(
      arch: CsrConfig(name: 'status', access: CsrAccess.readWrite, fields: [
        CsrFieldConfig(
            name: 'flags', start: 0, width: 4, access: CsrFieldAccess.readWrite)
      ]),
      addr: 0,
      width: 8,
    );
    final dut = _CsrReadConsumer(CsrBackdoorInterface(config: config));
    final input = dut.input('local_status');
    expect(input, isA<Csr>());
    expect((input as Csr).config, config);
    await dut.build();
    final vectors = [
      Vector({'local_status': 0x5a}, {'field': 0xa}),
      Vector({'local_status': 0xc3}, {'field': 3}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('backdoor read registration validates only selected payloads', () {
    final config = StatusBlock().registers.single;
    final target = CsrBackdoorInterface(config: config);
    final packed = _ReadSource(Logic(name: 'status', width: _csrWidth));
    final consumer = _InterfaceModule()
      ..addInterfaceFrom(target, packed,
          inputTags: {CsrBackdoorPortGroup.read});
    expect(consumer.input('status'), isA<Csr>());

    final incompatible = _ReadSource(LogicStructure([
      Logic(name: 'different', width: _csrWidth),
    ], name: 'status'));
    expect(
        () => _InterfaceModule().addInterfaceFrom(
            CsrBackdoorInterface(config: config), incompatible,
            inputTags: {CsrBackdoorPortGroup.read}),
        throwsA(isA<PortTypeException>()));
    expect(
        () => _InterfaceModule().addInterfaceFrom(
            CsrBackdoorInterface(config: config), incompatible),
        returnsNormally);
  });

  test('typed CSR connections reject different register configurations', () {
    final config = CsrInstanceConfig(
      arch: CsrConfig(name: 'status', access: CsrAccess.readWrite, fields: [
        CsrFieldConfig(
            name: 'flags', start: 0, width: 4, access: CsrFieldAccess.readWrite)
      ]),
      addr: 0,
      width: 8,
    );
    final equivalent = config.clone(arch: config.arch.clone());
    final different = [
      config.clone(addr: 4),
      config.clone(wideAddr: BigInt.one << 80),
      config.clone(arch: config.arch.clone(access: CsrAccess.readOnly)),
      config.clone(
          arch: config.arch.clone(fields: [
        config.fields.single.clone(access: CsrFieldAccess.readOnly)
      ])),
      config.clone(resetValue: 1),
      config.clone(isFrontdoorWritable: false),
      config.clone(arch: config.arch.clone(resetValue: 1)),
    ];
    CsrInstanceConfig legalConfig(List<int> values) => config.clone(
          arch: config.arch.clone(fields: [
            config.fields.single.clone(
                access: CsrFieldAccess.readWriteLegal, legalValues: values)
          ]),
        );
    expect(samePayloadShape(Csr(legalConfig([0, 1])), Csr(legalConfig([0, 2]))),
        isFalse);

    for (final candidate in [equivalent, ...different]) {
      final shouldMatch = candidate == config;
      expect(
          payloadShapeIdentity(Csr(candidate)) ==
              payloadShapeIdentity(Csr(config)),
          shouldMatch);
      final source = _ReadSource(Csr(candidate));
      for (final input in [true, false]) {
        expect(
          () => _InterfaceModule().addInterfaceFrom(
            CsrBackdoorInterface(config: config),
            source,
            inputTags: input ? {CsrBackdoorPortGroup.read} : null,
            outputTags: input ? null : {CsrBackdoorPortGroup.read},
          ),
          shouldMatch ? returnsNormally : throwsA(isA<PortTypeException>()),
        );
      }
      expect(
        () => ReadyValidRegister<Logic>(
          clk: Logic(),
          reset: Logic(),
          upstream: ReadyValidInterface<Logic>(Csr(config)),
          downstream: ReadyValidInterface<Logic>(Csr(candidate)),
        ),
        shouldMatch ? returnsNormally : throwsA(isA<PortTypeException>()),
      );
    }

    expect(
      () => _InterfaceModule().addInterfaceFrom(
        CsrBackdoorInterface(config: config),
        _ReadSource(Csr(different.first)),
      ),
      returnsNormally,
    );
    expect(
      () => ReadyValidRegister<Logic>(
        clk: Logic(),
        reset: Logic(),
        upstream: ReadyValidInterface<Logic>(Csr(config)),
        downstream: ReadyValidInterface<Logic>(Logic(width: config.width)),
      ),
      returnsNormally,
    );
  });

  test('nested CSR payloads retain configuration compatibility', () {
    final config = StatusBlock().registers.single;
    TypedLogicArray<Csr, LogicValue> array(CsrInstanceConfig schema) =>
        TypedLogicArray<Csr, LogicValue>(
          [2],
          ({name}) => Csr(schema).clone(name: name),
          numUnpackedDimensions: 1,
        );
    final original = array(config);
    final equivalent = array(config.clone());
    final different = array(config.clone(addr: 4));
    expect(samePayloadShape(original, equivalent), isTrue);
    expect(samePayloadShape(original, different), isFalse);
    expect(payloadShapeIdentity(original), payloadShapeIdentity(equivalent));
    expect(
        payloadShapeIdentity(original), isNot(payloadShapeIdentity(different)));
  });

  test('CSR configuration survives a typed ready-valid queue', () async {
    final config = StatusBlock().registers.single;
    final dut = ReadyValidQueue<Csr>(
      clk: Logic(),
      reset: Logic(),
      upstream: ReadyValidInterface(Csr(config)),
      downstream: ReadyValidInterface(Csr(config.clone())),
      depth: 1,
      storage: ReadyValidQueueStorage.ring,
    );
    expect(dut.upstream.data.config, config);
    expect(dut.downstream.data.config, config);
    await dut.build();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'upstream_valid': 0,
        'upstream_status': 0x12345678,
        'downstream_ready': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector(
          {'clk': 0, 'reset': 0, 'upstream_valid': 1}, {'upstream_ready': 1}),
      Vector(
          {'clk': 1}, {'downstream_valid': 1, 'downstream_status': 0x12345678}),
      Vector({'clk': 0, 'upstream_valid': 0, 'upstream_status': 0},
          {'downstream_valid': 1, 'downstream_status': 0x12345678}),
      Vector(
          {'clk': 1}, {'downstream_valid': 1, 'downstream_status': 0x12345678}),
      Vector({'clk': 0, 'downstream_ready': 1}, {'downstream_valid': 1}),
      Vector({'clk': 1}, {'downstream_valid': 0}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('a readOnly register is still backdoor writeable', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);
    final wIntf = DataPortInterface(_csrWidth, 8);
    final rIntf = DataPortInterface(_csrWidth, 8);

    final block = CsrBlock(
        config: StatusBlock(),
        clk: clk,
        reset: reset,
        frontWrite: wIntf,
        frontRead: rIntf);

    final readPort = block.output('${block.name}_status_backdoor_status');
    expect(readPort, isA<Csr>());
    expect((readPort as Csr).config, block.csrs.single.config);

    wIntf.en.put(0);
    wIntf.addr.put(0);
    wIntf.data.put(0);
    rIntf.en.put(0);
    rIntf.addr.put(0);

    await block.build();

    final back = block.getBackdoorPortsByName('status');
    back.wrEn!.put(0);
    back.wrData!.put(0);

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    // perform a reset
    reset.inject(1);
    for (var i = 0; i < 4; i++) {
      await clk.nextNegedge;
    }
    reset.inject(0);
    for (var i = 0; i < 4; i++) {
      await clk.nextNegedge;
    }

    expect(back.rdData!.value, LogicValue.ofInt(0, _csrWidth));

    // Hardware updates the status register through the backdoor.
    back.wrEn!.inject(1);
    back.wrData!.inject(0xdeadbeef);
    await clk.nextNegedge;
    back.wrEn!.inject(0);
    await clk.nextNegedge;

    expect(back.rdData!.value, LogicValue.ofInt(0xdeadbeef, _csrWidth),
        reason: 'the backdoor write should have landed');

    // The frontdoor still cannot write it.
    wIntf.en.inject(1);
    wIntf.addr.inject(0x0);
    wIntf.data.inject(0x12345678);
    await clk.nextNegedge;
    wIntf.en.inject(0);
    await clk.nextNegedge;

    expect(back.rdData!.value, LogicValue.ofInt(0xdeadbeef, _csrWidth),
        reason: 'a frontdoor write to a readOnly register must be dropped');

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });
}
