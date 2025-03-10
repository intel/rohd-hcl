// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_compliance_checker.dart
// Compliance checking for AXI4.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A checker for some of the rules defined in the AXI4 interface specification.
///
/// This does not necessarily cover all rules defined in the spec.
class Axi4ReadComplianceChecker extends Component {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Read Interface.
  final Axi4ReadInterface rIntf;

  /// Creates a new compliance checker for AXI4.
  Axi4ReadComplianceChecker(
    this.sIntf,
    this.rIntf, {
    required Component parent,
    String name = 'axi4ReadComplianceChecker',
  }) : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    // wait for reset to complete
    await sIntf.resetN.nextPosedge;

    // checks to run
    // READ REQUESTS
    //   number of flits returned matches ARLEN if no error
    //   if RLAST is present, asserted on the final flit only
    //   if RID is present, every read response should match
    //   a pending request ARID

    final rLastPresent = rIntf.rLast != null;
    final readReqMap = <int, List<List<int>>>{};

    sIntf.clk.posedge.listen((event) {
      // capture read requests for counting
      if (rIntf.arValid.previousValue!.isValid &&
          rIntf.arValid.previousValue!.toBool()) {
        final id = rIntf.arId?.previousValue!.toInt() ?? 0;
        final len = (rIntf.arLen?.previousValue!.toInt() ?? 0) + 1;
        if (!readReqMap.containsKey(id)) {
          readReqMap[id] = [];
        }
        readReqMap[id]!.add([len, 0]);
        if (Axi4SizeField.getImpliedSize(
                Axi4SizeField.fromValue(rIntf.arSize!.value.toInt())) >
            rIntf.dataWidth) {
          logger.severe('The ARSIZE value of ${rIntf.arSize!.value.toInt()} '
              'must be less than or equal to '
              '${Axi4SizeField.fromSize(rIntf.dataWidth).value} '
              'corresponding to the interface '
              'data width of ${rIntf.dataWidth}.');
        }
      }

      // track read response flits
      if (rIntf.rValid.previousValue!.isValid &&
          rIntf.rValid.previousValue!.toBool()) {
        final id = rIntf.rId?.previousValue!.toInt() ?? 0;
        if (!readReqMap.containsKey(id) || readReqMap[id]!.isEmpty) {
          logger.severe(
              'Cannot match a read response to any pending read request. '
              'ID captured by the response was $id.');
        }

        // always pull from the top
        readReqMap[id]![0][1] = readReqMap[id]![0][1] + 1;
        final len = readReqMap[id]![0][0];
        final currCount = readReqMap[id]![0][1];
        if (currCount > len) {
          logger.severe(
              'Received more read response data flits than indicated by the '
              'request with ID $id ARLEN. Expected $len but got $currCount');
        } else if (currCount == len &&
            rLastPresent &&
            !rIntf.rLast!.previousValue!.toBool()) {
          logger.severe('Received the final flit in the read response data per '
              'the request with ID $id ARLEN but RLAST is not asserted.');
        } else if (currCount == len &&
            rLastPresent &&
            rIntf.rLast!.previousValue!.toBool()) {
          readReqMap[id]!.removeAt(0);
        }
      }
    });
  }
}
