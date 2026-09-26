// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// configuration_pane_state_test.dart
// Tests component configuration pane presentation state.
//
// 2026 July 31
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:confapp/hcl/view/screen/configuration_pane_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('configuration pane starts docked and open', () {
    final state = ConfigurationPaneState();

    expect(state.isPinned, isTrue);
    expect(state.isOverlayOpen, isTrue);
  });

  test('changing layout mode opens the pane', () {
    final state = ConfigurationPaneState()..setPinned(pinned: false);

    expect(state.isPinned, isFalse);
    expect(state.isOverlayOpen, isTrue);

    state
      ..hideOverlay()
      ..setPinned(pinned: true);
    expect(state.isPinned, isTrue);
    expect(state.isOverlayOpen, isTrue);
  });

  test('only an unpinned pane auto-hides', () {
    final state = ConfigurationPaneState()..hideOverlay();
    expect(state.isOverlayOpen, isTrue);

    state
      ..setPinned(pinned: false)
      ..hideOverlay();
    expect(state.isOverlayOpen, isFalse);

    state.showOverlay();
    expect(state.isOverlayOpen, isTrue);
  });
}
