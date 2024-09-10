// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// string_config_knob.dart
// A knob for holding a string.
//
// 2023 December 5

import 'package:rohd_hcl/rohd_hcl.dart';

/// A knob for holding a [String].
class StringConfigKnob extends TextConfigKnob<String> {
  /// Creates a new knob with the specified initial [value].
  StringConfigKnob({required super.value});

  @override
  void setValueFromString(String valueString) => value = valueString;
}
