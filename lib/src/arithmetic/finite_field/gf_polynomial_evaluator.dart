// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// gf_polynomial_evaluator.dart
// Implementation of Gf Polynomial Evaluator.
//
// 2026 September 5
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/finite_field/binary_extension_field.dart';
import 'package:rohd_hcl/src/arithmetic/finite_field/gf_logic.dart';
import 'package:rohd_hcl/src/arithmetic/finite_field/gf_value.dart';

/// Combinational Horner evaluator for a GF polynomial.
///
/// `coefficients` are ordered from highest degree to constant term.
class GfPolynomialEvaluator extends Module {
  /// The evaluated polynomial value.
  Logic get result => output('result');

  /// Creates a finite-field polynomial evaluator.
  GfPolynomialEvaluator(
    Logic input, {
    required BinaryExtensionField field,
    required List<GfValue> coefficients,
    super.name = 'gf_polynomial_evaluator',
  }) : super(
          definitionName:
              'GfPolynomialEvaluator_D${field.degree}_N${coefficients.length}',
        ) {
    if (coefficients.isEmpty) {
      throw ArgumentError('A polynomial requires at least one coefficient.');
    }
    for (final coefficient in coefficients) {
      field.requireCompatible(coefficient.field);
    }
    if (input.width != field.degree) {
      throw ArgumentError('Input width must equal the field degree.');
    }
    final localInput = GfLogic.of(
      addInput('dataIn', input, width: input.width),
      field: field,
    );
    var value = GfLogic.constant(coefficients.first);
    for (final coefficient in coefficients.skip(1)) {
      value = (value * localInput) + GfLogic.constant(coefficient);
    }
    addOutput('result', width: field.degree) <= value;
  }
}
