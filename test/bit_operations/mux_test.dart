// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// select_test.dart
// Tests for OneHotMux and PriorityMux.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

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

  test('PriorityMux picks the lowest set selector bit, else the default',
      () async {
    const defaultValue = 0xE;
    final selector = Logic(name: 'selector', width: numCases);
    final inputs = [
      for (var i = 0; i < numCases; i++) Logic(name: 'case$i', width: caseWidth)
    ];
    final dflt = Logic(name: 'defaultValue', width: caseWidth);
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
}
