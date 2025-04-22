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

/// A [SignMagnitudeAdderBase] performs addition on values in sign/magnitude
/// format.
abstract class SignMagnitudeAdderBase extends Adder {
  /// The sign of the first input
  Logic aSign;

  /// The sign of the second input
  Logic bSign;

  /// The sign of the result
  Logic get sign => output('sign');

  /// [SignMagnitudeAdder] constructor.
  ///
  /// Inputs are (sign, magnitude) pairs: ([aSign], [a]) and ([bSign], [b]). If
  /// the caller can guarantee that the larger magnitude value is provided first
  SignMagnitudeAdderBase(this.aSign, super.a, this.bSign, super.b,
      {String? definitionName, super.name = 'sign_magnitude_adder'})
      : super(
            definitionName:
                definitionName ?? 'SignMagnitudeAdder_W${a.width}') {
    aSign = addInput('aSign', aSign);
    bSign = addInput('bSign', bSign);
    addOutput('sign');
  }
}

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
      bool outputEndAroundCarry = false,
      super.name = 'sign_magnitude_adder',
      String? definitionName})
      : super(
            definitionName:
                definitionName ?? 'SignMagnitudeAdder_W${a.width}') {
    aSign = addInput('aSign', aSign);
    bSign = addInput('bSign', bSign);
    _sign = addOutput('sign');

    if (outputEndAroundCarry) {
      addOutput('endAroundCarry');
    }

    if (!largestMagnitudeFirst) {
      final bLarger = a.lt(b) | (a.eq(b) & bSign.gt(aSign));
      _sign <= mux(bLarger, bSign, aSign);
    } else {
      _sign <= aSign;
    }

    final sub = aSign ^ bSign;

    final adder = OnesComplementAdder(
        mux(_sign & sub, ~a, a), mux(_sign & sub, ~b, b),
        outputEndAroundCarry: largestMagnitudeFirst & outputEndAroundCarry,
        subtractIn: sub,
        adderGen: adderGen);
    sum <= adder.sum;
    if (outputEndAroundCarry) {
      output('endAroundCarry') <=
          (largestMagnitudeFirst ? adder.endAroundCarry! : Const(0));
    }
  }
}

/// A sign-magnitude adder implementation that uses two ones-complement
/// adders wired in opposition to compute the magnitude and sign without
/// using internal twos-complement addition.
class SignMagnitudeDualAdder extends SignMagnitudeAdderBase {
  ////// [SignMagnitudeDualAdder] constructor with an adder functor [adderGen].
  ///
  /// Inputs are (sign, magnitude) pairs: ([aSign], [a]) and ([bSign], [b]).
  /// The caller need not guarantee the order of inputs as this adder
  /// performs two ones-complement subtractions and selects the appropriate one
  /// to compute magnitude.
  SignMagnitudeDualAdder(super.aSign, super.a, super.bSign, super.b,
      {Adder Function(Logic a, Logic b, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      super.name = 'sign_magnitude_dualadder'})
      : super(definitionName: 'SignMagnitudeAdder_W${a.width}') {
    // final carryForward = Logic();
    final adderForward = SignMagnitudeAdder(Const(0), a, aSign ^ bSign, b,
        outputEndAroundCarry: true,
        largestMagnitudeFirst: true,
        adderGen: adderGen);

    // final carryReverse = Logic();
    final adderReverse = SignMagnitudeAdder(Const(0), b, aSign ^ bSign, a,
        outputEndAroundCarry: true,
        largestMagnitudeFirst: true,
        adderGen: adderGen);

    // Not having the endAroundCarry means the second argument is bigger
    // and that is also indicates the correct sign to choose.
    sum <=
        mux(adderForward.endAroundCarry!, adderReverse.sum, adderForward.sum);
    output('sign') <= mux(adderForward.endAroundCarry!, aSign, bSign);
  }
}
