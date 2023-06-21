// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_completer.dart
// An agent for completing APB requests.
//
// 2023 June 14
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A checker for some of the rules defined in the APB interface specification.
///
/// This does not necessarily cover all rules defined in the spec.
class ApbComplianceChecker extends Component {
  /// The interface being checked.
  final ApbInterface intf;

  /// Creates a new compliance checker for [intf].
  ApbComplianceChecker(
    this.intf, {
    required Component parent,
    String name = 'apbComplianceChecker',
  }) : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    // wait for reset to complete
    await intf.resetN.nextPosedge;

    var accessLastCycle = false;

    LogicValue? lastWrite;
    LogicValue? lastAddr;
    List<LogicValue>? lastSel;
    LogicValue? lastWriteData;
    LogicValue? lastStrb;
    LogicValue? lastProt;
    LogicValue? lastAuser;
    LogicValue? lastWuser;

    intf.clk.posedge.listen((event) {
      final currSels = intf.sel.map((e) => e.value).toList();

      if (currSels.map((e) => e.isValid).reduce((a, b) => a | b)) {
        // if any select is high

        // valid checks
        if (!intf.write.value.isValid) {
          logger.severe('Write must be valid during select.');
        }
        if (!intf.addr.value.isValid) {
          logger.severe('Addr must be valid during select.');
        }
        if (!intf.wData.value.isValid) {
          logger.severe('WData must be valid during select.');
        }
        if (!intf.strb.value.isValid) {
          logger.severe('Strobe must be valid during select.');
        }
        if (!intf.enable.value.isValid) {
          logger.severe('Enable must be valid during select.');
        }

        // stability checks
        if (intf.enable.value.isValid && intf.enable.value.toBool()) {
          if (lastWrite != null && lastWrite != intf.write.value) {
            logger.severe('Write must be stable until ready.');
          }
          if (lastAddr != null && lastAddr != intf.addr.value) {
            logger.severe('Addr must be stable until ready.');
          }
          if (lastSel != null) {
            for (var i = 0; i < intf.numSelects; i++) {
              if (intf.sel[i].value != lastSel![i]) {
                logger.severe('Sel must be stable until ready.');
              }
            }
          }
          if (lastWriteData != null && lastWriteData != intf.wData.value) {
            logger.severe('Write data must be stable until ready.');
          }
          if (lastStrb != null && lastStrb != intf.strb.value) {
            logger.severe('Strobe must be stable until ready.');
          }
          if (lastProt != null && lastProt != intf.prot.value) {
            logger.severe('Prot must be stable until ready.');
          }
          if (lastAuser != null && lastAuser != intf.aUser?.value) {
            logger.severe('AUser must be stable until ready.');
          }
          if (lastWuser != null && lastWuser != intf.wUser?.value) {
            logger.severe('WUser must be stable until ready.');
          }

          // collect "last" items for next check
          lastWrite = intf.write.value;
          lastAddr = intf.addr.value;
          lastSel = currSels;
          lastWriteData = intf.wData.value;
          lastStrb = intf.strb.value;
          lastProt = intf.prot.value;
          lastAuser = intf.aUser?.value;
          lastWuser = intf.wUser?.value;
        }
      }

      if (intf.ready.value.toBool()) {
        lastWrite = null;
        lastAddr = null;
        lastSel = null;
        lastWriteData = null;
        lastStrb = null;
        lastProt = null;
        lastAuser = null;
        lastWuser = null;
      }

      if (intf.write.value.isValid &&
          !intf.write.value.toBool() &&
          intf.enable.value.isValid &&
          intf.enable.value.toBool() &&
          intf.strb.value.isValid &&
          intf.strb.value.toInt() > 0) {
        // strobe must not be "active" during read xfer (all low during read)
        logger.severe('Strobe must not be active during read transfer.');
      }

      if (intf.enable.value.isValid &&
          intf.enable.value.toBool() &&
          intf.ready.value.isValid &&
          intf.ready.value.toBool()) {
        if (accessLastCycle) {
          logger.severe('Cannot have back-to-back accesses.');
        }

        if (intf.includeSlvErr && !intf.slvErr!.value.isValid) {
          logger.severe('SlvErr must be valid during transfer.');
        }

        accessLastCycle = true;
      } else {
        accessLastCycle = false;
      }
    });
  }
}
