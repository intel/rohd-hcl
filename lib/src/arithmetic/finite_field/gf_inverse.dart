// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// gf_inverse.dart
// Implementation of Gf Inverse.
//
// 2026 September 5
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/finite_field/binary_extension_field.dart';
import 'package:rohd_hcl/src/arithmetic/finite_field/gf_logic.dart';

/// A combinational finite-field inverse using fixed-exponent powering.
///
/// For non-zero `a`, the circuit computes `a^(|GF| - 2)`. Zero is explicitly
/// mapped to zero rather than inheriting the mathematical convention for
/// exponent zero in the degree-one field.
class GfInverse extends Module {
  /// The inverted field element.
  Logic get result => output('result');

  /// Creates a synthesizable combinational inverse for [field].
  GfInverse(
    Logic input, {
    required BinaryExtensionField field,
    super.name = 'gf_inverse',
  }) : super(
          definitionName: 'GfInverse_D${field.degree}',
        ) {
    if (input.width != field.degree) {
      throw ArgumentError('Input width must equal the field degree.');
    }

    final localInput = GfLogic.of(
      addInput('dataIn', input, width: input.width),
      field: field,
    );
    var exponent = field.size - BigInt.two;
    var power = localInput;
    var inverse = GfLogic.constant(field.one);
    while (exponent > BigInt.zero) {
      if (exponent.isOdd) {
        inverse = inverse * power;
      }
      exponent >>= 1;
      if (exponent > BigInt.zero) {
        power = power * power;
      }
    }

    final isZero = localInput.eq(GfLogic.constant(field.zero));
    addOutput('result', width: field.degree) <=
        mux(isZero, GfLogic.constant(field.zero), inverse);
  }
}
