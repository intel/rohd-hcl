// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// pooling_window_sequencer_test.dart
// Tests for pooling-window traversal and runtime splits.
//
// 2026 November 23
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(Simulator.reset);

  for (final (mode, count) in [
    ('without split inputs', null),
    ('with runtime splits disabled', 0),
    ('with runtime splits enabled', 2),
    ('with incomplete split inputs', -1),
  ]) {
    test('pooling windows $mode', () async {
      final split = count == 2;
      final hasSplitInputs = count != null && count >= 0;
      final incomplete = count == -1;
      PoolingWindowSequencer build() => PoolingWindowSequencer(
            clk: Logic(),
            reset: Logic(),
            restart: Logic(),
            advanceTerm: Logic(),
            advanceOutput: Logic(),
            inputWidth: Logic(width: 4),
            inputHeight: Logic(width: 4),
            outputWidth: Logic(width: 4),
            outputHeight: Logic(width: 4),
            groups: Logic(width: 4),
            kernelWidth: Logic(width: 4),
            kernelHeight: Logic(width: 4),
            strideX: Logic(width: 4),
            strideY: Logic(width: 4),
            padLeft: Logic(width: 4),
            padTop: Logic(width: 4),
            splitCount: hasSplitInputs || incomplete ? Logic(width: 4) : null,
            outputWidthFirst: hasSplitInputs ? Logic(width: 4) : null,
            outputWidthMiddle: hasSplitInputs ? Logic(width: 4) : null,
            outputWidthLast: hasSplitInputs ? Logic(width: 4) : null,
          );
      if (incomplete) {
        expect(build, throwsArgumentError);
        return;
      }
      final dut = build();
      await dut.build();
      expect(dut.inputs.containsKey('splitCount'), hasSplitInputs);
      final inputs = <String, int>{
        'clk': 0,
        'reset': 1,
        'restart': 0,
        'advanceTerm': 0,
        'advanceOutput': 0,
        'inputWidth': 5,
        'inputHeight': 3,
        'outputWidth': 5,
        'outputHeight': 2,
        'groups': 2,
        'kernelWidth': 3,
        'kernelHeight': 2,
        'strideX': 1,
        'strideY': 2,
        'padLeft': 1,
        'padTop': 1,
        if (hasSplitInputs) ...{
          'splitCount': count,
          'outputWidthFirst': 2,
          'outputWidthMiddle': 1,
          'outputWidthLast': 2,
        },
      };
      final vectors = <Vector>[];
      void vector(int clk, [Map<String, dynamic> expected = const {}]) {
        inputs['clk'] = clk;
        vectors.add(Vector(Map.of(inputs), expected));
      }

      vector(0);
      vector(1);
      inputs['reset'] = 0;
      inputs['advanceTerm'] = 1;
      vector(0, {'kernelX': 0, 'kernelY': 0});
      vector(1);
      inputs['restart'] = 1;
      vector(0, {'kernelX': 1});
      vector(1);
      inputs['restart'] = 0;

      final widths = split ? [2, 1, 2] : [5];
      var offset = 0;
      for (var s = 0; s < widths.length; s++) {
        for (var group = 0; group < 2; group++) {
          for (var y = 0; y < 2; y++) {
            for (var x = 0; x < widths[s]; x++) {
              for (var ky = 0; ky < 2; ky++) {
                for (var kx = 0; kx < 3; kx++) {
                  final ix = offset + x + kx - 1;
                  final iy = y * 2 + ky - 1;
                  final inside = ix >= 0 && ix < 5 && iy >= 0 && iy < 3;
                  final expected = <String, dynamic>{
                    'x': x,
                    'y': y,
                    'group': group,
                    'split': s,
                    'kernelX': kx,
                    'kernelY': ky,
                    'outputX': offset + x,
                    'inBounds': inside ? 1 : 0,
                    if (inside) ...{'inputX': ix, 'inputY': iy},
                    'lastTerm': kx == 2 && ky == 1 ? 1 : 0,
                    'lastOutput': s == widths.length - 1 &&
                            group == 1 &&
                            y == 1 &&
                            x == widths[s] - 1
                        ? 1
                        : 0,
                  };
                  if (x == 0 && y == 0 && group == 0 && kx == 1 && ky == 0) {
                    inputs['advanceTerm'] = 0;
                    vector(0, expected);
                    vector(1);
                  }
                  inputs['advanceTerm'] = 1;
                  vector(0, expected);
                  vector(1);
                }
              }
              inputs['advanceTerm'] = 0;
              inputs['advanceOutput'] = 1;
              vector(0);
              vector(1);
              inputs['advanceOutput'] = 0;
            }
          }
        }
        offset += widths[s];
      }
      inputs['restart'] = 1;
      inputs['advanceOutput'] = 1;
      vector(0);
      vector(1);
      inputs['restart'] = 0;
      inputs['advanceOutput'] = 0;
      vector(0, {
        'x': 0,
        'y': 0,
        'group': 0,
        'split': 0,
        'kernelX': 0,
        'kernelY': 0,
      });
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }
}
