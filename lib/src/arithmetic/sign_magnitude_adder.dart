// Copyright (C) 2024-2025 Intel Corporation
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

/// A [SignMagnitudeAdder] performs addition on values in sign/magnitude
/// format.
class SignMagnitudeAdder extends Adder {
  /// The sign of the first input
  Logic aSign;

  /// The sign of the second input
  Logic bSign;

  /// The sign of the result
  Logic get sign => output('sign');

  /// The end-around carry which should be added to the resulting [sum]
  /// If the input [endAroundCarry] is not null, this value is stored there.
  ///  Otherwise, the end-around carry is internally added to [sum]
  Logic? get endAroundCarry => tryOutput('endAroundCarry');

  @protected
  Logic _sign = Logic();

  /// Largest magnitude argument is provided in [a] or if equal
  /// the argument with a negative sign.
  bool largestMagnitudeFirst;

  /// [SignMagnitudeAdder] constructor with an adder functor [adderGen].
  ///
  /// Inputs are (sign, magnitude) pairs: ([aSign], [a]) and ([bSign], [b]). If
  /// the caller can guarantee that the larger magnitude value is provided first
  /// in [a], then they can set [largestMagnitudeFirst] too 'true' to avoid
  /// adding a comparator. Without the comparator, the [sign] may be wrong, but
  /// magnitude will be correct.
  /// - [endAroundCarry] avoids extra hardware to add the final '1' in an
  /// end-around carry during subtraction. For subtractions that remain positive
  /// the [endAroundCarry] will hold that final +1 that needs to be added.
  /// For subtractions that go negative, the [endAroundCarry] will be '0'.
  // TODO(desmonddak): this adder may need a carry-in for rounding
  SignMagnitudeAdder(this.aSign, super.a, this.bSign, super.b,
      {Adder Function(Logic a, Logic b, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      this.largestMagnitudeFirst = false,
      Logic? endAroundCarry,
      super.name = 'sign_magnitude_adder'})
      : super(definitionName: 'SignMagnitudeAdder_W${a.width}') {
    aSign = addInput('aSign', aSign);
    bSign = addInput('bSign', bSign);
    _sign = addOutput('sign');

    if (endAroundCarry != null) {
      endAroundCarry = addOutput('endAroundCarry');
    }

    if (!largestMagnitudeFirst) {
      final bLarger = a.lt(b) | (a.eq(b) & bSign.gt(aSign));
      _sign <= mux(bLarger, bSign, aSign);
    } else {
      _sign <= aSign;
    }

    final sub = aSign ^ bSign;
    final endCarry = Logic();
    final adder =
        OnesComplementAdder(mux(_sign & sub, ~a, a), mux(_sign & sub, ~b, b),
            endAroundCarry: largestMagnitudeFirst
                ? endAroundCarry != null
                    ? endCarry
                    : null
                : null,
            subtractIn: sub,
            adderGen: adderGen);
    // sum <= adder.sum.getRange(0, adder.sum.width - 1).zeroExtend(sum.width);
    sum <= adder.sum;
    if (endAroundCarry != null) {
      output('endAroundCarry') <= (largestMagnitudeFirst ? endCarry : Const(0));
    }
  }
}
