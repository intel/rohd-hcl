// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// signed_shifter.dart
// Implementation of bidirectional shifter.
//
// 2025 January 8
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// A bit shifter that takes a positive or negative shift amount
class SignedShifter extends Module {
  /// The output [shifted] bits
  Logic get shifted => output('shifted');

  /// Create a [SignedShifter] that treats shift as signed
  /// - [bits] is the input to be shifted
  /// - [shift] is the signed amount to be shifted
  SignedShifter(Logic bits, Logic shift, {super.name = 'shifter'}) {
    bits = addInput('bits', bits, width: bits.width);
    shift = addInput('shift', shift, width: shift.width);

    addOutput('shifted', width: bits.width);
    shifted <= mux(shift[-1], bits >>> shift.abs(), bits << shift);
  }
}
