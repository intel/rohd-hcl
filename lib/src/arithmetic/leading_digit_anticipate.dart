// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// leading_digit_anticipate.dart
// Implementation of LeadingZeroAnticipate and LeadingDigitAnticipate Modules.
//
// 2025 April 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Module for predicting the number of leading zeros (position of leading 1)
/// before an addition or subtraction.
class LeadingZeroAnticipate extends Module {
  /// The number of zeros or position of leading 1.
  Logic? get leadingOne => output('leadingOne');

  /// If the [leadingOne] output is valid.
  Logic? get validLeadOne => output('validLeadOne');

  /// The number of zeros for the forward case (subtract)
  Logic? get leadingOneA => tryOutput('leadingOneA');

  /// If the forward case is valid.
  Logic? get validLeadOneA => tryOutput('validLeadOneA');

  /// The number of zeros for the reverse case (subtract)
  Logic? get leadingOneB => output('leadingOneB');

  /// If the reverse case is valid.
  Logic? get validLeadOneB => output('validLeadOneB');

  /// Input for telling LZA that a carry was seen on the add of inputs.
  late final Logic? endAroundCarry;

  /// Construct a leading-zero anticipate module that
  /// predicts the number of leading zeros in the sum of
  /// [a] and [b].
  /// - if [endAroundCarry] is provided as input, then only the
  /// [leadingOne] and [validLeadOne] outputs are set.  Otherwise,
  /// the pairs of outputs for the [a] and [b] inputs are set. [endAroundCarry]
  /// tells the LZA that a carry occurred when
  /// subtracting [b] from [a], which means we know [a] was larger and
  /// so we can simply pass out a computed [leadingOne] with its
  /// corresponding [validLeadOne].
  /// - Outputs [leadingOneA] which should be used if [a] > [b] (e.g., there
  /// is a carry output from a ones-complement subtraction of [a] and [b].
  /// - [leadingOneB] should be used if [b] >= [a].
  LeadingZeroAnticipate(Logic aSign, Logic a, Logic bSign, Logic b,
      {Logic? endAroundCarry, super.name = 'leading_zero_anticipate'}) {
    aSign = addInput('aSign', aSign);
    a = addInput('a', a, width: a.width);
    bSign = addInput('bSign', bSign);
    b = addInput('b', b, width: b.width);
    this.endAroundCarry = (endAroundCarry != null)
        ? addInput('endAroundCarry', endAroundCarry)
        : null;

    final aX = a.zeroExtend(a.width + 1).named('aX');
    final bX = b.zeroExtend(b.width + 1).named('bX');
    final t = (aX ^ mux(aSign ^ bSign, ~bX, bX)).named('t');
    final zForward = (~aX & mux(aSign ^ bSign, bX, ~bX)).named('zerosForward');
    final zReverse = ~bX & mux(aSign ^ bSign, aX, ~aX).named('zerosReverse');
    final fForward = Logic(name: 'findForward', width: t.width);
    final fReverse = Logic(name: 'findReverse', width: t.width);
    fForward <= t ^ (~zForward << 1 | Const(1, width: t.width));
    fReverse <= t ^ (~zReverse << 1 | Const(1, width: t.width));

    final leadOneEncoderA = RecursiveModulePriorityEncoder(fForward.reversed,
        generateValid: true, name: 'leadone_forward');
    final leadingOneA = leadOneEncoderA.out;
    final validLeadOneA = leadOneEncoderA.valid!;

    final leadOneEncoderB = RecursiveModulePriorityEncoder(fReverse.reversed,
        generateValid: true, name: 'leadone_reverse');
    final leadingOneB = leadOneEncoderB.out;
    final validLeadOneB = leadOneEncoderB.valid!;

    if (this.endAroundCarry == null) {
      addOutput('leadingOneA', width: log2Ceil(fForward.width + 1)) <=
          leadingOneA;
      addOutput('leadingOneB', width: log2Ceil(fReverse.width + 1)) <=
          leadingOneB;
      addOutput('validLeadOneA') <= validLeadOneA;
      addOutput('validLeadOneB') <= validLeadOneB;
    } else {
      addOutput('leadingOne', width: log2Ceil(fForward.width + 1)) <=
          mux(this.endAroundCarry!, leadingOneA, leadingOneB);
      addOutput('validLeadOne') <=
          mux(this.endAroundCarry!, validLeadOneA, validLeadOneB);
    }
  }
}

/// Module for predicting the number of leading digits (position of first
/// digit change) before the sum of the two 2s-complement numbers.
/// The leading digit position is either [leadingDigit] or [leadingDigit] + 1.
class LeadingDigitAnticipate extends Module {
  /// The number of digits or position of first digit change.
  Logic get leadingDigit => output('leadingDigit');

  /// If the [leadingDigit] output is valid.
  Logic get validLeadDigit => output('validLeadDigit');

  /// Construct a leading-digit anticipate module that
  /// predicts the number of leading digits in the sum of
  /// [a] and [b].
  /// - Outputs [leadingDigit] which is the position of the first digit
  /// change (leading 1 position for positive sum, leading 0 position for
  /// negative sum).
  LeadingDigitAnticipate(Logic a, Logic b,
      {super.name = 'leading_digit_anticipate'}) {
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    final pA = a.reversed;
    final pB = b.reversed;
    final g = pA & pB.named('g');
    final t = (pA ^ pB).named('t');
    final z = (~pA & ~pB).named('z');

    final findFromMSB = Logic(name: 'findFromMSB', width: t.width - 1);
    final lowBits = ((t << 1) & ((g & (~z >>> 1)) | (z & (~g >>> 1))) |
            (~t << 1) & ((z & (~z >>> 1)) | (g & (~g >>> 1))))
        .slice(t.width - 2, 1);

    findFromMSB <= [lowBits, ~t[0] & t[1]].swizzle();

    final leadingEncoder = RecursiveModulePriorityEncoder(findFromMSB,
        generateValid: true, name: 'leading-pos');
    final leadingPos = leadingEncoder.out;
    final validLead = leadingEncoder.valid!;

    addOutput('leadingDigit', width: log2Ceil(findFromMSB.width + 1)) <=
        leadingPos;
    addOutput('validLeadDigit') <= validLead;
  }
}
