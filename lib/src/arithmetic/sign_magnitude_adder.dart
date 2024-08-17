// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sign_magnitude_adder.dart
// Implementation of a One's Complement Adder
//
// 2024 August 8
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An Adder which performs one's complement arithmetic using an
/// adder that is passed in using a functor. If the caller can guarantee
/// that the larger magnitude or negative value is provided first in 'a', then
/// they can set 'largestMagnitudeFirst' to 'true' to avoid a comparator.
class SignMagnitudeAdder extends Adder {
  /// The sign of the first input
  @protected
  late final Logic aSign;

  /// The sign of the second input
  @protected
  late final Logic bSign;

  /// The sign of the result
  Logic get sign => output('sign');

  /// Largest magnitude argument is provided in [a] or if equal
  /// the argument with a negative sign.
  bool largestMagnitudeFirst;

  /// [SignMagnitudeAdder] constructor with an unsigned adder functor
  SignMagnitudeAdder(Logic as, super.a, Logic bs, super.b,
      Adder Function(Logic, Logic) adderGen,
      {this.largestMagnitudeFirst = false})
      : super(
            name: 'Ones Complement Adder: '
                '${adderGen.call(Logic(), Logic()).name}') {
    aSign = addInput('aSign', as);
    bSign = addInput('bSign', bs);
    final sign = addOutput('sign');

    final bLarger = a.lt(b) | (a.eq(b) & bSign.gt(aSign));

    final computeSign = mux(largestMagnitudeFirst ? Const(1) : Const(0), aSign,
        mux(bLarger, bSign, aSign));

    final ax = a.zeroExtend(a.width + 1);
    final bx = b.zeroExtend(b.width + 1);

    final aOnesComplement = mux(aSign, ~ax, ax);
    final bOnesComplement = mux(bSign, ~bx, bx);

    final adder = adderGen(aOnesComplement, bOnesComplement);
    final endAround = adder.sum[-1] & (aSign | bSign);
    final localOut = mux(endAround, adder.sum + 1, adder.sum);
    sign <= computeSign;
    sum <= mux(sign, ~localOut, localOut).slice(ax.width - 1, 0);
  }
}
