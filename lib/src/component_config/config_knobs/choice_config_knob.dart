// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// choice_config_knob.dart
// A knob for selecting one of multiple choices.
//
// 2023 December 5

import 'package:rohd_hcl/rohd_hcl.dart';

/// A [ConfigKnob] for selecting one of multiple options.
///
/// This is a useful choice for selecting one of an `enum`.
class ChoiceConfigKnob<T> extends ConfigKnob<T> {
  /// The available choices to choose from.
  ///
  /// Often the entire `enum`'s `values` list, unless it needs to be more
  /// restrictive.
  List<T> choices;

  /// Creates a new knob to with the specified default [value] of the available
  /// [choices].
  ChoiceConfigKnob(this.choices, {required super.value}) {
    if (!choices.contains(value)) {
      throw RohdHclException('Default value should be one of the choices.');
    }
  }

  @override
  set value(T newValue) {
    if (!choices.contains(newValue)) {
      throw RohdHclException(
          'New value should be one of the available choices.');
    }
    super.value = newValue;
  }

  @override
  void loadJson(Map<String, dynamic> decodedJson) {
    value = choices.firstWhere(
        (element) => element.toString() == decodedJson['value'] as String);
  }

  @override
  Map<String, dynamic> toJson() => {'value': value.toString()};
}
