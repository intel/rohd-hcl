// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// text_config_knob.dart
// Definition of a configuration knob which can be configured by parsing text.
//
// 2023 December 5

import 'package:rohd_hcl/rohd_hcl.dart';

/// A configuration knob for use in [Configurator]s which can be configured by
/// text.
abstract class TextConfigKnob<T> extends ConfigKnob<T> {
  /// Creates a new knob with an initial [value].
  TextConfigKnob({required super.value});

  /// A [String] representation of the [value].
  String get valueString => value.toString();

  /// Whether the knob allows an empty string as input.
  bool get allowEmpty => false;
}
