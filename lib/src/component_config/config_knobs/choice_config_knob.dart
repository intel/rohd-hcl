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

  /// Stable labels used for both display and JSON serialization.
  ///
  /// Every choice that is a Dart [Type] must have an entry because
  /// `Type.toString()` is not stable in minified builds. Other choice kinds
  /// may also provide labels to override their default string representation.
  ///
  /// When migrating existing [Type] choices, use labels matching their
  /// previous unminified names to preserve compatibility with saved JSON.
  final Map<T, String> choiceLabels;

  /// Creates a new knob to with the specified default [value] of the available
  /// [choices].
  ///
  /// If any member of [choices] is a Dart [Type], [choiceLabels] must contain
  /// a stable label for every such member. These labels are used as both
  /// user-facing text and serialized JSON values:
  ///
  /// ```dart
  /// ChoiceConfigKnob<Type>(
  ///   [BinaryToOneHot, OneHotToBinary],
  ///   value: OneHotToBinary,
  ///   choiceLabels: const {
  ///     BinaryToOneHot: 'BinaryToOneHot',
  ///     OneHotToBinary: 'OneHotToBinary',
  ///   },
  /// );
  /// ```
  ///
  /// Matching labels to the previous unminified `Type.toString()` values
  /// preserves compatibility with existing saved configurations.
  ChoiceConfigKnob(
    this.choices, {
    required super.value,
    this.choiceLabels = const {},
  }) {
    if (!choices.contains(value)) {
      throw RohdHclException('Default value should be one of the choices.');
    }
    if (!choiceLabels.keys.every(choices.contains)) {
      throw RohdHclException('Choice labels should correspond to choices.');
    }
    if (choices
        .whereType<Type>()
        .any((choice) => !choiceLabels.containsKey(choice))) {
      throw RohdHclException(
          'Type choices require stable labels for minified builds.');
    }
  }

  /// Returns the user-facing label for [choice].
  String labelFor(T choice) {
    final label = choiceLabels[choice];
    if (label != null) {
      return label;
    }
    if (choice is Type) {
      throw RohdHclException(
          'Type choices require stable labels for minified builds.');
    }
    return choice is Enum ? choice.name : choice.toString();
  }

  String _serializedValue(T choice) {
    final label = choiceLabels[choice];
    if (label != null) {
      return label;
    }
    if (choice is Type) {
      throw RohdHclException(
          'Type choices require stable labels for minified builds.');
    }
    return choice.toString();
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
      (element) => _serializedValue(element) == decodedJson['value'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'value': _serializedValue(value),
      };
}
