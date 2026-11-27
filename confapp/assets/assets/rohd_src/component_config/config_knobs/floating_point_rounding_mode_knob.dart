// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_rounding_mode_knob.dart
// A knob for selecting an IEEE floating-point rounding mode.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';

/// A [ConfigKnob] for selecting a [FloatingPointRoundingMode].
class FloatingPointRoundingModeKnob
    extends ChoiceConfigKnob<FloatingPointRoundingMode> {
  /// Creates a floating-point rounding-mode selection knob.
  FloatingPointRoundingModeKnob({
    super.value = FloatingPointRoundingMode.roundNearestEven,
  }) : super(
          FloatingPointRoundingMode.values,
          choiceLabels: const {
            FloatingPointRoundingMode.truncate: 'Truncate',
            FloatingPointRoundingMode.roundNearestEven:
                'Round nearest, ties to even',
            FloatingPointRoundingMode.roundNearestTiesAway:
                'Round nearest, ties away',
            FloatingPointRoundingMode.roundTowardsZero: 'Round toward zero',
            FloatingPointRoundingMode.roundTowardsInfinity:
                'Round toward positive infinity',
            FloatingPointRoundingMode.roundTowardsNegativeInfinity:
                'Round toward negative infinity',
          },
        );
}
