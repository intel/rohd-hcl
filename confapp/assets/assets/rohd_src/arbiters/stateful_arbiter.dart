// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// stateful_arbiter.dart
// Implementation of an arbiter that holds state.
//
// 2023 December
// Author: Max Korbel <max.korbel@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An [Arbiter] which holds state in order to arbitrate.
abstract class StatefulArbiter extends Arbiter {
  /// The clock used for sequential elements.
  ///
  /// Should only be used by implementations.
  @protected
  late final Logic clk = input('clk');

  /// The reset used for sequential elements (active high).
  ///
  /// Should only be used by implementations.
  @protected
  late final Logic reset = input('reset');

  /// Creates a new [StatefulArbiter] with associated [clk] and [reset].
  StatefulArbiter(super.requests,
      {required Logic clk,
      required Logic reset,
      super.name = 'stateful_arbiter',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName:
                definitionName ?? 'StatefulArbiter_W${requests.length}') {
    addInput('clk', clk);
    addInput('reset', reset);
  }
}
