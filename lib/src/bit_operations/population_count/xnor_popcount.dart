// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// xnor_popcount.dart
// Binary similarity using XNOR followed by population count.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_hcl/src/bit_operations/population_count/bitwise_popcount.dart';

/// Counts equal corresponding bits, producing a binary similarity score.
/// {@category Bit Operations}
class XnorPopcount extends BitwisePopcount {
  /// Creates balanced XNOR-popcount hardware.
  XnorPopcount(
    super.a,
    super.b, {
    super.radix = 2,
    super.name = 'xnor_popcount',
    super.reserveName,
    super.reserveDefinitionName,
    super.definitionName,
  }) : super(
          countEqual: true,
          definitionPrefix: 'XnorPopcount',
        );
}
