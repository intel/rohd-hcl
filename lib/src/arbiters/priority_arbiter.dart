import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An [Arbiter] which always picks the lowest-indexed request.
class PriorityArbiter extends Arbiter {
  /// Constructs an arbiter where the grant is given to the lowest-indexed
  /// request.
  PriorityArbiter(super.requests, {super.name = 'priority_arbiter'}) {
    Combinational([
      CaseZ(requests.rswizzle(), conditionalType: ConditionalType.priority, [
        for (var i = 0; i < count; i++)
          CaseItem(
            Const(
              LogicValue.filled(count, LogicValue.z).withSet(i, LogicValue.one),
            ),
            [for (var g = 0; g < count; g++) grants[g] < (i == g ? 1 : 0)],
          )
      ], defaultItem: [
        for (var g = 0; g < count; g++) grants[g] < 0
      ]),
    ]);
  }
}
