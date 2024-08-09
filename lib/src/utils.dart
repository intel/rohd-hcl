// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// utils.dart
// Various utilities helpful for working with the component library

import 'dart:math';
import 'package:rohd/rohd.dart';

/// Computes the bit width needed to store [w] addresses.
int log2Ceil(int w) => (log(w) / log(2)).ceil();

/// This extension will eventually move to ROHD once it is proven useful
extension LogicValueBitString on LogicValue {
  /// Simplest version of bit string representation as shorthand
  String get bitString => toString(includeWidth: false);
}
