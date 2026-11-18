// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// associative_matcher.dart
// Public typed associative matcher.
//
// 2026 November 18
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/associative/associative_matcher.dart'
    as implementation;

/// Produces a match vector for typed keys.
class AssociativeMatcher<T extends Logic>
    extends implementation.AssociativeMatcherImplementation<T> {
  /// Constructs a matcher with typed query and stored-key ports.
  AssociativeMatcher(
      {required super.query,
      required super.storedKeys,
      required super.validMask,
      super.comparator,
      super.comparisonName,
      super.name});
}
