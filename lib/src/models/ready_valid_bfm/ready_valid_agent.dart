import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';

abstract class ReadyValidAgent extends Agent {
  final Logic clk;
  final Logic reset;
  final Logic ready;
  final Logic valid;
  final Logic data;

  ReadyValidAgent(
      {required this.clk,
      required this.reset,
      required this.ready,
      required this.valid,
      required this.data,
      String name = 'readyValidComponent',
      required Component? parent})
      : super(name, parent);
}
