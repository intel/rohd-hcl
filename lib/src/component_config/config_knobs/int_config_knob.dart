// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// int_config_knob.dart
// A knob for holding a number.
//
// 2023 December 5

import 'package:rohd_hcl/rohd_hcl.dart';

/// A knob to store an [int].
class IntConfigKnob extends TextConfigKnob<int> {
  /// Creates a new config knob with the specified initial [value].
  IntConfigKnob({required super.value});

  @override
  Map<String, dynamic> toJson() =>
      {'value': value > 255 ? '0x${value.toRadixString(16)}' : value};

  @override
  String get valueString =>
      value > 255 ? '0x${value.toRadixString(16)}' : value.toString();

  @override
  void loadJson(Map<String, dynamic> decodedJson) {
    final val = decodedJson['value'];
    if (val is String) {
      value = int.parse(val);
    } else {
      value = val as int;
    }
  }
}
