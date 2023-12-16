import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A round-robin arbiter.
class RotateRoundRobinArbiter extends StatefulArbiter
    implements RoundRobinArbiter {
  /// Creates an [Arbiter] that fairly takes turns between [requests].
  RotateRoundRobinArbiter(super.requests,
      {required super.clk, required super.reset}) {
    final preference = Logic(name: 'preference', width: log2Ceil(count));

    final rotatedReqs = requests
        .rswizzle()
        .rotateRight(preference, maxAmount: count - 1)
        .elements;
    final priorityArb = PriorityArbiter(rotatedReqs);
    final unRotatedGrants = priorityArb.grants
        .rswizzle()
        .rotateLeft(preference, maxAmount: count - 1);

    Sequential(clk, reset: reset, [
      If(unRotatedGrants.or(), then: [
        preference < TreeOneHotToBinary(unRotatedGrants).binary + 1,
      ]),
    ]);

    for (var i = 0; i < count; i++) {
      grants[i] <= unRotatedGrants[i];
    }
  }
}
