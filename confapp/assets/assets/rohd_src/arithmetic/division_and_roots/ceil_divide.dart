// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ceil_divide.dart
// Unsigned division rounded up to the next integer.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Divides `dividend` by `divisor` and rounds the quotient up.
///
/// The quotient is the unsigned quotient plus
/// one whenever there is a non-zero remainder, and is truncated to the width of
/// `dividend`. Division by zero follows the underlying [Divide] and [Modulo]
/// behavior and is not specified here.
class CeilDivide extends Module {
  /// The rounded-up [quotient].
  Logic get quotient => output('quotient');

  /// Constructs a [CeilDivide] of [dividend] by [divisor].
  CeilDivide(Logic dividend, Logic divisor,
      {super.name = 'ceil_divide',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'CeilDivide_N${dividend.width}_D${divisor.width}') {
    dividend = addInput('dividend', dividend, width: dividend.width);
    divisor = addInput('divisor', divisor, width: divisor.width);
    final quotient = addOutput('quotient', width: dividend.width);

    final w = dividend.width;
    final truncated = (dividend / divisor).zeroExtend(w + 1).slice(w, 0);
    final inexact = (dividend % divisor).or();
    quotient <= (truncated + inexact.zeroExtend(w + 1)).slice(w - 1, 0);
  }
}
