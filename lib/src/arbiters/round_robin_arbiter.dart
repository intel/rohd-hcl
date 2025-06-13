// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// round_robin_arbiter.dart
// Interface for round-robin arbiters.
//
// 2023 December
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [StatefulArbiter] which fairly arbitrates between requests.
abstract class RoundRobinArbiter extends StatefulArbiter {
  /// By default, creates an instance of a [MaskRoundRobinArbiter].
  factory RoundRobinArbiter(List<Logic> requests,
          {required Logic clk, required Logic reset}) =>
      MaskRoundRobinArbiter(requests, clk: clk, reset: reset);
}
