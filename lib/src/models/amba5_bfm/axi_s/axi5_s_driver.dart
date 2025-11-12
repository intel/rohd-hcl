// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_s_driver.dart
// A driver for AXI-S transactions.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A driver for the [Axi5StreamInterface] interface.
class Axi5StreamDriver extends PendingClockedDriver<Axi5StreamPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 Stream Interface.
  final Axi5StreamInterface stream;

  /// Capture link utilization/bandwidth over time
  ///
  /// Based on the % of cycles in which we want to send a transaction
  /// and actually can (i.e., credits available).
  num get linkUtilization => _linkValidAndReadyCount / _linkValidCount;
  int _linkValidCount = 0;
  int _linkValidAndReadyCount = 0;

  /// Should we capture link utilization.
  ///
  /// This is helpful to exclude certain time windows from the aggregate
  /// calculation.
  void toggleLinkUtilization({bool on = true}) => _linkUtilizationEnabled = on;
  bool _linkUtilizationEnabled = true;

  /// Creates a new [Axi5StreamDriver].
  Axi5StreamDriver({
    required Component parent,
    required this.sys,
    required this.stream,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'axi5StreamDriver',
  }) : super(
          name,
          parent,
          clk: sys.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      stream.valid.put(0);
      stream.id?.put(0);
      stream.data?.put(0);
      stream.user?.put(0);
      stream.strb?.put(0);
      stream.keep?.put(0);
      stream.dest?.put(0);
      stream.last?.put(0);
      stream.wakeup?.put(0);
    });

    // wait for reset to complete before driving anything
    await sys.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      if (pendingSeqItems.isNotEmpty) {
        await _drivePacket(pendingSeqItems.removeFirst());
      } else {
        await sys.clk.nextPosedge;
      }
    }
  }

  /// Drives a packet onto the interface.
  Future<void> _drivePacket(Axi5StreamPacket packet) async {
    logger.info('Driving stream packet.');
    await _driveStreamPacket(packet);
  }

  Future<void> _driveStreamPacket(Axi5StreamPacket packet) async {
    if (_linkUtilizationEnabled) {
      _linkValidCount++;
    }
    Simulator.injectAction(() async {
      stream.valid.put(1);
      stream.id?.put(packet.id ?? 0);
      stream.user?.put(packet.user ?? 0);
      stream.data?.put(packet.data);
      stream.strb?.put(
          packet.strb ?? LogicValue.filled(stream.strbWidth, LogicValue.one));
      stream.keep?.put(
          packet.keep ?? LogicValue.filled(stream.strbWidth, LogicValue.one));
      stream.dest?.put(packet.dest ?? 0);
      stream.last?.put(packet.last ?? 1);
      stream.wakeup?.put(packet.wakeup ?? 0);
    });

    // need to hold the request until receiver is ready
    await sys.clk.nextPosedge;
    while (!stream.ready!.previousValue!.toBool()) {
      if (_linkUtilizationEnabled) {
        _linkValidCount++;
      }
      await sys.clk.nextPosedge;
    }
    if (_linkUtilizationEnabled) {
      _linkValidAndReadyCount++;
    }

    // now we can release the request
    // in the future, we may want to wait for the response to complete
    Simulator.injectAction(() {
      stream.valid.put(0);
      packet.complete();
    });
  }
}
