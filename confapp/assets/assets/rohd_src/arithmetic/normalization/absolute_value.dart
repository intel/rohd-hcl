// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// absolute_value.dart
// Exact-width two's-complement magnitude.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Computes the exact magnitude of a signed two's-complement value.
///
/// The [result] is one bit wider than the input so the most-negative input is
/// representable without overflow. Unlike `Logic.abs`, which keeps the input
/// width and wraps the most-negative value, this never wraps.
/// {@category Arithmetic}
class AbsoluteValue extends Module {
  /// Width of [result].
  final int outputWidth;

  /// The exact non-negative magnitude of the signed input.
  Logic get result => output('result');

  /// Creates combinational signed absolute-value hardware.
  AbsoluteValue(
    Logic value, {
    super.name = 'absolute_value',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  })  : outputWidth = value.width + 1,
        super(
          definitionName: definitionName ??
              'AbsoluteValue_I${value.width}_O${value.width + 1}',
        ) {
    value = addInput('value', value, width: value.width);

    final extendedValue = value.signExtend(outputWidth);
    final negativeMagnitude = ~extendedValue + Const(1, width: outputWidth);

    addOutput('result', width: outputWidth) <=
        mux(value[-1], negativeMagnitude, extendedValue);
  }
}
