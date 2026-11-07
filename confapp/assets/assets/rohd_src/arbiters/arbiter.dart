// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// arbiter.dart
// Definition for an interface for a generic arbiter.
//
// 2023 March 13
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:collection';
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// An abstract description of an arbiter module.
abstract class Arbiter extends Module {
  /// Each element corresponds to an arbitration grant of the correspondingly
  /// indexed request passed at construction time.
  late final List<Logic> grants = UnmodifiableListView(_grants);
  final List<Logic> _grants = [];

  /// Each element is the [input] pin for the correspondingly indexed request.
  ///
  /// To be used internally to the arbiter only, since this contains the
  /// [inputs] of the [Module].
  @protected
  late final List<Logic> requests = UnmodifiableListView(_requests);
  final List<Logic> _requests = [];

  /// The total number of requests and grants for this [Arbiter].
  late final int count = _requests.length;

  /// Constructs an arbiter where each element in [requests] is a one-bit signal
  /// requesting a corresponding bit from [grants].
  Arbiter(List<Logic> requests,
      {super.name = 'arbiter',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(definitionName: definitionName ?? 'Arbiter_W${requests.length}') {
    for (var i = 0; i < requests.length; i++) {
      if (requests[i].width != 1) {
        throw RohdHclException('Each request must be 1 bit,'
            ' but found ${requests[i]} at index $i.');
      }

      _requests.add(addInput('request_$i', requests[i]));
      _grants.add(addOutput('grant_$i'));
    }
  }
}
