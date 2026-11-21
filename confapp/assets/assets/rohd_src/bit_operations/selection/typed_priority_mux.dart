// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// typed_priority_mux.dart
// Public typed priority multiplexer.
//
// 2026 November 18
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/bit_operations/selection/priority_mux.dart'
    as implementation;

/// Selects the lowest-index asserted case, preserving its payload type.
class PriorityMux<T extends Logic>
    extends implementation.PriorityMuxImplementation<T> {
  /// Constructs a priority mux whose cases match the default payload.
  PriorityMux(super.selector, super.cases, super.defaultValue,
      {super.name,
      super.reserveName,
      super.reserveDefinitionName,
      super.definitionName});
}
