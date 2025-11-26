// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_test.dart
// Tests for the APB interface.
//
// 2023 May 19
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class ApbCompleterTest extends Module {
  ApbCompleterTest(ApbInterface intf) {
    intf = intf.clone()
      ..connectIO(this, intf,
          inputTags: {ApbDirection.misc, ApbDirection.fromRequester},
          outputTags: {ApbDirection.fromCompleter});
  }
}

class ApbRequesterTest extends Module {
  ApbRequesterTest(ApbInterface intf) {
    intf = intf.clone()
      ..connectIO(this, intf,
          inputTags: {ApbDirection.misc, ApbDirection.fromCompleter},
          outputTags: {ApbDirection.fromRequester});
  }
}

class ApbPair extends Module {
  ApbPair(Logic clk, Logic reset) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    final apb = ApbInterface(
      includeSlvErr: true,
      userDataWidth: 10,
      userReqWidth: 11,
      userRespWidth: 12,
    );
    apb.clk <= clk;
    apb.resetN <= ~reset;

    ApbCompleterTest(apb);
    ApbRequesterTest(apb);
  }
}

void main() {
  test('connect apb modules', () async {
    final abpPair = ApbPair(Logic(), Logic());
    await abpPair.build();
  });

  test('abp optional ports null', () async {
    final apb = ApbInterface();
    expect(apb.aUser, isNull);
    expect(apb.bUser, isNull);
    expect(apb.rUser, isNull);
    expect(apb.wUser, isNull);
    expect(apb.slvErr, isNull);
  });

  test('apb csr completer', () async {
    const dataWidth = 32;
    const addrWidth = 32;
    final apbCsr = ApbInterface();
    final apbCsrRd = DataPortInterface(dataWidth, addrWidth);
    final apbCsrWr = DataPortInterface(dataWidth, addrWidth);
    final csrs = CsrBlock(
      config: CsrBlockConfig(name: 'test', baseAddr: 0x0, registers: [
        CsrInstanceConfig(
          arch: CsrConfig(
            name: 'reg0',
            access: CsrAccess.readWrite,
            fields: const [],
            isBackdoorWritable: false,
          ),
          addr: 0x0,
          width: dataWidth,
          resetValue: 0xa,
        ),
        CsrInstanceConfig(
          arch: CsrConfig(
            name: 'reg1',
            access: CsrAccess.readWrite,
            fields: const [],
            isBackdoorWritable: false,
          ),
          addr: 0x4,
          width: dataWidth,
          resetValue: 0xb,
        ),
      ]),
      clk: apbCsr.clk,
      reset: ~apbCsr.resetN,
      frontWrite: apbCsrWr,
      frontRead: apbCsrRd,
    );
    final completer = ApbCsrCompleter(
      apb: apbCsr,
      csrRd: apbCsrRd,
      csrWr: apbCsrWr,
      name: 'apb_csr_completer',
    );
    final apbBfm = ApbRequesterAgent(intf: apbCsr, parent: Test.instance!);
    apbCsr.clk <= SimpleClockGenerator(10).clk;
    apbCsr.resetN.put(1);

    await csrs.build();
    await completer.build();

    // reset flow
    await apbCsr.clk.waitCycles(2);
    apbCsr.resetN.inject(0);
    await apbCsr.clk.waitCycles(3);
    apbCsr.resetN.inject(1);
    await apbCsr.clk.waitCycles(2);

    // write a register
    apbBfm.sequencer.add(
      ApbWritePacket(
        addr: LogicValue.ofInt(
          csrs.config.baseAddr,
          apbCsr.addrWidth,
        ),
        data: LogicValue.ofInt(0x5, apbCsr.dataWidth),
      ),
    );
    await apbCsr.clk.waitCycles(10);

    // read the register back
    apbBfm.sequencer.add(ApbReadPacket(
      addr: LogicValue.ofInt(
        csrs.config.baseAddr,
        apbCsr.addrWidth,
      ),
    ));

    while (!apbCsr.ready.previousValue!.toBool()) {
      await apbCsr.clk.nextNegedge;
    }
    expect(apbCsr.rData.value.toInt(), 0x5);

    await apbCsr.clk.waitCycles(10);
    await Simulator.endSimulation();
  });
}
