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

  /// AXI4 AW Channel.
  final Axi4BaseAwChannelInterface reqIntf;

  /// AXI4 W Channel.
  final Axi4BaseWChannelInterface dataIntf;

  /// AXI4 B Channel.
  final Axi4BaseBChannelInterface respIntf;

  /// Creates a new compliance checker for AXI4.
  Axi4WriteComplianceChecker(
    this.sIntf,
    this.reqIntf,
    this.dataIntf,
    this.respIntf, {
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

    final writeReqMap = <int, List<List<int>>>{};
    final lastWriteReqId = <int>[];

    sIntf.clk.posedge.listen((event) {
      // track write requests
      if (reqIntf.valid.previousValue!.isValid &&
          reqIntf.valid.previousValue!.toBool()) {
        final id = reqIntf.id?.previousValue!.toInt() ?? 0;
        final len = (reqIntf.len?.previousValue!.toInt() ?? 0) + 1;
        if (!writeReqMap.containsKey(id)) {
          writeReqMap[id] = [];
        }
        writeReqMap[id]!.add([len, 0]);
        lastWriteReqId.add(id);
        if (Axi4SizeField.getImpliedSize(
                Axi4SizeField.fromValue(reqIntf.size!.value.toInt())) >
            dataIntf.dataWidth) {
          logger.severe(
              'The AWSIZE value of ${reqIntf.size!.value.toInt()} must be '
              'less than or equal to '
              '${Axi4SizeField.fromSize(dataIntf.dataWidth).value} '
              'corresponding to the interface '
              'data width of ${dataIntf.dataWidth}.');
        }
      }

      // track write data flits
      if (dataIntf.valid.previousValue!.isValid &&
          dataIntf.valid.previousValue!.toBool()) {
        final id = lastWriteReqId.isEmpty ? -1 : lastWriteReqId[0];
        if (!writeReqMap.containsKey(id) || writeReqMap[id]!.isEmpty) {
          logger.severe('There is no pending write request '
              'to associate with valid write data.');
        } else {
          writeReqMap[id]![0][1] = writeReqMap[id]![0][1] + 1;
          final len = writeReqMap[id]![0][0];
          final currCount = writeReqMap[id]![0][1];
          if (currCount > len) {
            logger.severe(
                'Sent more write data flits than indicated by the request '
                'with ID $id AWLEN. Expected $len but sent $currCount');
          } else if (currCount == len &&
              !dataIntf.last!.previousValue!.toBool()) {
            logger
                .severe('Sent the final flit in the write data per the request '
                    'with ID $id AWLEN but WLAST is not asserted.');
          } else if (currCount == len &&
              dataIntf.last!.previousValue!.toBool()) {
            writeReqMap[id]!.removeAt(0);
            lastWriteReqId.removeAt(0);
          }
        }
      }
    });
  }
}
