// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// pad.dart
// Widens a signal by inserting bits of a constant fill at one end.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Widens `inp` to at least `atLeast` bits by inserting bits equal to `fill`
/// at the least significant end (`lsbs` true) or the most significant end
/// (`lsbs` false).
///
/// The input bits keep their positions relative to the end they are not
/// padded at. If `inp` is already at least `atLeast` bits wide, `result` is
/// `inp` unchanged in value and width.
/// {@category Bit Operations}
class Pad extends Module {
  /// The widened signal.
  Logic get result => output('result');

  /// Creates padding hardware for [inp].
  Pad(
    Logic inp, {
    required int atLeast,
    bool lsbs = true,
    bool fill = false,
    super.name = 'pad',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
            definitionName: definitionName ??
                'Pad_${lsbs ? 'Lsbs' : 'Msbs'}_F${fill ? 1 : 0}_'
                    'W${inp.width}_A$atLeast') {
    inp = addInput('inp', inp, width: inp.width);

    final padded = inp.pad(atLeast: atLeast, lsbs: lsbs, fill: fill);
    addOutput('result', width: padded.width) <= padded;
  }
}
