import 'dart:async';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/models/ready_valid_bfm/ready_valid_packet.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// An [Agent] for transmitting over a ready/valid protocol.
class ReadyValidTransmitterDriver
    extends PendingClockedDriver<ReadyValidPacket> {
  final Logic clk;
  final Logic reset;
  final Logic ready;
  final Logic valid;
  final Logic data;

  /// Probability (from 0 to 1) of blocking a valid from being driven.
  ///
  /// 0 -> never block, send transactions as soon as possible
  final double blockRate;

  /// Creates an [Agent] for transmitting over a ready/valid protocol.
  ReadyValidTransmitterDriver({
    required this.clk,
    required this.reset,
    required this.ready,
    required this.valid,
    required this.data,
    required super.sequencer,
    required Component? parent,
    this.blockRate = 0,
    String name = 'readyValidTransmitterDriver',
    super.dropDelayCycles = 30,
  }) : super(name, parent, clk: clk);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final random = Test.random ?? Random();

    await _drive(null);

    await reset.nextNegedge;

    while (!Simulator.simulationHasEnded) {
      final doBlock = random.nextDouble() < blockRate;

      if (pendingSeqItems.isNotEmpty && !doBlock) {
        await _drive(pendingSeqItems.removeFirst());
      } else {
        await _drive(null);
      }
    }
  }

  Future<void> _drive(ReadyValidPacket? pkt) async {
    if (pkt == null) {
      valid.inject(0);
      data.inject(LogicValue.x);

      await clk.nextPosedge;
    } else {
      valid.inject(1);

      assert(pkt.data.width == data.width, 'Data widths should match.');
      data.inject(pkt.data);

      // wait for it to be accepted
      await clk.nextPosedge;
      while (!ready.previousValue!.toBool()) {
        await clk.nextPosedge;
      }
    }
  }
}
