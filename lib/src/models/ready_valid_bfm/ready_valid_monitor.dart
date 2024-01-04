import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A [Monitor] for ready/valid protocol.
class ReadyValidMonitor extends Monitor<ReadyValidPacket> {
  final Logic clk;
  final Logic reset;
  final Logic ready;
  final Logic valid;
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
        if (data.previousValue == null) {
          logger.severe('WTF'); //TODO
        } else {
          add(ReadyValidPacket(data.previousValue!));
        }
      }
    });
  }
}
