//
// arbiter.dart
// Implementation of arbiters.
//
// Author: Max Korbel
// 2023 March 13
//

import 'dart:collection';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// An abstract description of an arbiter module.
abstract class Arbiter extends Module {
  /// Each element corresponds to an arbitration grant of the correspondingly
  /// indexed request passed at construction time.
  List<Logic> get grants => UnmodifiableListView(_grants);

  final List<Logic> _grants = [];

  final List<Logic> _requests = [];

  /// The total number of requests and grants for this [Arbiter].
  int get count => _requests.length;

  /// Constructs an arbiter where each element in [requests] is a one-bit signal
  /// requesting a corresponding bit from [grants].
  Arbiter(List<Logic> requests) {
    for (var i = 0; i < requests.length; i++) {
      if (requests[i].width != 1) {
        throw RohdHclException(
            'Each request must be 1 bit, but found ${requests[i]} at index $i');
      }

      _requests.add(addInput('request_$i', requests[i]));
      _grants.add(addOutput('grant_$i'));
    }
  }
}

/// An [Arbiter] which always picks the lowest-indexed request.
class PriorityArbiter extends Arbiter {
  /// Constructs an arbiter where the grant is given to the lowest-indexed
  /// request.
  PriorityArbiter(super.requests) {
    Combinational([
      CaseZ(_requests.rswizzle(), conditionalType: ConditionalType.priority, [
        for (var i = 0; i < count; i++)
          CaseItem(
            Const(
              LogicValue.filled(count, LogicValue.z).withSet(i, LogicValue.one),
            ),
            [for (var g = 0; g < count; g++) _grants[g] < (i == g ? 1 : 0)],
          )
      ], defaultItem: [
        for (var g = 0; g < count; g++) _grants[g] < 0
      ]),
    ]);
  }
}
