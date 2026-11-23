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
  /// The inverted field element as a plain bit vector.
  @Deprecated('Use gfResult for field-typed operations.')
  Logic get result => _legacyResult;

  /// The inverted field element.
  late final GfLogic gfResult;
  late final Logic _legacyResult;

  /// Creates an inverse from a plain bit-vector input.
  @Deprecated('Use GfInverse.typed with a field-typed input.')
  GfInverse(
    Logic input, {
    required BinaryExtensionField field,
    String name = 'gf_inverse',
  }) : this._(input, field: field, name: name, typedPorts: false);

  /// Creates a synthesizable combinational inverse for the input field.
  GfInverse.typed(GfLogic input, {String name = 'gf_inverse'})
      : this._(input, field: input.field, name: name, typedPorts: true);

  GfInverse._(Logic input,
      {required BinaryExtensionField field,
      required super.name,
      required bool typedPorts})
      : super(
          definitionName: 'GfInverse_D${field.degree}',
        ) {
    if (input.width != field.degree) {
      throw ArgumentError('Input width must equal the field degree.');
    }

    final localInput = typedPorts
        ? addTypedInput('dataIn', GfLogic.of(input, field: field))
        : GfLogic.of(addInput('dataIn', input, width: input.width),
            field: field);
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
    GfLogic resultSchema({String? name}) => GfLogic(field, name: name);
    if (typedPorts) {
      gfResult = addTypedOutput<GfLogic>('result', resultSchema);
      _legacyResult = Logic(name: 'result', width: field.degree)
        ..gets(gfResult);
      gfResult <= mux(isZero, GfLogic.constant(field.zero), inverse);
    } else {
      _legacyResult = addOutput('result', width: field.degree);
      gfResult = GfLogic.of(_legacyResult, field: field);
      _legacyResult <= mux(isZero, GfLogic.constant(field.zero), inverse);
    }
  }
}
