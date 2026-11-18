// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// prbs_test.dart
// Tests for PRBS generation and checking.
//
// 2026 November 14
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

int _advance(int state) => (state >> 1) | (((state ^ (state >> 1)) & 1) << 2);

int _word(int state) => (state & 1) | ((_advance(state) & 1) << 1);

class _PrbsHarness extends Module {
  _PrbsHarness() {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final enable = addInput('enable', Logic());
    final clear = addInput('clear', Logic());
    final data = addInput('data', Logic(width: 2), width: 2);
    final configuration = PrbsConfiguration(
      polynomial: BinaryPolynomial(BigInt.from(11)),
      seed: BigInt.from(7),
    );
    final generator = PrbsGenerator(
      clk: clk,
      reset: reset,
      enable: enable,
      configuration: configuration,
      bitsPerCycle: 2,
    );
    final checker = PrbsChecker(
      clk: clk,
      reset: reset,
      enable: enable,
      clearErrors: clear,
      dataIn: data,
      configuration: configuration,
      bitsPerCycle: 2,
      lockThreshold: 2,
      errorCountWidth: 2,
    );
    addOutput('generated', width: 2) <= generator.dataOut;
    addOutput('expected', width: 2) <= checker.expectedData;
    addOutput('locked') <= checker.locked;
    addOutput('errors', width: 2) <= checker.errorCount;
  }
}

void main() {
  tearDown(Simulator.reset);

  test('parallel sequence, lock, enable, errors and clear match RTL', () async {
    final dut = _PrbsHarness();
    await dut.build();
    var state = 7;
    var matches = 0;
    var locked = false;
    var errors = 0;
    final vectors = <Vector>[];

    void cycle(
        {bool reset = false,
        bool enable = true,
        bool clear = false,
        int corrupt = 0}) {
      final data = _word(state) ^ corrupt;
      final inputs = {
        'reset': reset ? 1 : 0,
        'enable': enable ? 1 : 0,
        'clear': clear ? 1 : 0,
        'data': data,
      };
      vectors
        ..add(Vector({'clk': 0, ...inputs}, {}))
        ..add(Vector({'clk': 1, ...inputs}, {}));
      if (reset) {
        state = 7;
        matches = 0;
        locked = false;
        errors = 0;
      } else {
        if (clear) {
          errors = 0;
        } else if (enable) {
          errors += (corrupt & 1) + ((corrupt >> 1) & 1);
          if (errors > 3) {
            errors = 3;
          }
        }
        if (enable) {
          if (corrupt != 0) {
            matches = 0;
            locked = false;
          } else if (!locked) {
            matches++;
            if (matches == 2) {
              locked = true;
            }
          }
          state = _advance(_advance(state));
        }
      }
      vectors.add(Vector({
        'clk': 0,
        ...inputs
      }, {
        'generated': _word(state),
        'expected': _word(state),
        'locked': locked ? 1 : 0,
        'errors': errors,
      }));
    }

    cycle(reset: true);
    cycle();
    cycle(enable: false, corrupt: 3);
    cycle();
    cycle(corrupt: 1);
    cycle();
    cycle();
    cycle(corrupt: 3);
    cycle(corrupt: 3);
    cycle(clear: true, corrupt: 1);
    cycle();
    cycle(reset: true);

    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });
}
