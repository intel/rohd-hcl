import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// An [Agent] for transmitting over a ready/valid protocol.
class ReadyValidTransmitterAgent extends ReadyValidAgent {
  late final Sequencer<ReadyValidPacket> sequencer;

  /// Creates an [Agent] for transmitting over a ready/valid protocol.
  ReadyValidTransmitterAgent({
    required super.clk,
    required super.reset,
    required super.ready,
    required super.valid,
    required super.data,
    required super.parent,
    double blockRate = 0,
    super.name = 'readyValidTransmitterAgent',
  }) {
    sequencer = Sequencer<ReadyValidPacket>('sequencer', this);
    ReadyValidTransmitterDriver(
      clk: clk,
      reset: reset,
      ready: ready,
      valid: valid,
      data: data,
      sequencer: sequencer,
      blockRate: blockRate,
      parent: this,
    );
  }
}
