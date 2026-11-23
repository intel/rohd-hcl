// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ace4_acknowledgement_driver.dart
// ACE4 read and write acknowledgement driver.
//
// 2026 November 15
// Author: Desmond Kirkpatrick <desmond.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Acknowledges accepted ACE4 read and write responses on the next cycle.
///
/// This driver is for a manager that can acknowledge immediately after
/// accepting a response. The historical layout has no acknowledgement ports
/// and cannot use this driver.
class Ace4AcknowledgementDriver extends Component {
  /// System clock and reset.
  final Axi4SystemInterface sIntf;

  /// ACE4 interface with acknowledgement signals.
  final Ace4Cluster ace;

  /// Creates an acknowledgement driver for an ACE4 signal-layout interface.
  Ace4AcknowledgementDriver(this.sIntf, this.ace,
      {required Component parent, String name = 'ace4AcknowledgementDriver'})
      : super(name, parent) {
    if (ace.rack == null || ace.wack == null || ace.read.rIntf.last == null) {
      throw RohdHclException(
          'ACE4 acknowledgement driving requires RACK, WACK, and RLAST.');
    }
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      ace.rack!.put(0);
      ace.wack!.put(0);
    });
    sIntf.resetN.negedge.listen((_) {
      Simulator.injectAction(() {
        ace.rack!.put(0);
        ace.wack!.put(0);
      });
    });
    sIntf.clk.posedge.listen((_) {
      final reset = sIntf.resetN.previousValue;
      var readComplete = false;
      var writeComplete = false;
      if (reset != null && reset.isValid && reset.toBool()) {
        final read = ace.read.rIntf;
        if (_transferred(read)) {
          final last = read.last!.previousValue!;
          if (!last.isValid) {
            logger.severe('RLAST is unknown on an accepted read response.');
          } else {
            readComplete = last.toBool();
          }
        }
        writeComplete = _transferred(ace.write.bIntf);
      }
      Simulator.injectAction(() {
        ace.rack!.put(readComplete);
        ace.wack!.put(writeComplete);
      });
    });
  }

  bool _transferred(Axi4ChannelInterface channel) {
    final valid = channel.valid.previousValue!;
    final ready = channel.ready.previousValue!;
    return valid.isValid && ready.isValid && valid.toBool() && ready.toBool();
  }
}
