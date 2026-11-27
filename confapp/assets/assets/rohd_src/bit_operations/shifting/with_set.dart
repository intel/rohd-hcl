// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// with_set.dart
// Module that overwrites a slice of a value at a runtime start index.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Overwrites the bits of `subject` starting at `start` with `value`.
///
/// This is the variable-`start` form of `Logic.withSet`, whose start index is
/// a constant. Bits of `value` that fall above the width of `subject` are
/// dropped. A `start` at or above the width leaves `subject` unchanged.
class WithSet extends Module {
  /// The updated [result].
  Logic get result => output('result');

  /// Constructs a [WithSet] that writes [value] into [subject] at [start].
  WithSet(Logic subject, Logic start, Logic value,
      {super.name = 'withSet',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'WithSet_W${subject.width}_V${value.width}'
                    '_S${start.width}') {
    subject = addInput('subject', subject, width: subject.width);
    start = addInput('start', start, width: start.width);
    value = addInput('value', value, width: value.width);
    final result = addOutput('result', width: subject.width);

    final w = subject.width;
    final valueWidth = value.width < w ? value.width : w;
    final windowMask = Const((BigInt.one << valueWidth) - BigInt.one, width: w);
    final mask = windowMask << start;
    final aligned = value.slice(valueWidth - 1, 0).zeroExtend(w) << start;
    result <= (subject & ~mask) | (aligned & mask);
  }
}
