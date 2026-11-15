// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// mux_test.dart
// Tests for OneHotMux and PriorityMux.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Payload extends LogicStructure {
  _Payload({String name = 'payload', String tagName = 'tag'})
      : super([Logic(name: tagName, width: 2), Logic(name: 'value', width: 2)],
            name: name);

  @override
  _Payload clone({String? name}) =>
      _Payload(name: name ?? this.name, tagName: elements.first.name);
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  const caseWidth = 4;
  const numCases = 3;
  // Overlapping bit patterns so the OR and the priority ordering both show.
  const cases = [0x3, 0xC, 0x6];

  test('OneHotMux ORs the cases whose selector bit is set', () async {
    final selector = Logic(name: 'selector', width: numCases);
    final inputs = [
      for (var i = 0; i < numCases; i++) Logic(name: 'case$i', width: caseWidth)
    ];
    final dut = OneHotMux(selector, inputs);
    await dut.build();

    // Every selector value: none set, each single bit, and all set.
    final vectors = [
      for (var sel = 0; sel < (1 << numCases); sel++)
        Vector({
          'selector': sel,
          for (var i = 0; i < numCases; i++) 'case$i': cases[i],
        }, {
          'result': [
            for (var i = 0; i < numCases; i++)
              if ((sel >> i) & 1 == 1) cases[i]
          ].fold(0, (a, b) => a | b),
        })
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
  });

  test('OneHotMux rejects invalid case and selector widths', () {
    expect(
      () => OneHotMux(Logic(), []),
      throwsA(predicate(
          (e) => e is Exception && e.toString().contains('At least one case'))),
    );
    expect(
      () => OneHotMux(Logic(width: 2), [Logic(width: 2), Logic(width: 3)]),
      throwsA(isA<Exception>()),
    );
    expect(
      () => OneHotMux(Logic(), [Logic(width: 2), Logic(width: 2)]),
      throwsA(isA<Exception>()),
    );
  });

  test('PriorityMux picks the lowest set selector bit, else the default',
      () async {
    const defaultValue = 0xE;
    final selector = Logic(name: 'selector', width: numCases);
    final inputs = [
      for (var i = 0; i < numCases; i++) Logic(name: 'case$i', width: caseWidth)
    ];
    final dflt = Logic(name: 'defaultValue', width: caseWidth);
    // Exercise the existing flat compatibility API.
    // ignore: deprecated_member_use_from_same_package
    final dut = PriorityMux(selector, inputs, dflt);
    await dut.build();

    final vectors = [
      for (var sel = 0; sel < (1 << numCases); sel++)
        Vector({
          'selector': sel,
          'defaultValue': defaultValue,
          for (var i = 0; i < numCases; i++) 'case$i': cases[i],
        }, {
          'result': sel == 0
              ? defaultValue
              : cases[[
                  for (var i = 0; i < numCases; i++)
                    if ((sel >> i) & 1 == 1) i
                ].first],
        })
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
  });

  test('typed priority mux preserves structured cases and result', () async {
    final selector = Logic(width: 2);
    final dut = TypedPriorityMux<_Payload>(
        selector, [_Payload(), _Payload()], _Payload());
    expect(dut.input('case0'), isA<_Payload>());
    expect(dut.input('defaultValue'), isA<_Payload>());
    expect(dut.result, isA<_Payload>());
    await dut.build();
    final vectors = [
      Vector({'selector': 0, 'case0': 3, 'case1': 12, 'defaultValue': 5},
          {'result': 5}),
      Vector({'selector': 2}, {'result': 12}),
      Vector({'selector': 3}, {'result': 3}),
      Vector({'selector': LogicValue.ofString('x0')},
          {'result': LogicValue.ofString('x10x')}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('typed priority mux rejects incompatible payload layouts', () {
    expect(
      () => TypedPriorityMux<_Payload>(
          Logic(), [_Payload(tagName: 'other')], _Payload()),
      throwsArgumentError,
    );
  });

  test('legacy priority mux keeps flat structured inputs and result', () {
    // Verify the compatibility API with structured caller signals.
    // ignore: deprecated_member_use_from_same_package
    final dut = PriorityMux(Logic(), [_Payload()], _Payload());
    expect(dut.input('case0'), isNot(isA<LogicStructure>()));
    expect(dut.result, isNot(isA<LogicStructure>()));
    expect(identical(dut.result, dut.output('result')), isTrue);
  });
}
