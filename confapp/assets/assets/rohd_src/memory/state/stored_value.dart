// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// stored_value.dart
// Normalization of values entering memory state.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Converts high-impedance bits to unknowns while preserving other bits.
Logic normalizeStoredLogic(Logic value) => value ^ Const(0, width: value.width);

/// Converts high-impedance bits to unknowns while preserving other bits.
LogicValue normalizeStoredValue(LogicValue value) =>
    value ^ LogicValue.filled(value.width, LogicValue.zero);

/// Four-state selection, preserving equal bits when [select] is unknown.
LogicValue selectLogicValue(
    LogicValue select, LogicValue whenTrue, LogicValue whenFalse) {
  if (select.width != 1 || whenTrue.width != whenFalse.width) {
    throw ArgumentError('Invalid four-state selection widths.');
  }
  if (select == LogicValue.one) {
    return whenTrue;
  }
  if (select == LogicValue.zero) {
    return whenFalse;
  }
  return LogicValue.of([
    for (var bit = 0; bit < whenTrue.width; bit++)
      if (whenTrue[bit] == whenFalse[bit]) whenTrue[bit] else LogicValue.x
  ]);
}

/// Four-state equality that returns zero for any definitely mismatching bit.
Logic storedLogicValuesEqual(Logic left, Logic right) {
  if (left.width != right.width) {
    throw ArgumentError('Value widths must match.');
  }
  return [for (var bit = 0; bit < left.width; bit++) left[bit].eq(right[bit])]
      .reduce((first, second) => first & second);
}

/// Matches address bits while preserving uncertainty from X or Z bits.
Logic storedAddressMatches(Logic left, Logic right) =>
    storedLogicValuesEqual(left, right);

/// Four-state equality that returns zero for any definitely mismatching bit.
LogicValue storedValuesEqual(LogicValue left, LogicValue right) {
  if (left.width != right.width) {
    throw ArgumentError('Value widths must match.');
  }
  var result = LogicValue.one;
  for (var bit = 0; bit < left.width; bit++) {
    result &= left[bit].eq(right[bit]);
  }
  return result;
}

/// Matches known index bits while preserving uncertainty from X or Z bits.
Logic storedIndexMatches(Logic address, int index) {
  if (BigInt.from(index) >= BigInt.one << address.width) {
    return Const(0);
  }
  return storedAddressMatches(address, Const(index, width: address.width));
}

/// Four-state equality with a constant index, matching Verilog equality.
LogicValue storedValueIndexMatches(LogicValue address, int index) {
  if (BigInt.from(index) >= BigInt.one << address.width) {
    return LogicValue.zero;
  }
  var result = LogicValue.one;
  for (var bit = 0; bit < address.width; bit++) {
    result &= address[bit].eq(LogicValue.ofInt((index >> bit) & 1, 1));
  }
  return result;
}
