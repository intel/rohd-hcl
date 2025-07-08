// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// leading_digit_anticipate.dart
// Implementation of LeadingZeroAnticipate and LeadingDigitAnticipate Modules.
//
// 2025 April 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Base class for leading-zero anticipate modules.
abstract class LeadingZeroAnticipateBase extends Module {
  /// The number of zeros or position of leading 1.
  Logic get leadingOne => output('leadingOne');

  /// If the [leadingOne] output is valid.
  Logic get validLeadOne => output('validLeadOne');

  /// The sign of input [a].
  @protected
  Logic get aSign => input('aSign');

  /// The value of input [a].
  @protected
  Logic get a => input('a');

  /// The sign of input [b].
  @protected
  Logic get bSign => input('bSign');

  /// The value of input [b].
  @protected
  Logic get b => input('b');

  /// The predictor used for the computation of [a] operation with [b].
  @protected
  late final RecursiveModulePriorityEncoder leadOneEncoder;

  /// The predictor used for the computation of [b] operation with [a].
  @protected
  late final RecursiveModulePriorityEncoder leadOneEncoderConverse;

  /// Construct a leading-zero anticipate module that predicts the number of
  /// leading zeros in the sum of [a] and [b].  The output [leadingOne] holds
  /// the position of the leading '1' (or, equivalently, the number of leading
  /// zeros) that are predicted.  This prediction can be exact or 1 position
  /// less than the leading zero of the sum or subtraction of [a] and [b].
  /// [validLeadOne] indicates a leading one was found.
  LeadingZeroAnticipateBase(Logic aSign, Logic a, Logic bSign, Logic b,
      {super.name = 'leading_zero_anticipate', String? definitionName})
      : super(definitionName: definitionName ?? 'LeadingZeroAnticipate') {
    aSign = addInput('aSign', aSign);
    a = addInput('a', a, width: a.width);
    bSign = addInput('bSign', bSign);
    b = addInput('b', b, width: b.width);

    final aX = a.zeroExtend(a.width + 1).named('aX');
    final bX = b.zeroExtend(b.width + 1).named('bX');
    final t = (aX ^ mux(aSign ^ bSign, ~bX, bX)).named('t');
    final zForward = (~aX & mux(aSign ^ bSign, bX, ~bX)).named('zerosForward');
    final zReverse = ~bX & mux(aSign ^ bSign, aX, ~aX).named('zerosReverse');
    final fForward = Logic(name: 'findForward', width: t.width);
    final fReverse = Logic(name: 'findReverse', width: t.width);
    fForward <= t ^ (~zForward << 1 | Const(1, width: t.width));
    fReverse <= t ^ (~zReverse << 1 | Const(1, width: t.width));

    leadOneEncoder = RecursiveModulePriorityEncoder(fForward.reversed,
        generateValid: true, name: 'leadone_detect');

    leadOneEncoderConverse = RecursiveModulePriorityEncoder(fReverse.reversed,
        generateValid: true, name: 'leadone_detect_converse');

    addOutput('leadingOne', width: log2Ceil(fForward.width + 1));
    addOutput('validLeadOne');
  }
}

/// Module for predicting the number of leading zeros (position of leading 1)
/// before an addition or subtraction.
class LeadingZeroAnticipate extends LeadingZeroAnticipateBase {
  /// The number of zeros for the converse case (when subtracting)
  Logic get leadingOneConverse => output('leadingOneConverse');

  /// If the converse case is valid.
  Logic get validLeadOneConverse => output('validLeadOneConverse');

  /// Construct a leading-zero anticipate module that predicts the number of
  /// leading zeros in the operation on [a] and [b] (ones-complement addition or
  /// subtraction). Pairs of prediction outputs ([leadingOne]/[validLeadOne] and
  /// [leadingOneConverse]/[validLeadOneConverse]) for the operation on [a] and
  /// [b] inputs are produced. These appropriate prediction pair can be selected
  /// outside the module by looking at the end-around-carry of a
  /// ones-complement: Essentially, [leadingOne] should be used if [a]
  /// > [b] (e.g., there is a carry output from a ones-complement subtraction of
  /// [a] and [b]. [leadingOneConverse] should be used if [b] >= [a] during
  /// subtraction.
  LeadingZeroAnticipate(super.aSign, super.a, super.bSign, super.b,
      {super.name = 'leading_zero_anticipate', String? definitionName})
      : super(definitionName: definitionName ?? 'LeadingDigitAnticipate') {
    leadingOne <= leadOneEncoder.out;
    validLeadOne <= leadOneEncoder.valid!;
    addOutput('leadingOneConverse', width: leadOneEncoderConverse.out.width);
    leadingOneConverse <= leadOneEncoderConverse.out;
    addOutput('validLeadOneConverse');
    validLeadOneConverse <= leadOneEncoderConverse.valid!;
  }
}

/// Module for predicting the number of leading zeros (position of leading 1)
/// before an addition or subtraction.
class LeadingZeroAnticipateCarry extends LeadingZeroAnticipateBase {
  /// Construct a leading-zero anticipate module that predicts the number of
  /// leading zeros in the addition or subtraction of [a] and [b].  Provide the
  /// [endAroundCarry] from the ones-complement operation to select the proper
  /// prediction pair. and output as [leadingOne] and [validLeadOne].
  LeadingZeroAnticipateCarry(super.aSign, super.a, super.bSign, super.b,
      {required Logic endAroundCarry,
      super.name = 'leading_zero_anticipate_carry',
      String? definitionName})
      : super(definitionName: definitionName ?? 'LeadingDigitAnticipate') {
    endAroundCarry = addInput('endAroundCarry', endAroundCarry);

    leadingOne <=
        mux(endAroundCarry, leadOneEncoder.out, leadOneEncoderConverse.out);
    validLeadOne <=
        mux(endAroundCarry, leadOneEncoder.valid!,
            leadOneEncoderConverse.valid!);
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
      {super.name = 'leading_digit_anticipate', String? definitionName})
      : super(definitionName: definitionName ?? 'LeadingDigitAnticipate') {
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
