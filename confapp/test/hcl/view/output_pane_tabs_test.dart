// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// output_pane_tabs_test.dart
// Tests generated-output pane and split-layout selection state.
//
// 2026 July 31
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:confapp/hcl/view/screen/output_pane_tabs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cross-probe navigation targets the opposite pane only when split', () {
    final tabs = OutputPaneTabs()..activePane = 1;
    expect(tabs.navigationPane, 1);

    tabs.setSplit([0, 1, 2], split: true);
    expect(tabs.navigationPane, 0);

    tabs.select(tabs.navigationPane, 1);
    expect(tabs.selectedLogicalTab(0), 1);
    expect(tabs.selectedLogicalTab(1), 2);
  });

  test('selecting an open tab swaps pane displays', () {
    final tabs = OutputPaneTabs()
      ..setSplit([0, 1, 2], split: true)
      ..select(0, 2);

    expect(tabs.selectedLogicalTab(0), 2);
    expect(tabs.selectedLogicalTab(1), 0);
  });

  test('pane selections stay within the enabled tabs', () {
    final tabs = OutputPaneTabs()..setSplit([1, 3], split: true);

    expect(tabs.selectedLogicalTab(0), 1);
    expect(tabs.selectedLogicalTab(1), 3);
  });
}
