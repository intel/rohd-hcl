// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ace4_compliance_checker.dart
// ACE4 signal-level protocol checks.
//
// 2026 November 15
// Author: Desmond Kirkpatrick <desmond.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Checks stalled ACE4 channel stability, snoop responses and acknowledgements.
///
/// The channel checks apply to both ACE4 layouts and include every payload
/// signal present on each channel. When RACK and WACK exist, the checker also
/// rejects acknowledgements without a previously completed response.
/// It checks snoop address alignment and matches snoop responses to accepted
/// addresses. ACE4 SNOOP encodings and PassDirty are checked when present.
///
/// This checker does not implement all ACE ordering and coherency rules.
class Ace4ComplianceChecker extends Component {
  /// System clock and reset.
  final Axi4SystemInterface sIntf;

  /// ACE4 interface to check.
  final Ace4Cluster ace;

  /// Creates an ACE4 checker.
  Ace4ComplianceChecker(this.sIntf, this.ace,
      {required Component parent, String name = 'ace4ComplianceChecker'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final channels = <Axi4ChannelInterface>[
      ace.read.arIntf,
      ace.read.rIntf,
      ace.write.awIntf,
      ace.write.wIntf,
      ace.write.bIntf,
      ace.snoop.acIntf,
      ace.snoop.crIntf,
      ace.snoop.cdIntf,
    ];
    final stalled = <Axi4ChannelInterface, Map<String, LogicValue>>{};
    var pendingReadAcks = 0;
    var pendingWriteAcks = 0;
    var pendingSnoops = 0;

    sIntf.clk.posedge.listen((_) {
      final reset = sIntf.resetN.previousValue;
      if (reset == null || !reset.isValid || !reset.toBool()) {
        stalled.clear();
        pendingReadAcks = 0;
        pendingWriteAcks = 0;
        pendingSnoops = 0;
        return;
      }

      for (final channel in channels) {
        final valid = channel.valid.previousValue!;
        final ready = channel.ready.previousValue!;
        final previous = stalled.remove(channel);
        if (previous != null) {
          if (!valid.isValid || !valid.toBool()) {
            logger.severe('${channel.prefix}VALID dropped while stalled.');
          } else {
            for (final entry in previous.entries) {
              if (channel.port(entry.key).previousValue != entry.value) {
                logger.severe('${entry.key} changed while stalled.');
              }
            }
          }
        }
        if (valid.isValid &&
            valid.toBool() &&
            ready.isValid &&
            !ready.toBool()) {
          stalled[channel] = {
            for (final entry in channel.ports.entries)
              if (entry.key != '${channel.prefix}VALID' &&
                  entry.key != '${channel.prefix}READY')
                entry.key: entry.value.previousValue!,
          };
        }
      }

      if (_transferred(ace.snoop.acIntf)) {
        pendingSnoops++;
        final address = ace.snoop.acIntf.addr.previousValue!;
        if (!address.isValid) {
          logger.severe('ACADDR is unknown on an accepted snoop.');
        } else if (address.toBigInt() %
                BigInt.from(ace.snoop.cdIntf.dataWidth ~/ 8) !=
            BigInt.zero) {
          logger.severe('ACADDR is not aligned to the snoop data width.');
        }
        final snoop = ace.snoop.acIntf.snoop?.previousValue;
        if (snoop != null &&
            (!snoop.isValid ||
                !const {0, 1, 2, 3, 7, 8, 9, 13, 14, 15}
                    .contains(snoop.toInt()))) {
          logger.severe('ACSNOOP is unknown or reserved.');
        }
      }
      if (_transferred(ace.snoop.crIntf)) {
        if (pendingSnoops == 0) {
          logger.severe('CR response has no accepted snoop address.');
        } else {
          pendingSnoops--;
        }
        final response = ace.snoop.crIntf.resp!.previousValue!;
        if (!response.isValid) {
          logger.severe('CRRESP is unknown on an accepted snoop response.');
        } else if (response.width >= 3 &&
            (response.toInt() & 4) != 0 &&
            (response.toInt() & 1) == 0) {
          logger.severe('CRRESP PassDirty requires DataTransfer.');
        }
      }

      final rack = ace.rack?.previousValue;
      if (rack != null) {
        if (!rack.isValid) {
          logger.severe('RACK is unknown outside reset.');
        } else if (rack.toBool()) {
          if (pendingReadAcks == 0) {
            logger.severe('RACK has no previously completed read response.');
          } else {
            pendingReadAcks--;
          }
        }
      }
      final wack = ace.wack?.previousValue;
      if (wack != null) {
        if (!wack.isValid) {
          logger.severe('WACK is unknown outside reset.');
        } else if (wack.toBool()) {
          if (pendingWriteAcks == 0) {
            logger.severe('WACK has no previously completed write response.');
          } else {
            pendingWriteAcks--;
          }
        }
      }

      if (rack != null &&
          _transferred(ace.read.rIntf) &&
          ace.read.rIntf.last!.previousValue!.isValid &&
          ace.read.rIntf.last!.previousValue!.toBool()) {
        pendingReadAcks++;
      }
      if (wack != null && _transferred(ace.write.bIntf)) {
        pendingWriteAcks++;
      }
    });
  }

  bool _transferred(Axi4ChannelInterface channel) {
    final valid = channel.valid.previousValue!;
    final ready = channel.ready.previousValue!;
    return valid.isValid && ready.isValid && valid.toBool() && ready.toBool();
  }
}
