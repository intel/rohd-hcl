// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_backdoor_test.dart
// Tests that register level access rules apply only to frontdoor writes
//
// 2026 September 21
// Author: Shubham Padkonde <shubhampadkonde12@gmail.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

const _csrWidth = 32;

/// A status register: read only from the frontdoor, written by hardware
/// through the backdoor.
class StatusBlock extends CsrBlockConfig {
  StatusBlock({super.name = 'statusBlock'})
      : super(baseAddr: 0x0, registers: [
          CsrInstanceConfig(
            arch: CsrConfig(
                name: 'status', access: CsrAccess.readOnly, fields: const []),
            addr: 0x0,
            width: _csrWidth,
            isBackdoorReadable: true,
            isBackdoorWritable: true,
          ),
        ]);
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('a readOnly register is still backdoor writeable', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);
    final wIntf = DataPortInterface(_csrWidth, 8);
    final rIntf = DataPortInterface(_csrWidth, 8);

    final block = CsrBlock(
        config: StatusBlock(),
        clk: clk,
        reset: reset,
        frontWrite: wIntf,
        frontRead: rIntf);

    wIntf.en.put(0);
    wIntf.addr.put(0);
    wIntf.data.put(0);
    rIntf.en.put(0);
    rIntf.addr.put(0);

    await block.build();

    final back = block.getBackdoorPortsByName('status');
    back.wrEn!.put(0);
    back.wrData!.put(0);

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    // perform a reset
    reset.inject(1);
    for (var i = 0; i < 4; i++) {
      await clk.nextNegedge;
    }
    reset.inject(0);
    for (var i = 0; i < 4; i++) {
      await clk.nextNegedge;
    }

    expect(back.rdData!.value, LogicValue.ofInt(0, _csrWidth));

    // Hardware updates the status register through the backdoor.
    back.wrEn!.inject(1);
    back.wrData!.inject(0xdeadbeef);
    await clk.nextNegedge;
    back.wrEn!.inject(0);
    await clk.nextNegedge;

    expect(back.rdData!.value, LogicValue.ofInt(0xdeadbeef, _csrWidth),
        reason: 'the backdoor write should have landed');

    // The frontdoor still cannot write it.
    wIntf.en.inject(1);
    wIntf.addr.inject(0x0);
    wIntf.data.inject(0x12345678);
    await clk.nextNegedge;
    wIntf.en.inject(0);
    await clk.nextNegedge;

    expect(back.rdData!.value, LogicValue.ofInt(0xdeadbeef, _csrWidth),
        reason: 'a frontdoor write to a readOnly register must be dropped');

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });
}
