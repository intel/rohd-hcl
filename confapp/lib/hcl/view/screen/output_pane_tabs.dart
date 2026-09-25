// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// output_pane_tabs.dart
// Selection and split-layout state for generated-output panes.
//
// 2026 July 31
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

/// Selection state for the generated-output panes.
class OutputPaneTabs {
  /// Creates pane selection state with initial logical tab selections.
  OutputPaneTabs({int primaryLogicalTab = 0, int secondaryLogicalTab = 1})
      : _selectedLogicalTabs = [primaryLogicalTab, secondaryLogicalTab];

  final List<int> _selectedLogicalTabs;
  List<int> _visibleTabs = const [];

  /// Whether the generated output is displayed in two panes.
  bool isSplit = false;

  /// The pane most recently selected by the user.
  int activePane = 0;

  /// Returns the logical tab displayed in [paneIndex].
  int selectedLogicalTab(int paneIndex) => _selectedLogicalTabs[paneIndex];

  /// The pane that should receive cross-probe navigation.
  int get navigationPane => isSplit ? 1 - activePane : activePane;

  /// Whether [logicalIndex] is currently displayed in either pane.
  bool isDisplayed(int logicalIndex) =>
      _selectedLogicalTabs[0] == logicalIndex ||
      (isSplit && _selectedLogicalTabs[1] == logicalIndex);

  /// Enables or disables split panes and updates the available tabs.
  void setSplit(List<int> visibleTabs, {required bool split}) {
    isSplit = split;
    _visibleTabs = List<int>.of(visibleTabs);
    if (!isSplit) {
      activePane = 0;
    }
    normalize(visibleTabs);
  }

  /// Selects [logicalIndex] for [paneIndex].
  void select(int paneIndex, int logicalIndex) {
    final previousLogical = _selectedLogicalTabs[paneIndex];
    final otherPaneIndex = 1 - paneIndex;
    if (isSplit && _selectedLogicalTabs[otherPaneIndex] == logicalIndex) {
      _selectedLogicalTabs[otherPaneIndex] = _visibleTabs.firstWhere(
        (tab) => tab != logicalIndex && tab != previousLogical,
        orElse: () => previousLogical,
      );
    } else if (isSplit && !_selectedLogicalTabs.contains(logicalIndex)) {
      _selectedLogicalTabs[otherPaneIndex] = previousLogical;
    }
    _selectedLogicalTabs[paneIndex] = logicalIndex;
  }

  /// Moves pane selections to valid entries in [visibleTabs].
  void normalize(List<int> visibleTabs) {
    if (visibleTabs.isEmpty) {
      return;
    }

    for (var paneIndex = 0;
        paneIndex < _selectedLogicalTabs.length;
        paneIndex++) {
      if (!visibleTabs.contains(_selectedLogicalTabs[paneIndex])) {
        _selectedLogicalTabs[paneIndex] = visibleTabs.first;
      }
    }

    if (isSplit &&
        visibleTabs.length > 1 &&
        _selectedLogicalTabs[0] == _selectedLogicalTabs[1]) {
      _selectedLogicalTabs[1] = visibleTabs.firstWhere(
          (logicalIndex) => logicalIndex != _selectedLogicalTabs[0]);
    }
  }
}
