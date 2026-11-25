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
  /// The evaluated polynomial value as a plain bit vector.
  @Deprecated('Use gfResult for field-typed operations.')
  Logic get result => _legacyResult;

  /// The evaluated polynomial value.
  late final GfLogic gfResult;
  late final Logic _legacyResult;

  /// Creates an evaluator from a plain bit-vector input.
  @Deprecated('Use GfPolynomialEvaluator.typed with a field-typed input.')
  GfPolynomialEvaluator(
    Logic input, {
    required BinaryExtensionField field,
    required List<GfValue> coefficients,
    String name = 'gf_polynomial_evaluator',
  }) : this._(input,
            field: field,
            coefficients: coefficients,
            name: name,
            typedPorts: false);

  /// Creates a polynomial evaluator for the input field.
  GfPolynomialEvaluator.typed(GfLogic input,
      {required List<GfValue> coefficients,
      String name = 'gf_polynomial_evaluator'})
      : this._(input,
            field: input.field,
            coefficients: coefficients,
            name: name,
            typedPorts: true);

  GfPolynomialEvaluator._(Logic input,
      {required BinaryExtensionField field,
      required List<GfValue> coefficients,
      required super.name,
      required bool typedPorts})
      : super(
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
    final localInput = typedPorts
        ? addTypedInput('dataIn', GfLogic.of(input, field: field))
        : GfLogic.of(addInput('dataIn', input, width: input.width),
            field: field);
    var value = GfLogic.constant(coefficients.first);
    for (final coefficient in coefficients.skip(1)) {
      value = (value * localInput) + GfLogic.constant(coefficient);
    }
    GfLogic resultSchema({String? name}) => GfLogic(field, name: name);
    if (typedPorts) {
      gfResult = addTypedOutput<GfLogic>('result', resultSchema);
      _legacyResult = Logic(name: 'result', width: field.degree)
        ..gets(gfResult);
      gfResult <= value;
    } else {
      _legacyResult = addOutput('result', width: field.degree);
      gfResult = GfLogic.of(_legacyResult, field: field);
      _legacyResult <= value;
    }
  }
}
