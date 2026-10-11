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
