// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory_state_access.dart
// Common interface for software memory state access.
//
// 2026 October 16
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Optional raw software state access, separate from hardware port exposure.
///
/// [Image] is family-specific: a CSR image may contain heterogeneous widths,
/// while RAM may require uniform geometry. Addresses use the family's logical
/// units, never implicit byte scaling. Invalid addresses and widths throw.
abstract interface class MemoryStateAccess<Image extends Object> {
  /// Reads raw state; null means a valid but unpopulated sparse address.
  LogicValue? peek(int address);

  /// Replaces raw state without architectural writes, W1C effects, or pulses.
  void poke(int address, LogicValue value);

  /// Captures detached state without allocating hardware signals.
  Image snapshot();

  /// Validates the complete image before changing state.
  ///
  /// Overlay retains unspecified entries. Replace uses the family's initial
  /// state for unspecified entries (CSR reset values; empty sparse storage).
  void load(Image image, {bool replace = false});
}
