// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi_s_utils.dart
// Utility functionality for AXI-S HW.
//
// 2025 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

/// State of sending beats on the AXI-S interface.
enum AxiStreamBeatState {
  /// Not currently sending anything.
  idle,

  /// Currently sending beats.
  working,
}
