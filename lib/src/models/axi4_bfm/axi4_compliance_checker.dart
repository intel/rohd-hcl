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
class Axi4ComplianceChecker extends Component {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Read Interface.
  final Axi4ReadInterface rIntf;

  /// AXI4 Write Interface.
  final Axi4WriteInterface wIntf;

  /// Creates a new compliance checker for AXI4.
  Axi4ComplianceChecker(
    this.sIntf,
    this.rIntf,
    this.wIntf, {
    required Component parent,
    String name = 'axi4ComplianceChecker',
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
    // WRITE REQUESTS
    //   number of flits sent matches AWLEN
    //   WLAST is asserted on the final flit only
    //   if BID is present, every write response should match
    //   a pending request AWID

    final rLastPresent = rIntf.rLast != null;

    final readReqMap = <int, List<int>>{};
    final writeReqMap = <int, List<int>>{};
    var lastWriteReqId = -1;

    sIntf.clk.posedge.listen((event) {
      // capture read requests for counting
      if (rIntf.arValid.previousValue!.isValid &&
          rIntf.arValid.previousValue!.toBool()) {
        final id = rIntf.arId?.previousValue?.toInt() ?? 0;
        final len = (rIntf.arLen?.previousValue?.toInt() ?? 0) + 1;
        readReqMap[id] = [len, 0];
      }

      // track read response flits
      if (rIntf.rValid.previousValue!.isValid &&
          rIntf.rValid.previousValue!.toBool()) {
        final id = rIntf.rId?.previousValue?.toInt() ?? 0;
        if (!readReqMap.containsKey(id)) {
          logger.severe(
              'Cannot match a read response to any pending read request. '
              'ID captured by the response was $id.');
        }

        readReqMap[id]![1] = readReqMap[id]![1] + 1;
        final len = readReqMap[id]![0];
        final currCount = readReqMap[id]![1];
        if (currCount > len) {
          logger.severe(
              'Received more read response data flits than indicated by the '
              'request with ID $id ARLEN. Expected $len but got $currCount');
        } else if (currCount == len &&
            rLastPresent &&
            !rIntf.rLast!.previousValue!.toBool()) {
          logger.severe('Received the final flit in the read response data per '
              'the request with ID $id ARLEN but RLAST is not asserted.');
        }
      }

      // track write requests
      if (wIntf.awValid.previousValue!.isValid &&
          wIntf.awValid.previousValue!.toBool()) {
        final id = wIntf.awId?.previousValue?.toInt() ?? 0;
        final len = (wIntf.awLen?.previousValue?.toInt() ?? 0) + 1;
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
