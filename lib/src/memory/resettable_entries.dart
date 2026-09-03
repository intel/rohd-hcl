// Copyright (C) 2025 Intel Corporation
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
    if (resetValue is List) {
      if (resetValue.length != numEntries) {
        throw RohdHclException('resetValue list length (${resetValue.length})'
            ' does not match numEntries ($numEntries)');
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

      return [
        for (var i = 0; i < numEntries; i++)
          _makeResetValue(resetValue[i],
              name: 'resetValue_$i', entryWidth: entryWidth)
      ];
    }

    final commonResetValue =
        _makeResetValue(resetValue, name: 'resetValue', entryWidth: entryWidth);
    return List.generate(numEntries, (_) => commonResetValue);
  }

  Logic _makeResetValue(dynamic resetValue,
      {required String name, required int entryWidth}) {
    _validateResetValue(resetValue, entryWidth: entryWidth);
    final parameter = StaticOrRuntimeValue<dynamic>.ofDynamic(resetValue,
        name: name, defaultValue: 0, convertStatic: (value) => value);
    return parameter.resolve(this,
        staticToLogic: (value) => Const(value, width: entryWidth));
  }

  void _validateResetValue(dynamic resetVal, {required int entryWidth}) {
    if ((resetVal is Logic && resetVal.width != entryWidth) ||
        (resetVal is LogicValue && resetVal.width != entryWidth)) {
      throw RohdHclException(
          'Entry $resetVal does not have expected width $entryWidth,');
    }
  }
}
