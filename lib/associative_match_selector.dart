// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// associative_match_selector.dart
// Public typed associative match selector.
//
// 2026 November 18
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/associative/associative_match_selector.dart'
    as implementation;

/// Selects an associative match using typed selection values.
class AssociativeMatchSelector<T extends Logic>
    extends implementation.AssociativeMatchSelectorImplementation<T> {
  /// Constructs a selector with matching typed selection value ports.
  AssociativeMatchSelector(
      {required super.matchVector,
      required super.selectionValues,
      super.preference,
      super.selectionName,
      super.name});
}
