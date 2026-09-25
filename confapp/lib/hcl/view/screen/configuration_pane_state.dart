// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// configuration_pane_state.dart
// Presentation state for the component configuration pane.
//
// 2026 July 31
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

/// Presentation state for the combined component and configuration pane.
class ConfigurationPaneState {
  /// Whether the configuration pane is docked in the layout.
  bool isPinned = true;

  /// Whether the configuration overlay is visible when it is not pinned.
  bool isOverlayOpen = true;

  /// Changes whether the pane is [pinned] and opens it in the new layout.
  void setPinned({required bool pinned}) {
    isPinned = pinned;
    isOverlayOpen = true;
  }

  /// Opens the configuration overlay when the pane is not pinned.
  void showOverlay() {
    if (!isPinned) {
      isOverlayOpen = true;
    }
  }

  /// Hides the configuration overlay when the pane is not pinned.
  void hideOverlay() {
    if (!isPinned) {
      isOverlayOpen = false;
    }
  }
}
