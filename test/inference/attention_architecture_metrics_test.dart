// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// attention_architecture_metrics_test.dart
// Tests for Attention Architecture Metrics.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('compares register-captured and scratchpad numeric traffic', () {
    const metrics = FixedPointAttentionTrafficModel(
      sequenceLength: 3,
      headDimension: 2,
      valueDimension: 2,
      elementWidth: 4,
      valueWidth: 8,
      scoreWidth: 6,
    );

    expect(metrics.queryBytes, 1);
    expect(metrics.keyRowBytes, 1);
    expect(metrics.valueRowBytes, 2);
    expect(metrics.registerCapturedCommandBytes, 10);
    expect(metrics.scratchpadCommandBytes, 1);
    expect(metrics.scratchpadReadBytes, 9);
    expect(metrics.scratchpadTotalBytes, 10);
    expect(metrics.commandByteReduction, 9);
    expect(metrics.maximumAvoidedScoreWriteBytes, 3);
  });

  test('accounts for byte padding on independently packed rows', () {
    const metrics = FixedPointAttentionTrafficModel(
      sequenceLength: 2,
      headDimension: 3,
      valueDimension: 2,
      elementWidth: 3,
      valueWidth: 5,
      scoreWidth: 9,
    );

    expect(metrics.registerCapturedCommandBytes, 6);
    expect(metrics.scratchpadCommandBytes, 2);
    expect(metrics.scratchpadReadBytes, 8);
    expect(metrics.scratchpadTotalBytes, 10);
    expect(metrics.commandByteReduction, 4);
    expect(metrics.maximumAvoidedScoreWriteBytes, 4);
  });
}
