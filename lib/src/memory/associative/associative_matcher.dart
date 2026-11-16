// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// associative_matcher.dart
// Storage-independent associative match-vector generation.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';

/// Compares an associative query with one stored key.
typedef TypedAssociativeKeyComparator<T extends Logic> = Logic Function(
    {required T query,
    required T stored,
    required int index,
    required String name});

/// Compares flattened associative keys.
typedef AssociativeKeyComparator = TypedAssociativeKeyComparator<Logic>;

/// Creates an exact-key comparison.
Logic exactAssociativeKeyComparator(
        {required Logic query,
        required Logic stored,
        required int index,
        required String name}) =>
    storedLogicValuesEqual(query, stored).named('${name}_exact_match_$index');

/// Produces a match vector for typed keys without owning storage or selecting
/// one match.
///
/// One output bit corresponds to each candidate. Zero, one, and multiple
/// matches remain explicit so the selection policy can be composed separately.
/// {@category Memory}
class TypedAssociativeMatcher<T extends Logic> extends Module {
  /// Number of associatively compared candidates.
  final int entryCount;

  /// Width of every query and stored key.
  final int keyWidth;

  /// One bit per valid matching candidate.
  Logic get matchVector => output('matchVector');

  /// High when at least one candidate matches.
  Logic get hit => output('hit');

  /// High when more than one candidate matches.
  Logic get multipleMatches => output('multipleMatches');

  /// Creates storage-independent matching with typed query and key ports.
  TypedAssociativeMatcher({
    required T query,
    required List<T> storedKeys,
    required Logic validMask,
    TypedAssociativeKeyComparator<T> comparator = exactAssociativeKeyComparator,
    String comparisonName = 'exact',
    String name = 'associative_matcher',
  }) : this._(
          query: query,
          storedKeys: storedKeys,
          validMask: validMask,
          comparator: comparator,
          comparisonName: comparisonName,
          name: name,
          flatPorts: false,
        );

  TypedAssociativeMatcher._({
    required T query,
    required List<T> storedKeys,
    required Logic validMask,
    required TypedAssociativeKeyComparator<T> comparator,
    required String comparisonName,
    required bool flatPorts,
    required super.name,
  })  : entryCount = storedKeys.length,
        keyWidth = query.width,
        super(
          definitionName: 'AssociativeMatcher_E${storedKeys.length}_'
              'W${query.width}_'
              '${flatPorts ? '' : '${payloadShapeIdentity(query)}_'}'
              '$comparisonName',
        ) {
    if (storedKeys.isEmpty) {
      throw ArgumentError.value(storedKeys, 'storedKeys', 'Must not be empty.');
    }
    if (storedKeys.any((key) => key.width != keyWidth) ||
        validMask.width != entryCount) {
      throw ArgumentError(
          'Stored keys must match the query width and validMask must have '
          'one bit per entry.');
    }
    if (!flatPorts &&
        storedKeys.any((key) =>
            !sameDeclaredPayloadShape(query, key, ignoreConstantNames: true))) {
      throw ArgumentError('Stored keys must match the query payload shape.');
    }
    if (comparisonName.isEmpty) {
      throw ArgumentError.value(
          comparisonName, 'comparisonName', 'Must not be empty.');
    }

    final localQuery = flatPorts
        ? addInput('query', query, width: keyWidth) as T
        : addTypedInput<T>('query', query);
    final localValidMask = addInput('validMask', validMask, width: entryCount);
    final localStoredKeys = List.generate(
        entryCount,
        (index) => flatPorts
            ? addInput('storedKey_$index', storedKeys[index], width: keyWidth)
                as T
            : addTypedInput<T>('storedKey_$index', storedKeys[index]));
    final matches = List.generate(
        entryCount,
        (index) => (localValidMask[index] &
                comparator(
                    query: localQuery,
                    stored: localStoredKeys[index],
                    index: index,
                    name: name))
            .named('${name}_match_$index'));
    if (matches.any((match) => match.width != 1)) {
      throw ArgumentError.value(comparator, 'comparator',
          'Must return a one-bit result for every entry.');
    }
    final matchesLogic = matches.rconcat().named('${name}_matches');
    final anyMatch = matchesLogic.or().named('${name}_any_match');
    final moreThanOne =
        (matchesLogic & (matchesLogic - Const(1, width: entryCount)))
            .or()
            .named('${name}_more_than_one_match');

    addOutput('matchVector', width: entryCount) <= matchesLogic;
    addOutput('hit') <= anyMatch;
    addOutput('multipleMatches') <= moreThanOne;
  }
}

/// Compatibility matcher with flattened query and stored-key module ports.
///
/// Use [TypedAssociativeMatcher] to retain structured key types.
@Deprecated('Use TypedAssociativeMatcher to preserve key types.')
class AssociativeMatcher extends TypedAssociativeMatcher<Logic> {
  /// Creates storage-independent associative matching with flat ports.
  @Deprecated('Use TypedAssociativeMatcher to preserve key types.')
  AssociativeMatcher({
    required super.query,
    required super.storedKeys,
    required super.validMask,
    super.comparator = exactAssociativeKeyComparator,
    super.comparisonName = 'exact',
    super.name = 'associative_matcher',
  }) : super._(flatPorts: true);
}
