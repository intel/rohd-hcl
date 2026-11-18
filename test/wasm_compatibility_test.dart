// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// wasm_compatibility_test.dart
// Checks public HCL APIs in Dart-to-Wasm runtimes.
//
// 2026 November 16
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Payload extends LogicStructure {
  _Payload({String? name})
      : super([Logic(name: 'value', width: 4), Logic(name: 'flag')],
            name: name ?? 'payload');

  @override
  _Payload clone({String? name}) => _Payload(name: name ?? this.name);
}

class _TypedChannel extends Module {
  late final ValidOnlyInterface<_Payload> inputChannel;

  _TypedChannel(ValidOnlyInterface<_Payload> channel) {
    inputChannel = addPairInterfacePorts(channel, PairRole.consumer);
    addOutput('result', width: 4) <= inputChannel.data.elements.first;
  }
}

void main() {
  test('public arithmetic builds and generates SystemVerilog', () async {
    final value = Logic(width: 3)..put(3);
    expect(value.binaryToOneHot().value.toInt(), 8);

    final accumulator =
        Accumulator(Logic(width: 8), clk: Logic(), reset: Logic(), width: 8);
    await accumulator.build();
    expect(accumulator.dumpSystemVerilog(), contains('module'));
  });

  test('typed channel ports retain their payload in simulation', () async {
    final payload = _Payload();
    final channel = ValidOnlyInterface(payload);
    final dut = _TypedChannel(channel);
    await dut.build();
    payload.elements.first.put(9);
    expect(dut.inputChannel.data, isA<_Payload>());
    expect(dut.output('result').value.toInt(), 9);
    expect(dut.dumpSystemVerilog(), contains('module'));
  });
}
