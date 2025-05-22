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
  final ChoiceConfigKnob<Type> anticipator = ChoiceConfigKnob(
      [LeadingDigitAnticipate, LeadingZeroAnticipate],
      value: LeadingDigitAnticipate);

  /// Controls the width of the input.
  final IntConfigKnob inputWidthKnob = IntConfigKnob(value: 8);

  /// When available, controls whether to output endAroundCarry
  final ToggleConfigKnob generateEndAroundCarryKnob =
      ToggleConfigKnob(value: false);

  @override
  Module createModule() {
    final sgn1 = Logic();
    final inp1 = Logic(width: inputWidthKnob.value);
    final sgn2 = Logic();

    final inp2 = Logic(width: inputWidthKnob.value);
    return anticipator.value == LeadingDigitAnticipate
        ? LeadingDigitAnticipate(inp1, inp2)
        : LeadingZeroAnticipate(sgn1, inp1, sgn2, inp2,
            endAroundCarry: generateEndAroundCarryKnob.value ? Logic() : null);
  }

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Anticpator': anticipator,
        if (anticipator.value == LeadingZeroAnticipate)
          'EndAroundCarry': generateEndAroundCarryKnob,
        'Input width': inputWidthKnob,
      };

  @override
  String get name => 'Leading Digit Anticipator';
}
