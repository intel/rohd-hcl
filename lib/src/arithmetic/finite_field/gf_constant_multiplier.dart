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
import 'package:rohd_hcl/src/arithmetic/finite_field/gf_logic.dart';
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

  /// The multiplied field element as a plain bit vector.
  @Deprecated('Use gfResult for field-typed operations.')
  Logic get result => _legacyResult;

  /// The multiplied field element.
  late final GfLogic gfResult;
  late final Logic _legacyResult;

  /// Creates a constant multiplier from a plain bit-vector input.
  @Deprecated('Use GfConstantMultiplier.typed with a field-typed input.')
  GfConstantMultiplier(
    Logic input, {
    required BinaryExtensionField field,
    required GfValue constant,
    String name = 'gf_constant_multiplier',
  }) : this._(input,
            field: field, constant: constant, name: name, typedPorts: false);

  /// Creates a constant multiplier for the input field.
  GfConstantMultiplier.typed(GfLogic input,
      {required GfValue constant, String name = 'gf_constant_multiplier'})
      : this._(input,
            field: input.field,
            constant: constant,
            name: name,
            typedPorts: true);

  GfConstantMultiplier._(Logic input,
      {required this.field,
      required this.constant,
      required super.name,
      required bool typedPorts})
      : super(
          definitionName: 'GfConstantMultiplier_D${field.degree}_C'
              '${constant.value.toRadixString(16)}',
        ) {
    field.requireCompatible(constant.field);
    if (input.width != field.degree) {
      throw ArgumentError('Input width must equal the field degree.');
    }
    final localInput = typedPorts
        ? addTypedInput('dataIn', GfLogic.of(input, field: field))
        : GfLogic.of(addInput('dataIn', input, width: input.width),
            field: field);
    transform = _multiplicationTransform(field, constant);
    final multiplier = BinaryLinearTransform(
      localInput,
      matrix: transform.matrix,
      definitionName: 'GfConstantMultiplierTransform_'
          '${transform.configurationSignature}',
    );
    GfLogic resultSchema({String? name}) => GfLogic(field, name: name);
    if (typedPorts) {
      gfResult = addTypedOutput<GfLogic>('result', resultSchema);
      _legacyResult = Logic(name: 'result', width: field.degree)
        ..gets(gfResult);
      gfResult <= multiplier.result;
    } else {
      _legacyResult = addOutput('result', width: field.degree);
      gfResult = GfLogic.of(_legacyResult, field: field);
      _legacyResult <= multiplier.result;
    }
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
