// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// bitwise_prefix_scan_xz_test.dart
// Four-state tests for directional bitwise prefix scans.
//
// 2026 November 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(Simulator.reset);

  final topologies = <String, ParallelPrefixGenerator<Logic>>{
    'ripple': Ripple<Logic>.new,
    'sklansky': Sklansky<Logic>.new,
    'koggeStone': KoggeStone<Logic>.new,
    'brentKung': BrentKung<Logic>.new,
  };
  final expected = <(PrefixScanOperation, PrefixScanDirection), String>{
    (PrefixScanOperation.and, PrefixScanDirection.lowToHigh): '00x1',
    (PrefixScanOperation.and, PrefixScanDirection.highToLow): '1000',
    (PrefixScanOperation.or, PrefixScanDirection.lowToHigh): '1111',
    (PrefixScanOperation.or, PrefixScanDirection.highToLow): '1111',
    (PrefixScanOperation.xor, PrefixScanDirection.lowToHigh): 'xxx1',
    (PrefixScanOperation.xor, PrefixScanDirection.highToLow): '11xx',
  };
  for (final topology in topologies.entries) {
    for (final entry in expected.entries) {
      test('${topology.key} ${entry.key} preserves four-state semantics',
          () async {
        final dut = ParallelPrefixScan(
          Logic(width: 4),
          operation: entry.key.$1,
          direction: entry.key.$2,
          ppGen: topology.value,
        );
        await dut.build();
        final vectors = [
          for (final bit in ['x', 'z'])
            Vector({'inp': LogicValue.ofString('10${bit}1')},
                {'out': LogicValue.ofString(entry.value)}),
        ];
        await SimCompare.checkFunctionalVector(dut, vectors);
        SimCompare.checkIverilogVector(dut, vectors);
      });
    }
  }
}
