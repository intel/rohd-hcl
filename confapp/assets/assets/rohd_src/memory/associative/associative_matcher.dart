// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// associative_matcher.dart
// Storage-independent associative match-vector generation.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';

/// Compares an associative query with one stored key.
typedef AssociativeKeyComparator = Logic Function(
    {required Logic query,
    required Logic stored,
    required int index,
    required String name});

/// Creates an exact-key comparison.
Logic exactAssociativeKeyComparator(
        {required Logic query,
        required Logic stored,
        required int index,
        required String name}) =>
    storedLogicValuesEqual(query, stored).named('${name}_exact_match_$index');

/// Produces a match vector without owning storage or choosing one match.
///
/// One output bit corresponds to each candidate. Zero, one, and multiple
/// matches remain explicit so the selection policy can be composed separately.
/// {@category Memory}
class AssociativeMatcher extends Module {
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

  /// Creates storage-independent associative matching.
  AssociativeMatcher({
    required Logic query,
    required List<Logic> storedKeys,
    required Logic validMask,
    AssociativeKeyComparator comparator = exactAssociativeKeyComparator,
    String comparisonName = 'exact',
    super.name = 'associative_matcher',
  })  : entryCount = storedKeys.length,
        keyWidth = query.width,
        super(
          definitionName: 'AssociativeMatcher_E${storedKeys.length}_'
              'W${query.width}_$comparisonName',
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
    if (comparisonName.isEmpty) {
      throw ArgumentError.value(
          comparisonName, 'comparisonName', 'Must not be empty.');
    }

    final localQuery = addInput('query', query, width: keyWidth);
    final localValidMask = addInput('validMask', validMask, width: entryCount);
    final localStoredKeys = List.generate(
        entryCount,
        (index) =>
            addInput('storedKey_$index', storedKeys[index], width: keyWidth));
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
