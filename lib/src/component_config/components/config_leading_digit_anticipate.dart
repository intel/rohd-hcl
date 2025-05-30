// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_leading_digit_anticipate.dart
// Configurator for Leading Digit Anticipators.
//
// 2025 April 27
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [LeadingDigitAnticipate] and [LeadingZeroAnticipate].
class LeadingDigitAnticipateConfigurator extends Configurator {
  /// Controls whether we anticipate the leading digit change or count
  /// leading zeros.
  final ChoiceConfigKnob<Type> anticipator = ChoiceConfigKnob([
    LeadingDigitAnticipate,
    LeadingZeroAnticipate,
    LeadingZeroAnticipateCarry
  ], value: LeadingDigitAnticipate);

  /// Controls the width of the input.
  final IntConfigKnob inputWidthKnob = IntConfigKnob(value: 8);

  @override
  Module createModule() {
    final sgn1 = Logic();
    final inp1 = Logic(width: inputWidthKnob.value);
    final sgn2 = Logic();
    final carry = Logic();

    final inp2 = Logic(width: inputWidthKnob.value);
    return [
      if (anticipator.value == LeadingDigitAnticipate)
        LeadingDigitAnticipate(inp1, inp2)
      else if (anticipator.value == LeadingZeroAnticipate)
        LeadingZeroAnticipate(sgn1, inp1, sgn2, inp2)
      else
        LeadingZeroAnticipateCarry(sgn1, inp1, sgn2, inp2,
            endAroundCarry: carry)
    ].first;
  }

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Anticpator': anticipator,
        'Input width': inputWidthKnob,
      };

  @override
  String get name => 'Leading Digit Anticipator';
}
