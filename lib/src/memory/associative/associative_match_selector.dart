// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// associative_match_selector.dart
// Priority and age-value selection from an associative match vector.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';

String _selectorDefinitionName(
    Logic matchVector, List<Logic>? selectionValues, String selectionName) {
  final valuesName = selectionValues == null || selectionValues.isEmpty
      ? 'I'
      : 'V${selectionValues.first.width}';
  return 'AssociativeMatchSelector_E${matchVector.width}_'
      '${valuesName}_$selectionName';
}

/// Determines whether a candidate should replace the selected match.
typedef AssociativeMatchPreference = Logic Function(
    {required Logic candidateValue,
    required Logic selectedValue,
    required int candidateIndex,
    required Logic selectedIndex,
    required String name});

/// Prefers a candidate with a lower selection value.
Logic lowerAssociativeSelectionValue(
        {required Logic candidateValue,
        required Logic selectedValue,
        required int candidateIndex,
        required Logic selectedIndex,
        required String name}) =>
    candidateValue
        .lt(selectedValue)
        .named('${name}_prefer_lower_$candidateIndex');

/// Prefers a candidate with a higher selection value.
Logic higherAssociativeSelectionValue(
        {required Logic candidateValue,
        required Logic selectedValue,
        required int candidateIndex,
        required Logic selectedIndex,
        required String name}) =>
    candidateValue
        .gt(selectedValue)
        .named('${name}_prefer_higher_$candidateIndex');

/// Selects one entry from an associative match vector.
///
/// `selectionValues` may carry static priority, age, or another policy value.
/// With no values, entry indices are used, so the default selects the lowest
/// matching index. A custom `preference` can implement wrapping-age comparison.
/// {@category Memory}
class AssociativeMatchSelector extends Module {
  /// Number of selectable entries.
  final int entryCount;

  /// Width of the selected index.
  final int indexWidth;

  /// High when at least one entry is selected.
  Logic get valid => output('valid');

  /// Index of the selected entry.
  Logic get selectedIndex => output('selectedIndex');

  /// One-hot selected entry.
  Logic get selectedOneHot => output('selectedOneHot');

  /// Creates a composable associative match selector.
  AssociativeMatchSelector({
    required Logic matchVector,
    List<Logic>? selectionValues,
    AssociativeMatchPreference preference = lowerAssociativeSelectionValue,
    String selectionName = 'lower',
    super.name = 'associative_match_selector',
  })  : entryCount = matchVector.width,
        indexWidth = max(1, (matchVector.width - 1).bitLength),
        super(
          definitionName: _selectorDefinitionName(
              matchVector, selectionValues, selectionName),
        ) {
    if (matchVector.width < 1) {
      throw ArgumentError.value(
          matchVector, 'matchVector', 'Must not be empty.');
    }
    if (selectionName.isEmpty) {
      throw ArgumentError.value(
          selectionName, 'selectionName', 'Must not be empty.');
    }
    if (selectionValues != null &&
        (selectionValues.length != entryCount ||
            selectionValues.isEmpty ||
            selectionValues
                .any((value) => value.width != selectionValues.first.width))) {
      throw ArgumentError(
          'selectionValues must provide one equally sized value per entry.');
    }

    final localMatches =
        addInput('matchVector', matchVector, width: entryCount);
    final valueWidth = selectionValues?.first.width ?? indexWidth;
    final localValues = selectionValues == null
        ? List.generate(entryCount, (index) => Const(index, width: valueWidth))
        : List.generate(
            entryCount,
            (index) => addInput('selectionValue_$index', selectionValues[index],
                width: valueWidth));
    Logic found = Const(0);
    Logic selected = Const(0, width: indexWidth);
    Logic selectedValue = Const(0, width: valueWidth);
    for (var index = 0; index < entryCount; index++) {
      final preferred = preference(
          candidateValue: localValues[index],
          selectedValue: selectedValue,
          candidateIndex: index,
          selectedIndex: selected,
          name: name);
      if (preferred.width != 1) {
        throw ArgumentError.value(
            preference, 'preference', 'Must return a one-bit result.');
      }
      final choose = (localMatches[index] & (~found | preferred))
          .named('${name}_choose_$index');
      selected = mux(choose, Const(index, width: indexWidth), selected)
          .named('${name}_selected_index_$index');
      selectedValue = mux(choose, localValues[index], selectedValue)
          .named('${name}_selected_value_$index');
      found = (found | localMatches[index]).named('${name}_found_$index');
    }
    final oneHot = List.generate(
            entryCount,
            (index) => (found & selected.eq(index))
                .named('${name}_selected_one_hot_$index'))
        .rconcat()
        .named('${name}_selected_one_hot');

    addOutput('valid') <= found;
    addOutput('selectedIndex', width: indexWidth) <= selected;
    addOutput('selectedOneHot', width: entryCount) <= oneHot;
  }
}
