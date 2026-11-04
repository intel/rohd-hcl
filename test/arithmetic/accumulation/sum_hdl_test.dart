// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sum_hdl_test.dart
// HDL tests for sum components.
//
// 2026 November 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

import '../../verilator_test_utils.dart';

class _SumHarness extends Module {
  _SumHarness({required bool runtimeBounds, required bool saturates}) {
    final initial = addInput('initialValue', Logic(width: 4), width: 4);
    final increment = addInput('increment', Logic(width: 4), width: 4);
    final decrement = addInput('decrement', Logic(width: 4), width: 4);
    final incrementEnable = addInput('incrementEnable', Logic());
    final decrementEnable = addInput('decrementEnable', Logic());
    final min =
        runtimeBounds ? addInput('min', Logic(width: 4), width: 4) : null;
    final max =
        runtimeBounds ? addInput('max', Logic(width: 4), width: 4) : null;
    final sum = Sum(
      [
        SumInterface(width: 4, hasEnable: true)
          ..amount.gets(increment)
          ..enable!.gets(incrementEnable),
        SumInterface(width: 4, increments: false, hasEnable: true)
          ..amount.gets(decrement)
          ..enable!.gets(decrementEnable),
      ],
      width: 4,
      initialValue: initial,
      minValue: min ?? 2,
      maxValue: max ?? 5,
      saturates: saturates,
    );
    addOutput('sum', width: 4) <= sum.sum;
    addOutput('overflowed') <= sum.overflowed;
    addOutput('underflowed') <= sum.underflowed;
    addOutput('equalsMax') <= sum.equalsMax;
    addOutput('equalsMin') <= sum.equalsMin;
  }
}

void main() {
  tearDown(Simulator.reset);

  for (final runtimeBounds in [false, true]) {
    for (final saturates in [false, true]) {
      test('sum HDL runtimeBounds=$runtimeBounds saturates=$saturates',
          () async {
        final dut =
            _SumHarness(runtimeBounds: runtimeBounds, saturates: saturates);
        await dut.build();
        final vectors = <Vector>[];
        void add(int initial, int increment, int decrement, int incEn,
            int decEn, int wrapped, int saturated,
            {int min = 2, int max = 5, int overflow = 0, int underflow = 0}) {
          final result = saturates ? saturated : wrapped;
          vectors.add(Vector({
            'initialValue': initial,
            'increment': increment,
            'decrement': decrement,
            'incrementEnable': incEn,
            'decrementEnable': decEn,
            if (runtimeBounds) 'min': min,
            if (runtimeBounds) 'max': max,
          }, {
            'sum': result,
            'overflowed': overflow,
            'underflowed': underflow,
            'equalsMax': result == max ? 1 : 0,
            'equalsMin': result == min ? 1 : 0,
          }));
        }

        add(4, 2, 0, 1, 0, 2, 5, overflow: 1);
        add(2, 0, 1, 0, 1, 5, 2, underflow: 1);
        add(3, 15, 0, 1, 0, 2, 5, overflow: 1);
        add(3, 0, 15, 0, 1, 4, 2, underflow: 1);
        add(4, 6, 3, 0, 0, 4, 4);
        add(3, 4, 2, 1, 1, 5, 5);
        if (runtimeBounds) {
          add(6, 3, 0, 1, 0, 3, 6, min: 1, max: 6, overflow: 1);
          add(1, 0, 8, 0, 1, 5, 1, min: 1, max: 6, underflow: 1);
        }

        await SimCompare.checkFunctionalVector(dut, vectors);
        SimCompare.checkIverilogVector(dut, vectors);
        expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);

        expectNoVerilatorWarnings(dut, ['UNOPTFLAT', 'WIDTHEXPAND']);
      });
    }
  }

  test('unknown enable remains pessimistic in functional simulation', () {
    final dut = _SumHarness(runtimeBounds: false, saturates: false);
    dut.input('initialValue').put(3);
    dut.input('increment').put(0);
    dut.input('decrement').put(0);
    dut.input('incrementEnable').put(LogicValue.x);
    dut.input('decrementEnable').put(0);
    expect(dut.output('sum').value.isValid, isFalse);
  });
}
