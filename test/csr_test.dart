// Copyright (C) 2024-2025 Intel Corporation
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
      : super(access: CsrAccess.READ_ONLY);
}

class MyNoFieldCsrInstance extends CsrInstanceConfig {
  MyNoFieldCsrInstance({
    required super.addr,
    required super.width,
    super.resetValue = 0x0,
    String name = 'myNoFieldCsrInstance',
  }) : super(
            arch: MyNoFieldCsr(name: name),
            isBackdoorReadable: addr != 0x1,
            isBackdoorWritable: false);
}

class MyFieldCsr extends CsrConfig {
  MyFieldCsr({super.name = 'myFieldCsr'}) : super(access: CsrAccess.READ_WRITE);
}

class MyFieldCsrInstance extends CsrInstanceConfig {
  MyFieldCsrInstance({
    required super.addr,
    required super.width,
    super.resetValue = 0xff,
    String name = 'myFieldCsrInstance',
  }) : super(arch: MyFieldCsr(name: name), isBackdoorWritable: true) {
    // example of a static field
    fields
      ..add(CsrFieldConfig(
          start: 0, width: 2, name: 'field1', access: CsrFieldAccess.READ_ONLY))
      ..add(CsrFieldConfig(
          start: 2,
          width: 2,
          name: 'field2',
          access: CsrFieldAccess.READ_WRITE_LEGAL)
        ..addLegalValue(0x0)
        ..addLegalValue(0x1))
      // example of a field with dynamic start and width
      ..add(CsrFieldConfig(
          start: width ~/ 2,
          width: width ~/ 4,
          name: 'field3',
          access: CsrFieldAccess.READ_WRITE));
    // example of field duplication
    for (var i = 0; i < width ~/ 4; i++) {
      fields.add(CsrFieldConfig(
          start: (3 * width ~/ 4) + i,
          width: 1,
          name: 'field4_$i',
          access: CsrFieldAccess.WRITE_ONES_CLEAR));
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
    registers.add(MyFieldCsrInstance(addr: 0x0, width: csrWidth, name: 'csr1'));

    // dynamic register instances
    for (var i = 0; i < numNoFieldCsrs; i++) {
      final chk = i.isEven || !evensOnly;
      if (chk) {
        registers.add(MyNoFieldCsrInstance(
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
    super.blockOffsetWidth = 8,
  }) {
    // example of dynamic block instantiation
    const baseAddr = 0x0;
    for (var i = 0; i < numBlocks; i++) {
      blocks.add(MyRegisterBlock(
          baseAddr: baseAddr + (i * 0x100),
          numNoFieldCsrs: i + 1,
          evensOnly: i.isEven,
          name: 'block_$i'));
    }
  }
}

// to test potentially issues with CsrTop port propagation
class DummyCsrTopModule extends Module {
  // ignore: unused_field
  late final Logic _clk;
  // ignore: unused_field
  late final Logic _reset;

  // ignore: unused_field
  late final CsrTop _top;
  late final DataPortInterface _fdr;
  late final DataPortInterface _fdw;

  DummyCsrTopModule(
      {required Logic clk,
      required Logic reset,
      required CsrTopConfig config}) {
    _clk = addInput('clk', clk);
    _reset = addInput('reset', reset);
    _fdr = DataPortInterface(32, 32);
    _fdw = DataPortInterface(32, 32);
    _top = CsrTop(config, _clk, _reset, _fdw, _fdr);
  }
}

///// END DEFINE SOME HELPER CLASSES FOR TESTING /////

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('simple individual CSRs', () async {
    const dataWidth1 = 32;
    const dataWidth2 = 8;

    // register with no explicit fields, read only
    final csr1Cfg =
        MyNoFieldCsrInstance(addr: 0x0, width: dataWidth1, name: 'csr1');
    final csr1 = Csr(csr1Cfg);

    // check address and reset value
    expect(csr1.addr, 0x0);
    expect(csr1.resetValue, 0x0);
    csr1.put(csr1.resetValue);

    // check write data
    // should return the reset value, since it's read only
    final wd1 = csr1.getWriteData(Const(0x12345678, width: dataWidth1));
    expect(wd1.value, LogicValue.ofInt(0x0, dataWidth1));

    // register with 3 explicit fields, read/write
    // fields don't cover full width of register
    final csr2Cfg = MyFieldCsrInstance(addr: 0x1, width: 8, name: 'csr2');
    final csr2 = Csr(csr2Cfg);

    // check address and reset value
    expect(csr2.addr, 0x1);
    expect(csr2.resetValue, 0xff);
    csr2.put(csr2.resetValue);

    // check the write data
    // only some of what we're trying to write should
    // given the field access rules
    final wd2 = csr2.getWriteData(Const(0xab, width: dataWidth2));
    expect(wd2.value, LogicValue.ofInt(0xe3, dataWidth2));

    // check grabbing individual fields
    final f1 = csr2.getField('field1');
    expect(f1.value, LogicValue.ofInt(0x3, 2));
    final f2 = csr2.getField('field2');
    expect(f2.value, LogicValue.ofInt(0x3, 2)); // never wrote the value...
    final f3 = csr2.getField('field3');
    expect(f3.value, LogicValue.ofInt(0x3, 2));
    final f4a = csr2.getField('field4_0');
    expect(f4a.value, LogicValue.ofInt(0x1, 1));
    final f4b = csr2.getField('field4_1');
    expect(f4b.value, LogicValue.ofInt(0x1, 1));
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

    for (var i = 0; i < csrBlock.backdoorInterfaces.length; i++) {
      if (csrBlock.backdoorInterfaces[i].hasWrite) {
        csrBlock.backdoorInterfaces[i].wrEn!.put(0);
        csrBlock.backdoorInterfaces[i].wrData!.put(0);
      }
    }

    // WaveDumper(csrBlock);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // retrieve block address
    final blkAddr = csrBlock.baseAddr;
    expect(blkAddr, 0x0);

    // grab pointers to the CSRs
    final csr1 = csrBlock.getRegisterByName('csr1');
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
    rIntf.addr.inject(csr2.addr);
    await clk.nextNegedge;
    rIntf.en.inject(0);
    expect(
        rIntf.data.value, LogicValue.ofInt(csr2.resetValue, rIntf.dataWidth));
    await clk.waitCycles(10);

    // perform a write of csr2 and then a read
    // ensure that the write takes no effect b/c readonly
    await clk.nextNegedge;
    wIntf.en.inject(1);
    wIntf.addr.inject(csr2.addr);
    wIntf.data.inject(0xdeadbeef);
    await clk.nextNegedge;
    wIntf.en.inject(0);
    rIntf.en.inject(1);
    rIntf.addr.inject(csr2.addr);
    await clk.nextNegedge;
    rIntf.en.inject(0);
    expect(
        rIntf.data.value, LogicValue.ofInt(csr2.resetValue, rIntf.dataWidth));
    await clk.waitCycles(10);

    // perform a write of csr1
    // ensure that the write data is modified appropriately
    await clk.nextNegedge;
    wIntf.en.inject(1);
    wIntf.addr.inject(csr1.addr);
    wIntf.data.inject(0xdeadbeef);
    await clk.nextNegedge;
    wIntf.en.inject(0);
    rIntf.en.inject(1);
    rIntf.addr.inject(csr1.addr);
    await clk.nextNegedge;
    rIntf.en.inject(0);
    expect(rIntf.data.value, LogicValue.ofInt(0xad00f3, rIntf.dataWidth));
    await clk.waitCycles(10);

    // perform a read of nothing
    await clk.nextNegedge;
    rIntf.en.inject(1);
    rIntf.addr.inject(0xff);
    await clk.nextNegedge;
    rIntf.en.inject(0);
    expect(rIntf.data.value, LogicValue.ofInt(0, rIntf.dataWidth));
    await clk.waitCycles(10);

    // grab backdoor interfaces
    final back1 = csrBlock.getBackdoorPortsByName('csr1');
    final back2 = csrBlock.getBackdoorPortsByAddr(0x2);

    // perform backdoor read of csr2
    expect(back2.rdData!.value,
        LogicValue.ofInt(csr2.resetValue, rIntf.dataWidth));

    // perform a backdoor write and then a backdoor read of csr1
    await clk.nextNegedge;
    back1.wrEn!.inject(1);
    back1.wrData!.inject(0xdeadbeef);
    await clk.nextNegedge;
    back1.wrData!.inject(0);
    expect(back1.rdData!.value, LogicValue.ofInt(0xad00f3, rIntf.dataWidth));

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

    for (var i = 0; i < csrTop.backdoorInterfaces.length; i++) {
      for (var j = 0; j < csrTop.backdoorInterfaces[i].length; j++) {
        if (csrTop.backdoorInterfaces[i][j].hasWrite) {
          csrTop.backdoorInterfaces[i][j].wrEn!.put(0);
          csrTop.backdoorInterfaces[i][j].wrData!.put(0);
        }
      }
    }

    // WaveDumper(csrTop);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // grab pointers to certain blocks and CSRs
    final block1 = csrTop.getBlockByName('block_0');
    final block2 = csrTop.getBlockByAddr(0x100);
    final csr1 = block1.getRegisterByName('csr1');
    final csr2 = block2.getRegisterByAddr(0x2);

    // perform a reset
    reset.inject(1);
    await clk.waitCycles(10);
    reset.inject(0);
    await clk.waitCycles(10);

    // perform a read to a particular register in a particular block
    final addr1 = Const(block2.baseAddr + csr2.addr, width: rIntf.addrWidth);
    await clk.nextNegedge;
    rIntf.en.inject(1);
    rIntf.addr.inject(addr1.value);
    await clk.nextNegedge;
    rIntf.en.inject(0);
    expect(
        rIntf.data.value, LogicValue.ofInt(csr2.resetValue, rIntf.dataWidth));
    await clk.waitCycles(10);

    // perform a write to a particular register in a particular block
    final addr2 = Const(block1.baseAddr + csr1.addr, width: rIntf.addrWidth);
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
    expect(rIntf.data.value, LogicValue.ofInt(0xad00f3, rIntf.dataWidth));
    await clk.waitCycles(10);

    // perform a read to an invalid block
    await clk.nextNegedge;
    rIntf.en.inject(1);
    rIntf.addr.inject(0xffffffff);
    await clk.nextNegedge;
    rIntf.en.inject(0);
    expect(rIntf.data.value, LogicValue.ofInt(0, rIntf.dataWidth));
    await clk.waitCycles(10);

    // grab backdoor interfaces
    final back1 = csrTop.getBackdoorPortsByName('block_0', 'csr1');
    final back2 = csrTop.getBackdoorPortsByAddr(0x100, 0x2);

    // perform backdoor read of csr2
    expect(back2.rdData!.value,
        LogicValue.ofInt(csr2.resetValue, rIntf.dataWidth));

    // perform a backdoor write and then a backdoor read of csr1
    await clk.nextNegedge;
    back1.wrEn!.inject(1);
    back1.wrData!.inject(0xdeadbeef);
    await clk.nextNegedge;
    back1.wrData!.inject(0);
    expect(back1.rdData!.value, LogicValue.ofInt(0xad00f3, rIntf.dataWidth));

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('simple CSR top sub-instantiation', () async {
    final csrTopCfg = MyCsrModule(numBlocks: 4);
    final mod =
        DummyCsrTopModule(clk: Logic(), reset: Logic(), config: csrTopCfg);
    await mod.build();
  });

  test('CSR validation failures', () async {
    // illegal individual field - no legal values
    final badFieldCfg1 = CsrFieldConfig(
        start: 0,
        width: 1,
        name: 'badFieldCfg',
        access: CsrFieldAccess.READ_WRITE_LEGAL);
    expect(badFieldCfg1.validate,
        throwsA(predicate((f) => f is CsrValidationException)));

    // illegal individual field - reset value doesn't fit
    final badFieldCfg2 = CsrFieldConfig(
        start: 0,
        width: 1,
        name: 'badFieldCfg',
        access: CsrFieldAccess.READ_WRITE,
        resetValue: 0xfff);
    expect(badFieldCfg2.validate,
        throwsA(predicate((f) => f is CsrValidationException)));

    // illegal individual field - legal value doesn't fit
    final badFieldCfg3 = CsrFieldConfig(
        start: 0,
        width: 1,
        name: 'badFieldCfg',
        access: CsrFieldAccess.READ_WRITE_LEGAL)
      ..addLegalValue(0x0)
      ..addLegalValue(0xfff);
    expect(badFieldCfg3.validate,
        throwsA(predicate((f) => f is CsrValidationException)));

    // illegal architectural register
    final badArchRegCfg =
        CsrConfig(access: CsrAccess.READ_WRITE, name: 'badArchRegCfg')
          ..fields.add(CsrFieldConfig(
              start: 0,
              width: 8,
              name: 'field',
              access: CsrFieldAccess.READ_WRITE))
          ..fields.add(CsrFieldConfig(
              start: 3,
              width: 4,
              name: 'field',
              access: CsrFieldAccess.READ_WRITE))
          ..fields.add(CsrFieldConfig(
              start: 3,
              width: 10,
              name: 'field1',
              access: CsrFieldAccess.READ_WRITE))
          ..fields.add(CsrFieldConfig(
              start: 9,
              width: 11,
              name: 'field2',
              access: CsrFieldAccess.READ_WRITE));
    expect(badArchRegCfg.validate,
        throwsA(predicate((f) => f is CsrValidationException)));

    // illegal register instance - field surpasses reg width
    final badRegInstCfg1 = CsrInstanceConfig(
        arch: CsrConfig(access: CsrAccess.READ_WRITE, name: 'reg')
          ..fields.add(CsrFieldConfig(
              start: 0,
              width: 32,
              name: 'field',
              access: CsrFieldAccess.READ_WRITE)),
        addr: 0x0,
        width: 4);
    expect(badRegInstCfg1.validate,
        throwsA(predicate((f) => f is CsrValidationException)));

    // illegal register instance - reset value surpasses reg width
    final badRegInstCfg2 = CsrInstanceConfig(
        arch: CsrConfig(access: CsrAccess.READ_WRITE, name: 'reg')
          ..fields.add(CsrFieldConfig(
              start: 0,
              width: 4,
              name: 'field',
              access: CsrFieldAccess.READ_WRITE)),
        addr: 0x0,
        width: 4,
        resetValue: 0xfff);
    expect(badRegInstCfg2.validate,
        throwsA(predicate((f) => f is CsrValidationException)));
  });

  test('CSR block and top validation failures', () async {
    // illegal block - empty
    final badBlockCfg1 = CsrBlockConfig(name: 'block', baseAddr: 0x0);
    expect(badBlockCfg1.validate,
        throwsA(predicate((f) => f is CsrValidationException)));

    // illegal block - duplication
    final badBlockCfg2 = CsrBlockConfig(name: 'block', baseAddr: 0x0)
      ..registers.add(CsrInstanceConfig(
          arch: CsrConfig(access: CsrAccess.READ_WRITE, name: 'reg'),
          addr: 0x0,
          width: 4))
      ..registers.add(CsrInstanceConfig(
          arch: CsrConfig(access: CsrAccess.READ_WRITE, name: 'reg'),
          addr: 0x1,
          width: 4))
      ..registers.add(CsrInstanceConfig(
          arch: CsrConfig(access: CsrAccess.READ_WRITE, name: 'reg1'),
          addr: 0x1,
          width: 4));
    expect(badBlockCfg2.validate,
        throwsA(predicate((f) => f is CsrValidationException)));

    // illegal top - empty
    final badTopCfg1 = CsrTopConfig(name: 'top', blockOffsetWidth: 8);
    expect(badTopCfg1.validate,
        throwsA(predicate((f) => f is CsrValidationException)));

    // illegal top - duplication and closeness
    final badTopCfg2 = CsrTopConfig(name: 'top', blockOffsetWidth: 8)
      ..blocks.add(CsrBlockConfig(name: 'block', baseAddr: 0x0))
      ..blocks.add(CsrBlockConfig(name: 'block', baseAddr: 0x1))
      ..blocks.add(CsrBlockConfig(name: 'block1', baseAddr: 0x1));
    expect(badTopCfg2.validate,
        throwsA(predicate((f) => f is CsrValidationException)));

    // illegal top - bad block offset width
    final badTopCfg3 = CsrTopConfig(name: 'top', blockOffsetWidth: 1)
      ..blocks.add(CsrBlockConfig(name: 'block', baseAddr: 0x0)
        ..registers.add(CsrInstanceConfig(
            arch: CsrConfig(access: CsrAccess.READ_WRITE, name: 'reg'),
            addr: 0x4,
            width: 4)));
    expect(badTopCfg3.validate,
        throwsA(predicate((f) => f is CsrValidationException)));
  });
}
