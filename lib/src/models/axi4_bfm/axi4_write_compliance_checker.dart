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
class Axi4WriteComplianceChecker extends Component {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Write Interface.
  final Axi4WriteInterface wIntf;

  /// Creates a new compliance checker for AXI4.
  Axi4WriteComplianceChecker(
    this.sIntf,
    this.wIntf, {
    required Component parent,
    String name = 'axi4WriteComplianceChecker',
  }) : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    // wait for reset to complete
    await sIntf.resetN.nextPosedge;

    // checks to run
    // WRITE REQUESTS
    //   number of flits sent matches AWLEN
    //   WLAST is asserted on the final flit only
    //   if BID is present, every write response should match
    //   a pending request AWID

    final writeReqMap = <int, List<int>>{};
    var lastWriteReqId = -1;

    sIntf.clk.posedge.listen((event) {
      // track write requests
      if (wIntf.awValid.previousValue!.isValid &&
          wIntf.awValid.previousValue!.toBool()) {
        final id = wIntf.awId?.previousValue!.toInt() ?? 0;
        final len = (wIntf.awLen?.previousValue!.toInt() ?? 0) + 1;
        writeReqMap[id] = [len, 0];
        lastWriteReqId = id;
      }

      // track write data flits
      if (wIntf.wValid.previousValue!.isValid &&
          wIntf.wValid.previousValue!.toBool()) {
        final id = lastWriteReqId;
        if (!writeReqMap.containsKey(id)) {
          logger.severe('There is no pending write request '
              'to associate with valid write data.');
        }

        writeReqMap[id]![1] = writeReqMap[id]![1] + 1;
        final len = writeReqMap[id]![0];
        final currCount = writeReqMap[id]![1];
        if (currCount > len) {
          logger.severe(
              'Sent more write data flits than indicated by the request '
              'with ID $id AWLEN. Expected $len but sent $currCount');
        } else if (currCount == len && !wIntf.wLast.previousValue!.toBool()) {
          logger.severe('Sent the final flit in the write data per the request '
              'with ID $id AWLEN but WLAST is not asserted.');
        }
      }
    });
  }
}
