// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// xor_popcount.dart
// Hamming distance using XOR followed by population count.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_hcl/src/bit_operations/population_count/bitwise_popcount.dart';

/// Counts unequal corresponding bits, producing the Hamming distance.
/// {@category Bit Operations}
class XorPopcount extends BitwisePopcount {
  /// Creates balanced XOR-popcount hardware.
  XorPopcount(
    super.a,
    super.b, {
    super.radix = 2,
    super.name = 'xor_popcount',
    super.reserveName,
    super.reserveDefinitionName,
    super.definitionName,
  }) : super(
          countEqual: false,
          definitionPrefix: 'XorPopcount',
        );
}
