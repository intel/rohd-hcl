// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// static_or_runtime_parameter_test.dart
// Tests for naming of runtime configuration parameters
//
// 2026 September 21
// Author: Shubham Padkonde <shubhampadkonde12@gmail.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  group('unnamed runtime parameters get distinct input names', () {
    test('on a CompressionTreeMultiplier', () async {
      final mod = CompressionTreeMultiplier(Logic(width: 8), Logic(width: 8),
          signedMultiplicand: Logic(), signedMultiplier: Logic());
      await mod.build();

      expect(mod.inputs.keys,
          containsAll(['signedMultiplicand', 'signedMultiplier']));
    });

    test('on a MultiplyAccumulate', () async {
      final mod = CompressionTreeMultiplyAccumulate(
          Logic(width: 8), Logic(width: 8), Logic(width: 8),
          signedMultiplicand: Logic(),
          signedMultiplier: Logic(),
          signedAddend: Logic());
      await mod.build();

      expect(
          mod.inputs.keys,
          containsAll(
              ['signedMultiplicand', 'signedMultiplier', 'signedAddend']));
    });
  });

  test('a named runtime parameter keeps its own name', () async {
    final mod = CompressionTreeMultiplier(Logic(width: 8), Logic(width: 8),
        signedMultiplicand: Logic(name: 'isSignedA'),
        signedMultiplier: Logic(name: 'isSignedB'));
    await mod.build();

    expect(mod.inputs.keys, containsAll(['isSignedA', 'isSignedB']));
    expect(mod.inputs.keys, isNot(contains('signedMultiplicand')));
  });
}
