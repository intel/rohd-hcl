// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// count_leading_trailing_zeros.dart
// Counts of leading and trailing zeros.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Base for modules counting zeros from one end of a [Logic] bus.
abstract class _CountZeros extends Module {
  /// The number of zeros, or the bus width when the input is all zeros.
  Logic get count => output('count');

  _CountZeros(Logic inp,
      {required bool fromMsb,
      required String defaultName,
      super.name = 'count_zeros',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ?? '${defaultName}_W${inp.width}') {
    inp = addInput('inp', inp, width: inp.width);
    final count = addOutput('count', width: inp.width);

    final encoder = RecursivePriorityEncoder(fromMsb ? inp.reversed : inp);
    count <= encoder.out.zeroExtend(inp.width);
  }
}

/// Counts the zeros above the most significant set bit of a [Logic].
///
/// The result is the input width when `inp` is zero.
class CountLeadingZeros extends _CountZeros {
  /// Constructs a [CountLeadingZeros] over [inp].
  CountLeadingZeros(super.inp,
      {super.name = 'count_leading_zeros',
      super.reserveName,
      super.reserveDefinitionName,
      super.definitionName})
      : super(fromMsb: true, defaultName: 'CountLeadingZeros');
}

/// Counts the zeros below the least significant set bit of a [Logic].
///
/// The result is the input width when `inp` is zero.
class CountTrailingZeros extends _CountZeros {
  /// Constructs a [CountTrailingZeros] over [inp].
  CountTrailingZeros(super.inp,
      {super.name = 'count_trailing_zeros',
      super.reserveName,
      super.reserveDefinitionName,
      super.definitionName})
      : super(fromMsb: false, defaultName: 'CountTrailingZeros');
}
