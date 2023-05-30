// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// multiplier.dart
// Abstract class of of multiplier module implementation. All multiplier module
// need to inherit this module to ensure consistency.
//
// 2023 May 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>
//

import 'package:rohd/rohd.dart';

/// An abstract class for all multiplier implementation.
abstract class Multiplier extends Module {
  /// The list of inputs to multiply. Length of inputs must be two.
  List<Logic> toMultiply;

  /// The multiplication results of the multiplier.
  Logic get product;

  /// Take a list of inputs Logic [toMultiply] and return the
  /// product result [product].
  Multiplier({required this.toMultiply, super.name});
}
