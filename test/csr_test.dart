// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_test.dart
// Tests for CSRs
//
// 2024 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

///// DEFINE SOME HELPER CLASSES FOR TESTING /////

class MyNoFieldCsr extends CsrConfig {
  MyNoFieldCsr({super.name = 'myNoFieldCsr'})
      : super(access: CsrAccess.REGISTER_READ_ONLY);
}

class MyNoFieldCsrInstance extends CsrInstanceConfig {
  MyNoFieldCsrInstance({
    required super.addr,
    required super.width,
    super.resetValue = 0x0,
    String name = 'myNoFieldCsrInstance',
  }) : super(arch: MyNoFieldCsr(name: name));
}

class MyFieldCsr extends CsrConfig {
  MyFieldCsr({super.name = 'myFieldCsr'})
      : super(access: CsrAccess.REGISTER_READ_WRITE);
}

class MyFieldCsrInstance extends CsrInstanceConfig {
  MyFieldCsrInstance({
    required super.addr,
    required super.width,
    super.resetValue = 0xff,
    String name = 'myFieldCsrInstance',
  }) : super(arch: MyFieldCsr(name: name)) {
    // example of a static field
    addField(CsrFieldConfig(
        start: 0,
        width: 2,
        name: 'field1',
        access: CsrFieldAccess.FIELD_READ_ONLY));
    // example of a field with dynamic start and width
    addField(CsrFieldConfig(
        start: width ~/ 2,
        width: width ~/ 4,
        name: 'field2',
        access: CsrFieldAccess.FIELD_READ_WRITE));
    // example of field duplication
    for (var i = 0; i < width ~/ 4; i++) {
      addField(CsrFieldConfig(
          start: (3 * width ~/ 4) + i,
          width: 1,
          name: 'field3_$i',
          access: CsrFieldAccess.FIELD_W1C));
    }
  }
}

class MyRegisterBlock extends CsrBlockConfig {
  final int csrWidth;
  final int numNoFieldCsrs;
  final bool evensOnly;

  MyRegisterBlock({
    required super.baseAddr,
    super.name = 'myRegisterBlock',
    this.csrWidth = 32,
    this.numNoFieldCsrs = 1,
    this.evensOnly = false,
  }) {
    // static register instance
    addRegister(MyFieldCsrInstance(addr: 0x0, width: csrWidth, name: 'csr1'));

    // dynamic register instances
    for (var i = 0; i < numNoFieldCsrs; i++) {
      final chk = i.isEven || !evensOnly;
      if (chk) {
        addRegister(MyNoFieldCsrInstance(
            addr: i + 1, width: csrWidth, name: 'csr2_$i'));
      }
    }
  }
}

class MyCsrModule extends CsrTopConfig {
  final int numBlocks;

  MyCsrModule({
    this.numBlocks = 1,
    super.name = 'myCsrModule',
    super.blockOffsetWidth = 16,
  }) {
    // example of dynamic block instantiation
    const baseAddr = 0x0;
    for (var i = 0; i < numBlocks; i++) {
      addBlock(MyRegisterBlock(
          baseAddr: baseAddr + (i * 0x100),
          numNoFieldCsrs: i + 1,
          evensOnly: i.isEven,
          name: 'block_$i'));
    }
  }
}

///// END DEFINE SOME HELPER CLASSES FOR TESTING /////

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('simple individual CSRs', () async {
    // register with no explicit fields, read only
    final csr1Cfg = MyNoFieldCsrInstance(addr: 0x0, width: 32, name: 'csr1');
    final csr1 = Csr(csr1Cfg);

    // check address and reset value
    expect(csr1.getAddr(8).value, LogicValue.ofInt(0x0, 8));
    expect(csr1.getResetValue().value, LogicValue.ofInt(0x0, 32));
    csr1.put(csr1.resetValue);

    // check write data
    // should return the reset value, since it's read only
    final wd1 = csr1.getWriteData(Const(0x12345678, width: 32));
    expect(wd1.value, LogicValue.ofInt(0x0, 32));

    // register with 3 explicit fields, read/write
    // fields don't cover full width of register
    final csr2Cfg = MyFieldCsrInstance(addr: 0x1, width: 8, name: 'csr2');
    final csr2 = Csr(csr2Cfg);

    // check address and reset value
    expect(csr2.getAddr(8).value, LogicValue.ofInt(0x1, 8));
    expect(csr2.getResetValue().value, LogicValue.ofInt(0xff, 8));
    csr2.put(csr2.resetValue);

    // check the write data
    // only some of what we're trying to write should
    // given the field access rules
    final wd2 = csr2.getWriteData(Const(0xab, width: 8));
    expect(wd2.value, LogicValue.ofInt(0xef, 8));

    // check grabbing individual fields
    final f1 = csr2.getField('field1');
    expect(f1.value, LogicValue.ofInt(0x3, 2));
    final f2 = csr2.getField('field2');
    expect(f2.value, LogicValue.ofInt(0x3, 2));
    final f3a = csr2.getField('field3_0');
    expect(f3a.value, LogicValue.ofInt(0x1, 1));
    final f3b = csr2.getField('field3_1');
    expect(f3b.value, LogicValue.ofInt(0x1, 1));
  });

  test('simple CSR block', () async {
    const csrWidth = 32;

    final csrBlockCfg = MyRegisterBlock(
      baseAddr: 0x0,
      csrWidth: csrWidth,
      numNoFieldCsrs: 2,
    );

    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);
    final wIntf = DataPortInterface(csrWidth, 8);
    final rIntf = DataPortInterface(csrWidth, 8);
    final csrBlock = CsrBlock(csrBlockCfg, clk, reset, wIntf, rIntf);

    wIntf.en.put(0);
    wIntf.addr.put(0);
    wIntf.data.put(0);
    rIntf.en.put(0);
    rIntf.addr.put(0);

    await csrBlock.build();

    // WaveDumper(csrBlock);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // retrieve block address
    final blkAddr = csrBlock.getAddr(16);
    expect(blkAddr.value, LogicValue.ofInt(0x0, 16));

    // grab pointers to the CSRs
    final csr1 = csrBlock.getRegister('csr1');
    final csr2 = csrBlock.getRegisterByAddr(0x2);

    // perform a reset
    reset.inject(1);
    await clk.waitCycles(10);
    reset.inject(0);
    await clk.waitCycles(10);

    // perform a read of csr2
    // ensure that the read data is the reset value
    await clk.nextNegedge;
    rIntf.en.inject(1);
    rIntf.addr.inject(csr2.getAddr(rIntf.addrWidth).value);
    await clk.nextNegedge;
    rIntf.en.inject(0);
    expect(csrBlock.rdData().value, csr2.getResetValue().value);
    await clk.waitCycles(10);

    // perform a write of csr2 and then a read
    // ensure that the write takes no effect b/c readonly
    await clk.nextNegedge;
    wIntf.en.inject(1);
    wIntf.addr.inject(csr2.getAddr(wIntf.addrWidth).value);
    wIntf.data.inject(0xdeadbeef);
    await clk.nextNegedge;
    wIntf.en.inject(0);
    rIntf.en.inject(1);
    rIntf.addr.inject(csr2.getAddr(rIntf.addrWidth).value);
    await clk.nextNegedge;
    rIntf.en.inject(0);
    expect(csrBlock.rdData().value, csr2.getResetValue().value);
    await clk.waitCycles(10);

    // perform a write of csr1
    // ensure that the write data is modified appropriately
    await clk.nextNegedge;
    wIntf.en.inject(1);
    wIntf.addr.inject(csr1.getAddr(wIntf.addrWidth).value);
    wIntf.data.inject(0xdeadbeef);
    await clk.nextNegedge;
    wIntf.en.inject(0);
    rIntf.en.inject(1);
    rIntf.addr.inject(csr1.getAddr(rIntf.addrWidth).value);
    await clk.nextNegedge;
    rIntf.en.inject(0);
    expect(
        csrBlock.rdData().value, LogicValue.ofInt(0xad00ff, rIntf.dataWidth));
    await clk.waitCycles(10);

    // perform a read of nothing
    await clk.nextNegedge;
    rIntf.en.inject(1);
    rIntf.addr.inject(0xff);
    await clk.nextNegedge;
    rIntf.en.inject(0);
    expect(csrBlock.rdData().value, LogicValue.ofInt(0, rIntf.dataWidth));
    await clk.waitCycles(10);

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('simple CSR top', () async {
    const csrWidth = 32;

    final csrTopCfg = MyCsrModule(numBlocks: 4);

    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..inject(0);
    final wIntf = DataPortInterface(csrWidth, 32);
    final rIntf = DataPortInterface(csrWidth, 32);
    final csrTop = CsrTop(csrTopCfg, clk, reset, wIntf, rIntf);

    wIntf.en.inject(0);
    wIntf.addr.inject(0);
    wIntf.data.inject(0);
    rIntf.en.inject(0);
    rIntf.addr.inject(0);

    await csrTop.build();

    WaveDumper(csrTop);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // grab pointers to certain blocks and CSRs
    final block1 = csrTop.getBlock('block_0');
    final block2 = csrTop.getBlockByAddr(0x100);
    final csr1 = block1.getRegister('csr1');
    final csr2 = block2.getRegisterByAddr(0x2);

    // perform a reset
    reset.inject(1);
    await clk.waitCycles(10);
    reset.inject(0);
    await clk.waitCycles(10);

    // perform a read to a particular register in a particular block
    final addr1 =
        block2.getAddr(rIntf.addrWidth) + csr2.getAddr(rIntf.addrWidth);
    await clk.nextNegedge;
    rIntf.en.inject(1);
    rIntf.addr.inject(addr1.value);
    await clk.nextNegedge;
    rIntf.en.inject(0);
    expect(rIntf.data.value, csr2.getResetValue().value);
    await clk.waitCycles(10);

    // perform a write to a particular register in a particular block
    final addr2 =
        block1.getAddr(rIntf.addrWidth) + csr1.getAddr(rIntf.addrWidth);
    await clk.nextNegedge;
    wIntf.en.inject(1);
    wIntf.addr.inject(addr2.value);
    wIntf.data.inject(0xdeadbeef);
    await clk.nextNegedge;
    wIntf.en.inject(0);
    rIntf.en.inject(1);
    rIntf.addr.inject(addr2.value);
    await clk.nextNegedge;
    rIntf.en.inject(0);
    expect(rIntf.data.value, LogicValue.ofInt(0xad00ff, rIntf.dataWidth));
    await clk.waitCycles(10);

    // perform a read to an invalid block
    await clk.nextNegedge;
    rIntf.en.inject(1);
    rIntf.addr.inject(0xffffffff);
    await clk.nextNegedge;
    rIntf.en.inject(0);
    expect(rIntf.data.value, LogicValue.ofInt(0, rIntf.dataWidth));
    await clk.waitCycles(10);

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });
}
