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
  /// Inclusive lower bound, or `null` for a signed, unbounded knob.
  final int? minValue;

  /// Creates a new config knob with the specified initial [value].
  ///
  /// [minValue] restricts valid values without imposing an upper bound.
  IntConfigKnob({required int value, this.minValue}) : super(value: value) {
    _validate(value);
  }

  void _validate(int value) {
    if (minValue != null && value < minValue!) {
      throw ArgumentError.value(value, 'value', 'Must be at least $minValue.');
    }
  }

  @override
  set value(int value) {
    _validate(value);
    super.value = value;
  }

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
      setValueFromString(val);
    } else {
      value = val as int;
    }
  }

  @override
  void setValueFromString(String valueString) {
    final parsed = int.tryParse(valueString.trim());
    if (parsed == null) {
      throw ArgumentError.value(valueString, 'valueString', 'Invalid integer.');
    }
    value = parsed;
  }
}

/// An integer knob allowing zero and positive values, with no upper bound.
class NonNegativeIntConfigKnob extends IntConfigKnob {
  /// Creates a nonnegative knob with the specified initial [value].
  NonNegativeIntConfigKnob({required super.value}) : super(minValue: 0);
}

/// An integer knob allowing values of at least one, with no upper bound.
class PositiveIntConfigKnob extends IntConfigKnob {
  /// Creates a positive knob with the specified initial [value].
  PositiveIntConfigKnob({required super.value}) : super(minValue: 1);
}
