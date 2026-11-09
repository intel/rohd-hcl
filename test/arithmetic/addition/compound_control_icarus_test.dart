// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// compound_control_icarus_test.dart
// Verify different subtraction configurations in generated HDL.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _CompoundControlHarness extends Module {
  _CompoundControlHarness(Logic a, Logic b, Logic subtract) {
    final localA = addInput('a', a, width: a.width);
    final localB = addInput('b', b, width: b.width);
    final localSubtract = addInput('subtract', subtract);
    final add = CarrySelectOnesComplementCompoundAdder(localA, localB);
    final sub = CarrySelectOnesComplementCompoundAdder(localA, localB,
        subtract: StaticOrRuntimeParameter.staticValue(value: true));
    final runtime = CarrySelectOnesComplementCompoundAdder(localA, localB,
        subtract: StaticOrRuntimeParameter.fromLogic(localSubtract,
            fallbackName: 'subtract'));
    final alternate = CarrySelectOnesComplementCompoundAdder(localA, localB,
        subtract: StaticOrRuntimeParameter(
            name: 'alternateSubtract', runtimeConfig: localSubtract));
    final legacy = CarrySelectOnesComplementCompoundAdder(localA, localB,
        // Verify the legacy runtime port alongside the unified form.
        // ignore: deprecated_member_use_from_same_package
        subtractIn: localSubtract);
    addOutput('addition', width: add.sum.width) <= add.sum;
    addOutput('subtraction', width: sub.sum.width) <= sub.sum;
    addOutput('selected', width: runtime.sum.width) <= runtime.sum;
    addOutput('alternate', width: alternate.sum.width) <= alternate.sum;
    addOutput('legacy', width: legacy.sum.width) <= legacy.sum;
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('static and runtime subtract configurations coexist in HDL', () async {
    final harness =
        _CompoundControlHarness(Logic(width: 4), Logic(width: 4), Logic());
    await harness.build();
    SimCompare.checkIverilogVector(harness, [
      Vector({
        'a': 7,
        'b': 3,
        'subtract': 0
      }, {
        'addition': 10,
        'subtraction': 4,
        'selected': 10,
        'alternate': 10,
        'legacy': 10
      }),
      Vector({
        'subtract': 1
      }, {
        'addition': 10,
        'subtraction': 4,
        'selected': 4,
        'alternate': 4,
        'legacy': 4
      }),
    ]);
  }, skip: _iverilogUnavailableReason());
}

String? _iverilogUnavailableReason() {
  try {
    final result = Process.runSync('iverilog', const ['-V']);
    return result.exitCode == 0 ? null : 'Icarus Verilog is unavailable.';
  } on ProcessException {
    return 'Icarus Verilog is not installed.';
  }
}
