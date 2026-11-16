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
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

String _selectorDefinitionName(
    Logic matchVector, List<Logic>? selectionValues, String selectionName,
    {required bool flatPorts}) {
  final valuesName = selectionValues == null || selectionValues.isEmpty
      ? 'I'
      : 'V${selectionValues.first.width}';
  final shapeName =
      flatPorts || selectionValues == null || selectionValues.isEmpty
          ? ''
          : '${payloadShapeIdentity(selectionValues.first)}_';
  return 'AssociativeMatchSelector_E${matchVector.width}_'
      '${valuesName}_$shapeName$selectionName';
}

/// Determines whether a candidate should replace the selected match.
typedef TypedAssociativeMatchPreference<T extends Logic> = Logic Function(
    {required T candidateValue,
    required T selectedValue,
    required int candidateIndex,
    required Logic selectedIndex,
    required String name});

/// Determines preference between flattened selection values.
typedef AssociativeMatchPreference = TypedAssociativeMatchPreference<Logic>;

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

LogicValue _initialSelectionValue(Logic template) {
  final leaves =
      template is LogicStructure ? template.leafElements : <Logic>[template];
  return leaves
      .map((leaf) {
        final zero = LogicValue.filled(leaf.width, LogicValue.zero);
        if (leaf is! LogicEnum || leaf.mapping.containsValue(zero)) {
          return zero;
        }
        return leaf.mapping.values
            .reduce((a, b) => a.toBigInt() < b.toBigInt() ? a : b);
      })
      .toList()
      .rconcat();
}

/// Selects one entry from an associative match vector using typed values.
///
/// Selection values may carry priority, age, or another policy value. The
/// default preference calls the payload's `lt` operation; a custom preference
/// can compare fields or implement wrapping-age comparison. The preference
/// must return one bit and is evaluated for every entry, including before a
/// match has been found. Initially the selected index and value bits are zero,
/// except enum leaves without a zero encoding use their lowest encoding.
/// {@category Memory}
class TypedAssociativeMatchSelector<T extends Logic> extends Module {
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

  /// Creates a selector with matching typed selection value ports.
  TypedAssociativeMatchSelector({
    required Logic matchVector,
    required List<T> selectionValues,
    TypedAssociativeMatchPreference<T> preference =
        lowerAssociativeSelectionValue,
    String selectionName = 'lower',
    String name = 'associative_match_selector',
  }) : this._(
          matchVector: matchVector,
          selectionValues: selectionValues,
          preference: preference,
          selectionName: selectionName,
          name: name,
          flatPorts: false,
        );

  TypedAssociativeMatchSelector._({
    required Logic matchVector,
    required List<T>? selectionValues,
    required TypedAssociativeMatchPreference<T> preference,
    required String selectionName,
    required bool flatPorts,
    required super.name,
  })  : entryCount = matchVector.width,
        indexWidth = max(1, (matchVector.width - 1).bitLength),
        super(
          definitionName: _selectorDefinitionName(
              matchVector, selectionValues, selectionName,
              flatPorts: flatPorts),
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
    if (!flatPorts &&
        selectionValues != null &&
        selectionValues.any((value) => !sameDeclaredPayloadShape(
            selectionValues.first, value,
            ignoreConstantNames: true))) {
      throw ArgumentError(
          'Selection values must have matching payload shapes.');
    }

    final localMatches =
        addInput('matchVector', matchVector, width: entryCount);
    final valueWidth = selectionValues?.first.width ?? indexWidth;
    final List<T> localValues;
    if (selectionValues == null) {
      localValues = List.generate(
          entryCount, (index) => Const(index, width: valueWidth) as T);
    } else {
      localValues = List.generate(
          entryCount,
          (index) => flatPorts
              ? addInput('selectionValue_$index', selectionValues[index],
                  width: valueWidth) as T
              : addTypedInput<T>(
                  'selectionValue_$index', selectionValues[index]));
    }
    Logic found = Const(0);
    Logic selected = Const(0, width: indexWidth);
    var selectedValue = flatPorts
        ? Const(0, width: valueWidth) as T
        : (localValues.first.cloneTyped(name: 'initialSelectedValue')
          ..gets(Const(_initialSelectionValue(localValues.first))));
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
      selectedValue = flatPorts
          ? mux<T>(choose, localValues[index], selectedValue)
              .named('${name}_selected_value_$index') as T
          : mux<T>(choose, localValues[index], selectedValue,
              outputGenerator: ({name}) =>
                  localValues.first.cloneTyped(name: name));
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

/// Compatibility selector with flattened selection value ports.
@Deprecated('Use TypedAssociativeMatchSelector to preserve selection types.')
class AssociativeMatchSelector extends TypedAssociativeMatchSelector<Logic> {
  /// Creates a selector using packed values or entry indices.
  @Deprecated('Use TypedAssociativeMatchSelector to preserve selection types.')
  AssociativeMatchSelector({
    required super.matchVector,
    super.selectionValues,
    super.preference = lowerAssociativeSelectionValue,
    super.selectionName = 'lower',
    super.name = 'associative_match_selector',
  }) : super._(flatPorts: true);
}
