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

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An abstract class for all multiplier implementation.
abstract class Multiplier extends Module {
  /// The input to the multiplier pin [a].
  @protected
  final Logic a;

  /// The input to the multiplier pin [b].
  @protected
  final Logic b;

  /// The multiplication results of the multiplier.
  Logic get product;

  /// Take input [a] and input [b] and return the
  /// [product] of the multiplication result.
  Multiplier(this.a, this.b, {super.name}) {
    if (a.width != b.width) {
      throw RohdHclException('inputs of a and b should have same width.');
    }
  }
}
