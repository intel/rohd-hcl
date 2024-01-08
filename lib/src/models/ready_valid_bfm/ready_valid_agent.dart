// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_agent.dart
// A generic agent for ready/valid protocol.
//
// 2024 January 5
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A generic agent for ready/valid protocol.
abstract class ReadyValidAgent extends Agent {
  /// The clock.
  final Logic clk;

  /// Active-high reset.
  final Logic reset;

  /// Ready signal.
  final Logic ready;

  /// Valid signal.
  final Logic valid;

  /// Data being transmitted.
  final Logic data;

  /// Creates a new agent.
  ReadyValidAgent({
    required this.clk,
    required this.reset,
    required this.ready,
    required this.valid,
    required this.data,
    required Component? parent,
    String name = 'readyValidComponent',
  }) : super(name, parent);
}
