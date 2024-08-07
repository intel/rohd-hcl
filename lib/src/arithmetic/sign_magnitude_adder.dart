// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
//sign_magnitude_adder
// Implementation of a One's Complement Adder
//
// 2024 April 12
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An Adder which performs one's complement arithmetic using an unsigned
/// adder that is passed in using a functor
///    -- Requires that if the larger magnitude number is negative it
///       must be the first 'a' argument
///       We cannot enforce because this may be a smaller mantissa in
///       a larger magnitude negative floating point number (no asserts please)
class SignMagnitudeAdder extends Adder {
  /// The sign of the first input
  @protected
  late final Logic aSign;

  /// The sign of the second input
  @protected
  late final Logic bSign;

  /// The sign of the result
  Logic get sign => output('sign');

  late final Logic _out;
  late final Logic _carry = Logic();

  /// [SignMagnitudeAdder] constructor with an unsigned adder functor
  SignMagnitudeAdder(Logic as, super.a, Logic bs, super.b,
      Adder Function(Logic, Logic) adderGen)
      : _out = Logic(width: a.width),
        super(
            name: 'Ones Complement Adder: '
                '${adderGen.call(Logic(), Logic()).name}') {
    aSign = addInput('aSign', as);
    bSign = addInput('bSign', bs);
    final sign = addOutput('sign');

    final aOnesComplement = mux(aSign, ~a, a);
    final bOnesComplement = mux(bSign, ~b, b);

    final adder = adderGen(aOnesComplement, bOnesComplement);
    final endAround = adder.carryOut & (aSign | bSign);
    final localOut = mux(endAround, adder.sum + 1, adder.sum);

    sign <= aSign;
    _out <= mux(sign, ~localOut, localOut).slice(_out.width - 1, 0);
    _carry <= localOut.slice(localOut.width - 1, localOut.width - 1);
  }

  @override
  @protected
  Logic calculateOut() => _out;

  @override
  @protected
  Logic calculateCarry() => _carry;

  @override
  @protected
  Logic calculateSum() => [_carry, _out].swizzle();
}
