// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// valid_only_interface_test.dart
// Tests typed valid-only interface registration.
//
// 2026 November 15
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Payload extends LogicStructure {
  _Payload({String? name})
      : super([Logic(name: 'low', width: 4), Logic(name: 'high', width: 4)],
            name: name ?? 'data');

  @override
  _Payload clone({String? name}) => _Payload(name: name ?? this.name);
}

class _PassThrough<T extends Logic> extends Module {
  _PassThrough(ValidOnlyInterface<T> input, ValidOnlyInterface<T> output) {
    final localInput = addPairInterfacePorts(input, PairRole.consumer,
        uniquify: (name) => 'input_$name');
    final localOutput = addPairInterfacePorts(output, PairRole.provider,
        uniquify: (name) => 'output_$name');
    localOutput.data <= localInput.data;
    localOutput.valid <= localInput.valid;
  }
}

class _Retyped extends Module {
  _Retyped(
      ValidOnlyInterface<_Payload> target, ValidOnlyInterface<Logic> source) {
    addPairInterfaceFrom(target, source, PairRole.consumer);
  }
}

void main() {
  tearDown(Simulator.reset);

  test('registers structured payload ports in both directions', () async {
    final module = _PassThrough(
        ValidOnlyInterface(_Payload()), ValidOnlyInterface(_Payload()));
    await module.build();
    expect(module.input('input_data'), isA<_Payload>());
    expect(module.output('output_data'), isA<_Payload>());
    final vectors = [
      Vector({'input_data': 0xa5, 'input_valid': 1},
          {'output_data': 0xa5, 'output_valid': 1}),
      Vector({'input_data': 0x3c, 'input_valid': 0},
          {'output_data': 0x3c, 'output_valid': 0}),
    ];
    await SimCompare.checkFunctionalVector(module, vectors);
    SimCompare.checkIverilogVector(module, vectors);
  });

  test('preserves unpacked typed array schemas', () async {
    TypedLogicArray<_Payload, LogicValue> array() =>
        TypedLogicArray<_Payload, LogicValue>(
          [2, 2],
          _Payload.new,
          numUnpackedDimensions: 1,
          name: 'data',
        );
    final module =
        _PassThrough(ValidOnlyInterface(array()), ValidOnlyInterface(array()));
    await module.build();
    final input =
        module.input('input_data') as TypedLogicArray<_Payload, LogicValue>;
    final output =
        module.output('output_data') as TypedLogicArray<_Payload, LogicValue>;
    expect(input.dimensions, [2, 2]);
    expect(output.numUnpackedDimensions, 1);
    expect(module.dumpSystemVerilog(), contains('module'));
  });

  test('allows packed bridges and rejects incompatible structured layouts',
      () async {
    final bridged = _Retyped(ValidOnlyInterface(_Payload()),
        ValidOnlyInterface(Logic(name: 'data', width: 8)));
    await bridged.build();
    expect(bridged.input('data'), isA<_Payload>());
    expect(
        () => _Retyped(
              ValidOnlyInterface(_Payload()),
              ValidOnlyInterface(LogicStructure([
                Logic(name: 'other', width: 4),
                Logic(name: 'high', width: 4),
              ], name: 'data')),
            ),
        throwsA(isA<PortTypeException>()));
  });
}
