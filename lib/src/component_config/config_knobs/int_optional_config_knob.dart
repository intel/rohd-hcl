// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// int_optional_config_knob.dart
// A knob for holding a number or null.
//
// 2024 September 9

import 'package:rohd_hcl/rohd_hcl.dart';

/// A knob to store an [int].
class IntOptionalConfigKnob extends TextConfigKnob<int?> {
  /// Creates a new config knob with the specified initial [value].
  IntOptionalConfigKnob({required super.value});

  @override
  Map<String, dynamic> toJson() => {
        'value': value == null
            ? null
            : value! > 255
                ? '0x${value!.toRadixString(16)}'
                : value
      };

  @override
  String get valueString => value == null
      ? ''
      : value! > 255
          ? '0x${value!.toRadixString(16)}'
          : value.toString();

  @override
  bool get allowEmpty => true;

  @override
  void loadJson(Map<String, dynamic> decodedJson) {
    final val = decodedJson['value'];
    if (val == null) {
      value = null;
    } else if (val is String) {
      if (val.isEmpty) {
        value = null;
      } else {
        value = int.parse(val);
      }
    } else {
      value = val as int;
    }
  }
}
