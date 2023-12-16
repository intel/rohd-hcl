import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

abstract class RoundRobinArbiter extends StatefulArbiter {
  factory RoundRobinArbiter(List<Logic> requests,
          {required Logic clk, required Logic reset}) =>
      MaskRoundRobinArbiter(requests, clk: clk, reset: reset);
}
