// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_knob.dart
// Definition of a configuration knob.
//
// 2023 December 5

import 'package:rohd_hcl/rohd_hcl.dart';

/// A configuration knob for use in [Configurator]s.
abstract class ConfigKnob<T> {
  /// The primary value being stored in this knob.
  T value;

  /// Creates a new knob with an initial [value].
  ConfigKnob({required this.value});

  /// Serializes this knob into a JSON-compatible map.
  Map<String, dynamic> toJson() => {'value': value};

  /// Reconfigures this knob based on the provided deserialized JSON.
  void loadJson(Map<String, dynamic> decodedJson) {
    value = decodedJson['value'] as T;
  }
}
