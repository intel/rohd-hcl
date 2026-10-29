// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// bitwise_popcount.dart
// Shared bitwise comparison followed by population count.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/bit_operations/population_count/count.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// Base hardware for counting equal or unequal corresponding bits.
///
/// Subclasses select whether equal or unequal bits contribute to [count].
/// {@category Bit Operations}
abstract class BitwisePopcount extends Module {
  /// Number of selected corresponding bit positions.
  Logic get count => output('count');

  /// The combinational depth of the underlying balanced population-count tree.
  late final int treeDepth;

  /// Creates shared bitwise-comparison population-count hardware.
  BitwisePopcount(
    Logic a,
    Logic b, {
    required bool countEqual,
    required String definitionPrefix,
    int radix = 2,
    super.name = 'bitwise_popcount',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          definitionName:
              definitionName ?? '${definitionPrefix}_W${a.width}_R$radix',
        ) {
    if (a.width != b.width) {
      throw RohdHclException(
        'Bitwise population-count inputs must have equal widths, got '
        '${a.width} and ${b.width}.',
      );
    }

    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    final compared = (countEqual ? ~(a ^ b) : a ^ b).named('compared');
    final populationCount = Count(compared, radix: radix);
    treeDepth = populationCount.treeDepth;
    addOutput('count', width: populationCount.count.width) <=
        populationCount.count;
  }
}
