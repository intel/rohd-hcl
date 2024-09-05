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

/// A [SignMagnitudeAdder] performsa addition on values in sign/magnitude format.
class SignMagnitudeAdder extends Adder {
  /// The sign of the first input
  Logic aSign;

  /// The sign of the second input
  Logic bSign;

  /// The sign of the result
  Logic get sign => output('sign');

  @protected
  Logic _sign = Logic();

  /// Largest magnitude argument is provided in [a] or if equal
  /// the argument with a negative sign.
  bool largestMagnitudeFirst;

  /// [SignMagnitudeAdder] constructor with an adder functor [adderGen]
  ///Inputs are (sign, magnitude) pairs: ([aSign], [a]) and ([bSign], [b]).
  /// If the caller can guarantee that the larger magnitude value
  ///  is provided first in [a], then they can set [largestMagnitudeFirst]
  /// too 'true' to avoid a comparator.
  // TODO(desmonddak): this adder may need a carry-in for rounding
  SignMagnitudeAdder(this.aSign, super.a, this.bSign, super.b,
      Adder Function(Logic, Logic) adderGen,
      {this.largestMagnitudeFirst = false})
      : super(
            name: 'Sign Magnitude Adder: '
                '${adderGen.call(Logic(), Logic()).name}') {
    aSign = addInput('aSign', aSign);
    bSign = addInput('bSign', bSign);
    _sign = addOutput('sign');

    final bLarger = a.lt(b) | (a.eq(b) & bSign.gt(aSign));

    _sign <= (largestMagnitudeFirst ? aSign : mux(bLarger, bSign, aSign));
    final adder = OnesComplementAdder(a, b,
        subtractIn: aSign ^ bSign, adderGen: adderGen);
    sum <= adder.sum;
  }
}
