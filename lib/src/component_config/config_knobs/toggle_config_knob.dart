// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_knob.dart
// Definition of a configuration knob.
//
// 2023 December 5

import 'package:rohd_hcl/rohd_hcl.dart';

/// A knob for holding a [bool].
class ToggleConfigKnob extends ConfigKnob<bool> {
  /// Creates a new knob with the specified initial [value].
  ToggleConfigKnob({required super.value});
}
