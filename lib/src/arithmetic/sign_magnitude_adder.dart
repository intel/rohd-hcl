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
    final adder = OnesComplementAdder(a, b, aSign ^ bSign, null, adderGen);
    sum <= adder.sum;
  }
}

/// An adder (and subtractor) [OnesComplementAdder] that operates on
/// ones-complement values.
class OnesComplementAdder extends Adder {
  /// The sign of the result
  Logic get sign => output('sign');

  /// The end-around carry which should be added to the resulting [sum]
  /// If the input [carry] is not null, this value is stored there. Otherwise,
  /// the end-around carry is internally added to [sum]
  Logic? get carry => tryOutput('carry');

  @protected
  Logic _sign = Logic();

  /// [OnesComplementAdder] constructor with an adder functor [adderGen]
  /// Either a Logic [subtractIn] or a boolean [subtract] can enable
  /// subtraction, with [subtractIn] overriding [subtract].  If Logic [carry]
  /// is provided as not null, then the end-around carry is not performed and is
  /// left to the caller via the output [carry].
  OnesComplementAdder(super.a, super.b, Logic? subtractIn, Logic? carry,
      Adder Function(Logic, Logic) adderGen,
      {bool subtract = false})
      : super(
            name: 'Ones Complement Adder: '
                '${adderGen.call(Logic(), Logic()).name}') {
    if (subtractIn != null) {
      subtractIn = addInput('subtractIn', subtractIn);
    }
    _sign = addOutput('sign');
    if (carry != null) {
      addOutput('carry');
      carry <= this.carry!;
    }
    if ((subtractIn != null) & subtract) {
      throw RohdHclException(
          'Subtraction is controlled by a non-null subtractIn: '
          'subtract boolean is ignored');
    }
    final doSubtract = subtractIn ?? (subtract ? Const(1) : Const(0));

    final ax = a.zeroExtend(a.width);
    final bx = b.zeroExtend(b.width);

    final adder = adderGen(ax, mux(doSubtract, ~bx, bx));

    if (this.carry != null) {
      this.carry! <= adder.sum[-1];
    }
    final endAround = mux(doSubtract, adder.sum[-1], Const(0));
    final magnitude = adder.sum.slice(a.width - 1, 0);

    sum <=
        mux(
            doSubtract,
            mux(
                    endAround,
                    [if (this.carry != null) magnitude else magnitude + 1]
                        .first,
                    ~magnitude)
                .zeroExtend(sum.width),
            adder.sum);
    _sign <= mux(doSubtract, ~endAround, Const(0));
  }
}
