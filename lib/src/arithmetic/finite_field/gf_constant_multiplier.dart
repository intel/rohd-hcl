// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// gf_constant_multiplier.dart
// Implementation of Gf Constant Multiplier.
//
// 2026 September 5
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/finite_field/binary_extension_field.dart';
import 'package:rohd_hcl/src/arithmetic/finite_field/gf_value.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_affine_transform.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_linear_transform.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_matrix.dart';

/// Combinational multiplication by a compile-time GF constant.
///
/// This is intentionally a general field primitive; BCH and Reed-Solomon
/// implementations can choose it wherever a constant multiplier is needed.
class GfConstantMultiplier extends Module {
  /// The field used by this multiplier.
  final BinaryExtensionField field;

  /// The compile-time multiplier.
  final GfValue constant;

  /// The binary linear transform implementing the multiplication.
  late final BinaryAffineTransform transform;

  /// The multiplied field element.
  Logic get result => output('result');

  /// Creates a constant finite-field multiplier.
  GfConstantMultiplier(
    Logic input, {
    required BinaryExtensionField field,
    required GfValue constant,
    super.name = 'gf_constant_multiplier',
  })  : field = field,
        constant = constant,
        super(
          definitionName: 'GfConstantMultiplier_D${field.degree}_C'
              '${constant.value.toRadixString(16)}',
        ) {
    field.requireCompatible(constant.field);
    if (input.width != field.degree) {
      throw ArgumentError('Input width must equal the field degree.');
    }
    transform = _multiplicationTransform(field, constant);
    final multiplier = BinaryLinearTransform(
      input,
      matrix: transform.matrix,
      definitionName: 'GfConstantMultiplierTransform_'
          '${transform.configurationSignature}',
    );
    addOutput('result', width: field.degree) <= multiplier.result;
  }

  static BinaryAffineTransform _multiplicationTransform(
    BinaryExtensionField field,
    GfValue constant,
  ) {
    final rows = <BigInt>[];
    for (var row = 0; row < field.degree; row++) {
      var mask = BigInt.zero;
      for (var column = 0; column < field.degree; column++) {
        final product = field.elementFromInt(1 << column) * constant;
        if (((product.value >> row) & BigInt.one) == BigInt.one) {
          mask |= BigInt.one << column;
        }
      }
      rows.add(mask);
    }
    return BinaryAffineTransform(
      BinaryMatrix(rows, columnCount: field.degree),
    );
  }
}
