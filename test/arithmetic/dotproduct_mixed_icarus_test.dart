// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// dotproduct_mixed_icarus_test.dart
// Verify mixed-width, runtime-signed dot-product synthesis with Icarus.
//
// 2026 September 19
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('mixed-width runtime-signed dot product compiles in Icarus', () async {
    final dotProduct = GeneralDotProduct(
      [Logic(width: 4), Logic(width: 4)],
      [Logic(width: 3), Logic(width: 3)],
      signedMultiplicand: Logic(name: 'signedMultiplicand'),
      signedMultiplier: Logic(name: 'signedMultiplier'),
      multiplierGen: _compressionTreeMultiplier,
      multiplierIdentity: 'compressionTreeR4',
    );
    await dotProduct.build();
    SimCompare.checkIverilogVector(dotProduct, const [], buildOnly: true);
  });
}

Multiplier _compressionTreeMultiplier(
  Logic a,
  Logic b, {
  Logic? clk,
  Logic? reset,
  Logic? enable,
  dynamic signedMultiplicand,
  dynamic signedMultiplier,
}) =>
    CompressionTreeMultiplier(
      a,
      b,
      clk: clk,
      reset: reset,
      enable: enable,
      signedMultiplicand: signedMultiplicand,
      signedMultiplier: signedMultiplier,
    );
