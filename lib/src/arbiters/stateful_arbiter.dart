import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

abstract class StatefulArbiter extends Arbiter {
  @protected
  late final Logic clk = input('clk');

  @protected
  late final Logic reset = input('reset');

  StatefulArbiter(super.requests, {required Logic clk, required Logic reset}) {
    addInput('clk', clk);
    addInput('reset', reset);
  }
}
