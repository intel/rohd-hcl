// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// inference_numeric_format_test.dart
// Tests for Inference Numeric Format.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('constructs stable integer, fixed, and floating formats', () {
    final signedInteger = InferenceNumericFormat.signedInteger(
      4,
      accumulatorWidth: 24,
    );
    final fixed = InferenceNumericFormat.fixedPoint(
      signed: true,
      integerWidth: 3,
      fractionWidth: 4,
    );
    final floating = InferenceNumericFormat.floatingPoint(
      exponentWidth: 4,
      mantissaWidth: 3,
    );
    final blockScaled = InferenceNumericFormat.blockScaled(
      elementWidth: 4,
      signed: true,
      scaleKind: InferenceScaleKind.sharedExponent,
      scaleWidth: 8,
      groupSize: 32,
      accumulatorWidth: 24,
    );

    expect(signedInteger.elementWidth, 4);
    expect(signedInteger.productWidth, 8);
    expect(signedInteger.accumulatorWidth, 24);
    expect(signedInteger.signed, isTrue);
    expect(fixed.elementWidth, 8);
    expect(fixed.integerWidth, 3);
    expect(fixed.fractionWidth, 4);
    expect(floating.elementWidth, 8);
    expect(floating.exponentWidth, 4);
    expect(floating.mantissaWidth, 3);
    expect(blockScaled.groupSize, 32);
    expect(blockScaled.scaleWidth, 8);
    expect(blockScaled.accumulatorWidth, 24);
    expect(
      signedInteger.configurationSignature,
      contains('signedInteger_E4_P8_A24'),
    );
    expect(
      InferenceNumericFormat.signedInteger(4, accumulatorWidth: 24),
      signedInteger,
    );
  });

  test('validates scale and representation metadata', () {
    expect(
      () => InferenceNumericFormat(
        elementKind: InferenceElementKind.blockScaled,
        elementWidth: 4,
        productWidth: 8,
        accumulatorWidth: 16,
        signed: true,
      ),
      throwsArgumentError,
    );
    expect(
      () => InferenceNumericFormat.fixedPoint(
        signed: true,
        integerWidth: -1,
        fractionWidth: 4,
      ),
      throwsArgumentError,
    );
    expect(
      () => InferenceNumericFormat.floatingPoint(
        exponentWidth: 0,
        mantissaWidth: 3,
      ),
      throwsArgumentError,
    );
    expect(
      () => InferenceNumericFormat.signedInteger(
        8,
        accumulatorWidth: 7,
      ),
      throwsArgumentError,
    );
  });
}
