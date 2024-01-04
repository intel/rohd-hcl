// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_receiver_agent.dart
// An agent for receiving over a ready/valid protocol.
//
// 2024 January 5
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// An [Agent] for receiving over a ready/valid protocol.
class ReadyValidReceiverAgent extends ReadyValidAgent {
  /// Probability (from 0 to 1) of blocking a ready from being driven.
  ///
  /// 0 -> never block, accept transactions as soon as possible.
  final double blockRate;

  /// Creates an [Agent] for receiving over a ready/valid protocol.
  ReadyValidReceiverAgent({
    required super.clk,
    required super.reset,
    required super.ready,
    required super.valid,
    required super.data,
    required super.parent,
    this.blockRate = 0,
    super.name = 'readyValidReceiverAgent',
  });

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final random = Test.random ?? Random();

    await _drive(LogicValue.zero);

    await reset.nextNegedge;

    while (!Simulator.simulationHasEnded) {
      final doBlock = random.nextDouble() < blockRate;

      await _drive(doBlock ? LogicValue.zero : LogicValue.one);
    }
  }

  Future<void> _drive(LogicValue newReady) async {
    ready.inject(newReady);
    await clk.nextPosedge;
  }
}
