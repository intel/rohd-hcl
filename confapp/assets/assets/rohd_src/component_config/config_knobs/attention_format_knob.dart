// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// attention_format_knob.dart
// Named shared numeric formats and attention arithmetic role assignments.
//
// 2026 November 24
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd_hcl/rohd_hcl.dart';

/// Arithmetic uses of a shared attention format definition.
enum AttentionFormatRole {
  /// Query and key elements.
  queryKey('Query/Key'),

  /// Value elements.
  value('Value'),

  /// Dot-product scores.
  score('Score'),

  /// Normalization sums.
  normalizer('Normalizer'),

  /// Exponential scales.
  exponential('Exponential'),

  /// Reciprocal scales.
  reciprocal('Reciprocal');

  /// Label shown for an arithmetic role.
  final String label;

  const AttentionFormatRole(this.label);
}

/// An editable label and its fixed-point format definition.
class NamedAttentionFormatKnob extends GroupOfKnobs {
  /// User-facing name; assignments retain their numeric identity on rename.
  final StringConfigKnob labelKnob;

  /// Width and fractional precision.
  final InferenceFixedPointFormatKnob formatKnob;

  NamedAttentionFormatKnob._(this.labelKnob, this.formatKnob)
      : super({'Label': labelKnob, 'Format': formatKnob});

  @override
  String get name => labelKnob.value;
}

class _AttentionFormatDefinitionsKnob extends ListOfKnobsKnob {
  final int Function() _minimumCount;

  _AttentionFormatDefinitionsKnob(this._minimumCount)
      : super(
          count: AttentionFormatRole.values.length,
          name: 'Format Definitions',
          generateKnob: (index) {
            final role = index < AttentionFormatRole.values.length
                ? AttentionFormatRole.values[index]
                : null;
            return NamedAttentionFormatKnob._(
              StringConfigKnob(value: role?.label ?? 'Format $index'),
              InferenceFixedPointFormatKnob(
                width: switch (role) {
                  AttentionFormatRole.queryKey ||
                  AttentionFormatRole.score ||
                  AttentionFormatRole.exponential =>
                    4,
                  _ => 6,
                },
                fractionBits: switch (role) {
                  AttentionFormatRole.normalizer ||
                  AttentionFormatRole.exponential =>
                    2,
                  AttentionFormatRole.reciprocal => 4,
                  _ => 0,
                },
              ),
            );
          },
        );

  @override
  int get minCount => _minimumCount();
}

/// Selects a named definition while serializing a stable zero-based index.
class AttentionFormatSelectionKnob extends ChoiceConfigKnob<int> {
  final ListOfKnobsKnob _definitions;

  AttentionFormatSelectionKnob._(this._definitions, {required super.value})
      : super(List.generate(_definitions.count, (index) => index));

  /// Synchronizes choices after definitions are added or removed.
  void refreshChoices() =>
      choices = List.generate(_definitions.count, (index) => index);

  @override
  set value(int newValue) {
    refreshChoices();
    super.value = newValue;
  }

  @override
  void loadJson(Map<String, dynamic> decodedJson) {
    refreshChoices();
    super.loadJson(decodedJson);
  }

  @override
  String labelFor(int choice) {
    final definition = _definitions.knobs[choice];
    if (definition is! NamedAttentionFormatKnob) {
      throw StateError('Attention requires named format definitions.');
    }
    return '$choice: ${definition.name}';
  }
}

/// Shares named format definitions between the six attention arithmetic roles.
///
/// Only unused trailing definitions can be removed. Reassign their roles first
/// so resizing never silently changes arithmetic precision.
class AttentionNumericFormatsKnob extends GroupOfKnobs {
  /// Adjustable definitions; removed, unused entries are cached for regrowth.
  final ListOfKnobsKnob definitionsKnob;

  /// The format selected for each arithmetic role.
  final Map<AttentionFormatRole, AttentionFormatSelectionKnob> assignments;

  final GroupOfKnobs _assignmentsKnob;

  /// Creates six small preview formats; every role remains independently set.
  factory AttentionNumericFormatsKnob() {
    final assignments = <AttentionFormatRole, AttentionFormatSelectionKnob>{};
    final definitions = _AttentionFormatDefinitionsKnob(
      () => assignments.values.fold(
        1,
        (count, knob) => max(count, knob.value + 1),
      ),
    );
    for (final role in AttentionFormatRole.values) {
      assignments[role] =
          AttentionFormatSelectionKnob._(definitions, value: role.index);
    }
    return AttentionNumericFormatsKnob._(
      definitions,
      Map.unmodifiable(assignments),
      GroupOfKnobs(
        {for (final entry in assignments.entries) entry.key.label: entry.value},
        name: 'Arithmetic Roles',
      ),
    );
  }

  AttentionNumericFormatsKnob._(
      this.definitionsKnob, this.assignments, this._assignmentsKnob)
      : super({
          'Arithmetic Roles': _assignmentsKnob,
          'Format Definitions': definitionsKnob,
        }, name: 'Numeric Formats');

  /// Refreshes the role menus to include precisely the active definitions.
  void refreshChoices() {
    for (final knob in assignments.values) {
      knob.refreshChoices();
    }
  }

  /// Returns the named definition at [index].
  NamedAttentionFormatKnob definitionAt(int index) {
    final definition = definitionsKnob.knobs[index];
    if (definition is! NamedAttentionFormatKnob) {
      throw StateError('Attention requires named format definitions.');
    }
    return definition;
  }

  /// Resolves a role to its shared numeric format.
  InferenceFixedPointFormatKnob formatFor(AttentionFormatRole role) =>
      definitionAt(assignments[role]!.value).formatKnob;

  @override
  void loadJson(Map<String, dynamic> decodedJson) {
    for (final key in decodedJson.keys) {
      if (!subKnobs.containsKey(key)) {
        throw RohdHclException('Unknown numeric format control "$key".');
      }
    }
    final definitionsJson =
        decodedJson['Format Definitions'] as Map<String, dynamic>;
    final count = (definitionsJson['knobs'] as List<dynamic>).length;
    if (count < 1) {
      throw ArgumentError('Attention requires at least one format definition.');
    }
    // Grow before assignments; shrink only once references are restored.
    if (count > definitionsKnob.count) {
      definitionsKnob.count = count;
    }
    _assignmentsKnob
        .loadJson(decodedJson['Arithmetic Roles'] as Map<String, dynamic>);
    definitionsKnob.loadJson(definitionsJson);
    refreshChoices();
  }
}
