// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_sort_fields.dart
// Raw operand fields for floating-point adder sorting.
//
// 2026 November 15
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/signals/floating_point_logics/floating_point_logic.dart';

/// Fields whose encoding can be sorted independently of the operand format.
@internal
class FloatingPointSortFields extends LogicStructure {
  /// Operand sign.
  Logic get sign => elements[0];

  /// Operand exponent.
  Logic get exponent => elements[1];

  /// Encoded mantissa.
  Logic get mantissa => elements[2];

  /// Whether this operand carries an explicit J bit.
  Logic get explicitJBit => elements[3];

  /// Whether the exponent is nonzero.
  late final Logic isNormal =
      exponent.neq(LogicValue.zero.zeroExtend(exponent.width));

  /// Captures the fields and representation of [operand].
  factory FloatingPointSortFields(FloatingPoint operand) =>
      FloatingPointSortFields._(operand.exponent.width, operand.mantissa.width)
        ..sign.gets(operand.sign)
        ..exponent.gets(operand.exponent)
        ..mantissa.gets(operand.mantissa)
        ..explicitJBit.gets(Const(operand.explicitJBit));

  FloatingPointSortFields._(int exponentWidth, int mantissaWidth,
      {String? name})
      : super([
          Logic(name: 'sign'),
          Logic(name: 'exponent', width: exponentWidth),
          Logic(name: 'mantissa', width: mantissaWidth),
          Logic(name: 'explicitJBit'),
        ], name: name ?? 'operand');

  @override
  FloatingPointSortFields clone({String? name}) =>
      FloatingPointSortFields._(exponent.width, mantissa.width,
          name: name ?? this.name);
}
