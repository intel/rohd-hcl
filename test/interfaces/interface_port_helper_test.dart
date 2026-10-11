// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// interface_port_helper_test.dart
// Tests HCL interface-port registration helpers.
//
// 2026 October 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Payload extends LogicStructure {
  Logic get data => elements[0];
  Logic get last => elements[1];

  _Payload({String name = 'payload'})
      : super(
          [
            Logic(name: 'data', width: 8),
            Logic(name: 'last'),
          ],
          name: name,
        );

  _Payload._clone(LogicStructure original, {String? name})
      : super(
          original.elements.map((element) => element.clone()).toList(),
          name: name ?? original.name,
        );

  @override
  _Payload clone({String? name}) => _Payload._clone(this, name: name);
}

class _DifferentPayload extends LogicStructure {
  _DifferentPayload({String name = 'payload'})
      : super(
          [
            Logic(name: 'data', width: 4),
            Logic(name: 'last', width: 5),
          ],
          name: name,
        );

  _DifferentPayload._clone(LogicStructure original, {String? name})
      : super(
          original.elements.map((element) => element.clone()).toList(),
          name: name ?? original.name,
        );

  @override
  _DifferentPayload clone({String? name}) =>
      _DifferentPayload._clone(this, name: name);
}

class _SelectedInterfaceModule extends Module {
  late final ReadyValidInterface<_Payload> channel;

  _SelectedInterfaceModule(ReadyValidInterface<_Payload> source) {
    channel = addInterface(
      source,
      inputTags: {PairDirection.fromProvider},
      outputTags: {PairDirection.fromConsumer},
      uniquify: (original) => 'selected_$original',
    );
  }
}

class _PairInterfaceModule extends Module {
  late final ReadyValidInterface<_Payload> channel;

  _PairInterfaceModule(ReadyValidInterface<_Payload> source) {
    channel = addPairInterface(
      source,
      PairRole.consumer,
      uniquify: (original) => 'pair_$original',
    );
  }
}

class _RetypedPairModule extends Module {
  late final IrrevocableReadyValidInterface<_Payload> channel;

  _RetypedPairModule(ReadyValidInterface<_Payload> source) {
    channel = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(source.data.clone()),
      source,
      PairRole.consumer,
      uniquify: (original) => 'retyped_$original',
    );
  }
}

class _GenericRetypedPairModule<LogicType extends Logic> extends Module {
  late final ReadyValidInterface<LogicType> channel;

  _GenericRetypedPairModule({
    required ReadyValidInterface<LogicType> target,
    required PairInterface source,
    required PairRole role,
  }) {
    channel = addPairInterfaceFrom(
      target,
      source,
      role,
      uniquify: (original) => 'retyped_$original',
    );
  }
}

PairInterface _plainReadyValidInterface({int payloadWidth = 9}) =>
    PairInterface(
      portsFromProvider: [
        Logic(name: 'payload', width: payloadWidth),
        Logic(name: 'valid'),
      ],
      portsFromConsumer: [Logic(name: 'ready')],
    );

class _NestedPairModule extends Module {
  late final ReadyValidInterface<_Payload> channel;
  late final _PairInterfaceModule child;

  _NestedPairModule(ReadyValidInterface<_Payload> source)
      : super(definitionName: 'NestedPairInterfaceHarness') {
    channel = addPairInterface(
      source,
      PairRole.consumer,
      uniquify: (original) => 'parent_$original',
    );
    child = _PairInterfaceModule(channel);
  }
}

void main() {
  tearDown(Simulator.reset);

  test('addInterface registers selected typed structure ports', () async {
    final source = ReadyValidInterface<_Payload>(
      _Payload(),
      contract: ReadyValidContract.irrevocable,
    );
    final module = _SelectedInterfaceModule(source);

    expect(module.inputs['selected_payload'], isA<_Payload>());
    expect(module.inputs.keys, contains('selected_valid'));
    expect(module.outputs.keys, contains('selected_ready'));
    expect(module.channel.data, isNot(same(source.data)));
    expect(module.channel.contract, ReadyValidContract.irrevocable);

    await module.build();
    expect(
      module.generateSynth(),
      contains('input logic [8:0] selected_payload'),
    );
    expect(module.generateSynth(), contains('payload_data'));
    expect(module.generateSynth(), contains('payload_last'));
  });

  test('addPairInterface registers the selected role', () {
    final source = ReadyValidInterface<_Payload>(_Payload());
    final module = _PairInterfaceModule(source);

    expect(module.inputs['pair_payload'], isA<_Payload>());
    expect(module.inputs.keys, contains('pair_valid'));
    expect(module.outputs.keys, contains('pair_ready'));
    expect(module.channel.data, isNot(same(source.data)));
  });

  test('addPairInterfaceFrom supports intentional interface retyping', () {
    final source = ReadyValidInterface<_Payload>(_Payload());
    final module = _RetypedPairModule(source);

    expect(module.channel, isA<IrrevocableReadyValidInterface<_Payload>>());
    expect(module.channel.contract, ReadyValidContract.irrevocable);
    expect(module.inputs['retyped_payload'], isA<_Payload>());
    expect(module.inputs.keys, contains('retyped_valid'));
    expect(module.outputs.keys, contains('retyped_ready'));
  });

  for (final role in PairRole.values) {
    test('addPairInterfaceFrom bridges plain source to typed target as $role',
        () async {
      final source = _plainReadyValidInterface();
      final module = _GenericRetypedPairModule<_Payload>(
        target: ReadyValidInterface<_Payload>(_Payload()),
        source: source,
        role: role,
      );

      final payloadPort = role == PairRole.consumer
          ? module.inputs['retyped_payload']
          : module.outputs['retyped_payload'];
      expect(payloadPort, isA<_Payload>());
      await module.build();
      final systemVerilog = module.generateSynth();
      expect(
        systemVerilog,
        contains(
          '${role == PairRole.consumer ? 'input' : 'output'} '
          'logic [8:0] retyped_payload',
        ),
      );
      expect(systemVerilog, contains('payload_data'));
      expect(systemVerilog, contains('payload_last'));

      if (role == PairRole.consumer) {
        source.port('payload').inject(0x15a);
        await Simulator.tick();
        expect(module.channel.data.data.value.toInt(), 0x5a);
        expect(module.channel.data.last.value, LogicValue.one);
      } else {
        module.channel.data.data.inject(0xa5);
        module.channel.data.last.inject(1);
        await Simulator.tick();
        expect(source.port('payload').value.toInt(), 0x1a5);
      }
    });

    test('addPairInterfaceFrom bridges typed source to plain target as $role',
        () async {
      final source = ReadyValidInterface<_Payload>(_Payload());
      final module = _GenericRetypedPairModule<Logic>(
        target: ReadyValidInterface<Logic>(
          Logic(name: 'payload', width: 9),
        ),
        source: source,
        role: role,
      );

      final payloadPort = role == PairRole.consumer
          ? module.inputs['retyped_payload']
          : module.outputs['retyped_payload'];
      expect(payloadPort, isA<Logic>());
      await module.build();
      expect(
        module.generateSynth(),
        contains(
          '${role == PairRole.consumer ? 'input' : 'output'} '
          'logic [8:0] retyped_payload',
        ),
      );
      if (role == PairRole.consumer) {
        source.data.data.inject(0x3c);
        source.data.last.inject(1);
        await Simulator.tick();
        expect(module.channel.data.value.toInt(), 0x13c);
      } else {
        module.channel.data.inject(0x17e);
        await Simulator.tick();
        expect(source.data.data.value.toInt(), 0x7e);
        expect(source.data.last.value, LogicValue.one);
      }
    });
  }

  test('addPairInterfaceFrom rejects an incompatible payload width', () {
    expect(
      () => _GenericRetypedPairModule<_Payload>(
        target: ReadyValidInterface<_Payload>(_Payload()),
        source: _plainReadyValidInterface(payloadWidth: 8),
        role: PairRole.consumer,
      ),
      throwsA(
        isA<PortTypeException>().having(
          (error) => error.toString(),
          'message',
          contains('payload width 9'),
        ),
      ),
    );
  });

  test('addPairInterfaceFrom rejects an incompatible declared shape', () {
    expect(
      () => _GenericRetypedPairModule<_Payload>(
        target: ReadyValidInterface<_Payload>(_Payload()),
        source: ReadyValidInterface<_DifferentPayload>(_DifferentPayload()),
        role: PairRole.consumer,
      ),
      throwsA(
        isA<PortTypeException>().having(
          (error) => error.toString(),
          'message',
          contains('payload shape'),
        ),
      ),
    );
  });

  test('helper registrations build through a nested hierarchy', () async {
    final module = _NestedPairModule(
      ReadyValidInterface<_Payload>(_Payload()),
    );

    await module.build();
    expect(module.hierarchyString(), contains('_PairInterfaceModule'));
    final systemVerilog = module.generateSynth();
    expect(systemVerilog, contains('NestedPairInterfaceHarness'));
    expect(systemVerilog, contains('input logic [8:0] parent_payload'));
    expect(systemVerilog, contains('pair_payload_data'));
  });
}
