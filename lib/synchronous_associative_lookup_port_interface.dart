// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// synchronous_associative_lookup_port_interface.dart
// Public typed synchronous associative lookup port.
//
// 2026 November 18
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/associative/associative_memory.dart'
    as implementation;

/// A fixed-latency associative lookup port preserving its key schema.
class SynchronousAssociativeLookupPortInterface<T extends Logic>
    extends implementation
    .SynchronousAssociativeLookupPortInterfaceImplementation<T> {
  /// Constructs a synchronous lookup port with the shape and type of [key].
  SynchronousAssociativeLookupPortInterface(super.key,
      {required super.indexWidth, super.matchEntryCount});

  /// Makes a copy with the same key schema and configuration.
  @override
  SynchronousAssociativeLookupPortInterface<T> clone() =>
      SynchronousAssociativeLookupPortInterface<T>(key,
          indexWidth: indexWidth, matchEntryCount: matchEntryCount);
}
