// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_storage_status.dart
// Common retained-storage observability for ready/valid components.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Common retained-storage status exposed by ready/valid storage components.
///
/// [occupancy], [empty], and [full] describe registered or memory-retained
/// items. An item that passes through an empty fall-through stage in one cycle
/// is not counted as retained storage.
abstract interface class ReadyValidStorageStatus {
  /// Total number of items this component can retain.
  int get capacity;

  /// Number of currently retained items.
  Logic get occupancy;

  /// High when no item is retained.
  Logic get empty;

  /// High when every retained-storage slot is occupied.
  Logic get full;
}
