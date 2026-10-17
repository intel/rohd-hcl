// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// portable_memory_model_test.dart
// Tests for portable memory model behavior.
//
// 2026 October 16
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:convert';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

import 'csr_software_model_test.dart' show csrSoftwareTestConfig;

class _FallbackField extends CsrFieldConfig {
  final List<int> state = [1, 0];
  int get calls => state[1];
  int get fallback => state[0];
  set fallback(int value) => state[0] = value;

  _FallbackField()
      : super(
            name: 'legal',
            start: 0,
            width: 4,
            access: CsrFieldAccess.readWriteLegal,
            legalValues: [0, 1]);

  @override
  int transformIllegalValue() {
    state[1]++;
    return fallback;
  }
}

class _OtherModel
    implements
        BehavioralModelProvider,
        BehavioralModel,
        BehavioralModelDescription {
  @override
  BehavioralModel get behavioralModel => this;
  @override
  BehavioralModelDescription get description => this;
  @override
  String get kind => 'test-family';
  @override
  Map<String, int> get inputPorts => const {};
  @override
  Map<String, int> get outputPorts => const {};
  @override
  String generateSystemC({
    required String className,
    SystemCModelOptions options = const SystemCModelOptions(),
  }) {
    if (className == 'Invalid') {
      throw UnsupportedError('Test export failure');
    }
    return '$className:${options.portType.name}';
  }
}

void main() {
  tearDown(Simulator.reset);

  test('portable discovery has no CSR dependency and propagates errors', () {
    final provider = _OtherModel();
    expect(generateBehavioralSystemC(provider, 'Other'), 'Other:fourState');
    expect(
        generateBehavioralSystemC(provider, 'Other',
            options: const SystemCModelOptions(
                portType: SystemCModelPortType.twoState)),
        'Other:twoState');
    expect(() => generateBehavioralSystemC(provider, 'Invalid'),
        throwsUnsupportedError);
  });

  test('four-state image codec is lossless beyond native integer widths', () {
    for (final width in [1, 32, 80, 160]) {
      for (final bit in ['0', '1', 'x', 'z']) {
        final value = LogicValue.ofString(List.filled(width, bit).join());
        final encoded = jsonDecode(jsonEncode(MemoryValueCodec.encode(value)));
        expect(MemoryValueCodec.decode(encoded), value);
      }
    }
    final mixed = LogicValue.ofString('01xz10zx');
    expect(MemoryValueCodec.decode(MemoryValueCodec.encode(mixed)), mixed);
    expect(MemoryValueCodec.binary(mixed, width: 12), '000001xz10zx');
    expect(() => MemoryValueCodec.binary(mixed, width: 4), throwsArgumentError);
    for (final invalid in [
      null,
      {'width': 4, 'bits': '001'},
      {'width': 4, 'bits': '00002'},
      {'width': 0, 'bits': ''},
      {'width': 4, 'bits': '0q01'},
    ]) {
      expect(() => MemoryValueCodec.decode(invalid), throwsFormatException);
    }
  });

  test('sparse raw state preserves absence, geometry, and atomic loading', () {
    var callbacks = 0;
    final storage = SparseMemoryStorage(
      addrWidth: 8,
      dataWidth: 80,
      alignAddress: (_) => throw StateError('Raw access must not align.'),
      onInvalidRead: (address, width) {
        callbacks++;
        return LogicValue.filled(80, LogicValue.x);
      },
      onInvalidWrite: () => callbacks++,
    );
    final MemoryStateAccess<Map<int, LogicValue>> state =
        MemoryStorageState(storage);
    expect(state.peek(7), isNull);
    final value = LogicValue.ofString('xz01').zeroExtend(80);
    state.poke(7, value);
    final saved = state.snapshot();
    expect(saved, {7: value});
    expect(saved.clear, throwsUnsupportedError);
    state.load({9: LogicValue.ofInt(3, 80)});
    expect(state.peek(7), value);
    expect(state.peek(9)!.toInt(), 3);
    final before = state.snapshot();
    expect(
        () =>
            state.load({7: LogicValue.ofInt(1, 80), 256: value}, replace: true),
        throwsRangeError);
    expect(state.snapshot(), before);
    expect(() => state.load({7: LogicValue.ofInt(1, 32)}, replace: true),
        throwsArgumentError);
    expect(state.snapshot(), before);
    expect(() => state.peek(-1), throwsRangeError);
    state.load(saved, replace: true);
    expect(state.snapshot(), saved);
    expect(state.peek(9), isNull);
    state.load({}, replace: true);
    expect(state.snapshot(), isEmpty);
    expect(callbacks, 0);
  });

  test('CSR description freezes custom callbacks once for both backends',
      () async {
    final field = _FallbackField();
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
    final header = description.generateSystemC(className: 'Frozen');
    expect(field.calls, 1);
    field.fallback = 0;
    final copied = description.registers[0]!;
    expect(identical(copied.config.fields.single, field), isFalse);
    expect(copied.illegalValues[copied.config.fields.single]!.toInt(), 1);
    expect(copied.config.fields.clear, throwsUnsupportedError);
    expect(copied.illegalValues.clear, throwsUnsupportedError);
    expect(description.registers.clear, throwsUnsupportedError);
    expect(description.inputPorts.clear, throwsUnsupportedError);
    for (var instance = 0; instance < 2; instance++) {
      final clk = Logic()..put(0);
      final write = DataPortInterface(4, 1)
        ..en.put(1)
        ..addr.put(0)
        ..data.put(2);
      final model = CsrSoftwareModel(
          description: description,
          clk: clk,
          reset: Logic()..put(0),
          frontRead: DataPortInterface(4, 1)..addr.put(0),
          frontWrite: write,
          hardware: {});
      final MemoryStateAccess<Map<int, LogicValue>> state = model
        ..load({}, replace: true);
      clk.inject(1);
      await Simulator.tick();
      expect(state.peek(0)!.toInt(), 1);
      state.poke(0, LogicValue.ofInt(0, 4));
      expect(model.generateSystemC(className: 'Frozen'), header);
      await model.dispose();
    }
    expect(field.calls, 1);
  });

  test('portable metadata matches live ports and generic model discovery',
      () async {
    final config = csrSoftwareTestConfig();
    for (final software in [false, true]) {
      final top = CsrTop(
        config: config,
        clk: Logic(),
        reset: Logic(),
        frontRead: DataPortInterface(16, 8),
        frontWrite: DataPortInterface(16, 8),
        allowLargerRegisters: true,
        implementationConfiguration: CsrImplementationConfiguration(
            implementation:
                software ? CsrImplementation.software : CsrImplementation.rtl,
            hardwareRegisters: software ? {'control/mixed'} : null),
      );
      await top.build();
      final BehavioralModelProvider provider = top;
      if (!software) {
        expect(provider.behavioralModel, isNull);
        expect(generateBehavioralSystemC(top, 'Rtl'), isNull);
        continue;
      }
      final model = provider.behavioralModel!;
      expect(model.description.kind, 'csr');
      expect(model.description.inputPorts,
          top.inputs.map((key, value) => MapEntry(key, value.width)));
      expect(model.description.outputPorts,
          top.outputs.map((key, value) => MapEntry(key, value.width)));
      expect(generateBehavioralSystemC(top, 'Portable'),
          model.generateSystemC(className: 'Portable'));
      expect(top.generateSynth, throwsUnsupportedError);
    }
    expect(generateBehavioralSystemC(Object(), 'Unrelated'), isNull);
  });

  test('standalone descriptions validate geometry and requested exposure', () {
    final config = csrSoftwareTestConfig();
    expect(
        () => CsrModelDescription.fromConfig(config,
            instanceName: 'bad', hardwareRegisters: {'missing'}),
        throwsArgumentError);
    expect(
        () => CsrModelDescription.fromConfig(config,
            instanceName: 'bad',
            frontRead: MemoryPortGeometry(addressWidth: 8, dataWidth: 16)),
        throwsA(isA<CsrValidationException>()));
    expect(
        () => CsrModelDescription.fromConfig(config,
            instanceName: 'bad',
            frontRead: MemoryPortGeometry(addressWidth: 1, dataWidth: 32)),
        throwsA(isA<CsrValidationException>()));
    expect(
        () => CsrModelDescription.fromConfig(config,
            instanceName: 'bad',
            frontRead: MemoryPortGeometry(addressWidth: 8, dataWidth: 32),
            frontWrite: MemoryPortGeometry(addressWidth: 9, dataWidth: 32)),
        throwsA(isA<CsrValidationException>()));
    for (final increment in [1, 4]) {
      final overlapping = CsrTopConfig(name: 'overlap', blockSize: 16, blocks: [
        CsrBlockConfig(name: 'b', baseAddr: 0, registers: [
          for (final (name, address, width) in [
            ('wide', 0, 64),
            ('next', increment, 32)
          ])
            CsrInstanceConfig(
                arch: CsrConfig(
                    name: name, access: CsrAccess.readWrite, fields: const []),
                addr: address,
                width: width),
        ]),
      ]);
      expect(
          () => CsrModelDescription.fromConfig(overlapping,
              instanceName: 'bad',
              allowLargerRegisters: true,
              logicalRegisterIncrement: increment,
              frontRead: MemoryPortGeometry(addressWidth: 4, dataWidth: 32)),
          throwsA(isA<CsrValidationException>()));
    }
    expect(() => MemoryPortGeometry(addressWidth: 0, dataWidth: 32),
        throwsArgumentError);
    expect(
        () => CsrModelDescription.fromConfig(config,
            instanceName: 'bad', logicalRegisterIncrement: 0),
        throwsArgumentError);
  });
}
