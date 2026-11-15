// Copyright (C) 2025-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// entry_resettable.dart
// Mixin for adding per-entry reset control on a structure with many entries.
//
// 2025 September 2
// Author: Max Korbel <max.korbel@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Provides functionality for structures with many entries to have various
/// reset capabilities.
mixin ResettableEntries on Module {
  /// Accepts multiple types to provide a mapping to reset all entries of a
  /// structure with the same or various reset values.
  ///
  /// Accepted types include:
  /// - [Logic]: all reset values are the same, based on that signal.
  /// - Other [LogicValue.of]-compatible types: all reset values are the same,
  ///   based on that static value.
  /// - [List]: each entry can have a different reset value, corresponding to
  ///   the index in the list.
  /// - [Map<int, dynamic>]: each entry can have a different reset value,
  ///   specified by the key-value (key is index) pairs in the map. Unspecified
  ///   entries will get the default of `0`.
  /// - `null`: all reset values are the same with the default of `0`.
  ///
  /// For types that include a [Logic], proper [input] ports are created.
  @protected
  List<Logic> makeResetValues(dynamic resetValue,
      {required int numEntries, required int entryWidth}) {
    if (resetValue == null) {
      return List.generate(numEntries, (_) => Const(0, width: entryWidth));
    } else if (resetValue is Logic) {
      _validateResetValue(resetValue, entryWidth: entryWidth);
      final resetValueInput = _makeResetValue(resetValue,
          name: 'resetValue', entryWidth: entryWidth);
      return List.generate(numEntries, (_) => resetValueInput);
    } else if (resetValue is List) {
      if (resetValue.length != numEntries) {
        throw RohdHclException('resetValue list length (${resetValue.length})'
            ' does not match numEntries ($numEntries)');
      }

      for (final resetVal in resetValue) {
        _validateResetValue(resetVal, entryWidth: entryWidth);
      }

      return [
        for (final (i, resetVal) in resetValue.indexed)
          _makeResetValue(resetVal,
              name: 'resetValue_$i', entryWidth: entryWidth)
      ];
    } else if (resetValue is Map<int, dynamic>) {
      if (resetValue.keys.any((key) => key < 0 || key >= numEntries)) {
        throw RohdHclException('resetValue map has keys outside of valid'
            ' range (0 to ${numEntries - 1})');
      }

      for (final resetVal in resetValue.values) {
        _validateResetValue(resetVal, entryWidth: entryWidth);
      }

      return [
        for (var i = 0; i < numEntries; i++)
          _makeResetValue(resetValue[i],
              name: 'resetValue_$i', entryWidth: entryWidth)
      ];
    } else {
      return List.generate(
          numEntries, (_) => Const(resetValue, width: entryWidth));
    }
  }

  Logic _makeResetValue(Object? resetValue,
      {required String name, required int entryWidth}) {
    final control = StaticOrRuntimeControl<Object>(
        name: name,
        staticConfig: resetValue is Logic ? 0 : resetValue ?? 0,
        runtimeConfig: resetValue is Logic ? resetValue : null);
    return control.resolveTyped(this,
        staticToLogic: (value) => Const(value, width: entryWidth),
        reuseExisting: false);
  }

  void _validateResetValue(dynamic resetVal, {required int entryWidth}) {
    if ((resetVal is Logic && resetVal.width != entryWidth) ||
        (resetVal is LogicValue && resetVal.width != entryWidth)) {
      throw RohdHclException(
          'Entry $resetVal does not have expected width $entryWidth,');
    }
  }
}
