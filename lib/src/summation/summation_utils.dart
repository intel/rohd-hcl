// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// summation_utils.dart
// Internal utilities for the summation components.
//
// 2024 August 26
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

mixin DynamicInputToLogicForSummation on Module {
  int get width;

  @protected
  Logic dynamicInputToLogic(String name, dynamic value) {
    if (value is Logic) {
      return addInput(name, value.zeroExtend(width), width: width);
    } else {
      if (LogicValue.ofInferWidth(value).width > width) {
        throw RohdHclException(
            'Value $value for $name is too large for width $width');
      }

      return Logic(name: name, width: width)..gets(Const(value, width: width));
    }
  }
}

//TODO doc
//TODO: hide this somehow
int inferWidth(
    List<dynamic> values, int? width, List<SumInterface> interfaces) {
  if (width != null) {
    if (width <= 0) {
      throw RohdHclException('Width must be greater than 0.');
    }

    if (values.any((v) => v is Logic && v.width > width)) {
      throw RohdHclException(
          'Width must be at least as large as the largest value.');
    }

    return width;
  }

  int? maxWidthFound;

  for (final value in values) {
    int? inferredValWidth;
    if (value is Logic) {
      inferredValWidth = value.width;
    } else if (value != null) {
      inferredValWidth = LogicValue.ofInferWidth(value).width;
    }

    if (inferredValWidth != null &&
        (maxWidthFound == null || inferredValWidth > maxWidthFound)) {
      maxWidthFound = inferredValWidth;
    }
  }

  for (final interface in interfaces) {
    if (interface.width > maxWidthFound!) {
      maxWidthFound = interface.width;
    }
  }

  if (maxWidthFound == null) {
    throw RohdHclException('Unabled to infer width.');
  }

  return max(1, maxWidthFound);
}

int biggestVal(int width) => (1 << width) - 1;
