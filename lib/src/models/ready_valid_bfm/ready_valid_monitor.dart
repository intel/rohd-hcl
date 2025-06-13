// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_monitor.dart
// A monitor for ready/valid protocol.
//
// 2024 January 5
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A [Monitor] for ready/valid protocol.
class ReadyValidMonitor extends Monitor<ReadyValidPacket> {
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

  /// Creates a new [ReadyValidMonitor].
  ReadyValidMonitor({
    required this.clk,
    required this.reset,
    required this.ready,
    required this.valid,
    required this.data,
    required Component? parent,
    String name = 'readyValidMonitor',
  }) : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await reset.nextNegedge;

    clk.posedge.listen((event) {
      if (!ready.previousValue!.isValid || !valid.previousValue!.isValid) {
        logger.severe('Both ready and valid must be valid for protocol,'
            ' but found ready=${ready.value} and valid=${valid.value}');
      } else if (ready.previousValue!.toBool() &&
          valid.previousValue!.toBool()) {
        add(ReadyValidPacket(data.previousValue!));
      }
    });
  }
}
