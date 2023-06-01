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
  /// The input to the multiplier pin [a].
  Logic a;

  /// The input to the multiplier pin [b].
  Logic b;

  /// The multiplication results of the multiplier.
  Logic get product;

  /// Take input [a] and input [b] and return the
  /// [product] of the multiplication result.
  Multiplier(this.a, this.b, {super.name});
}
