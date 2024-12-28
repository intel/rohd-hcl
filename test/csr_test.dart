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
    for (var i = 0; i < (width ~/ 4) - 1; i++) {
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
    csr1.inject(csr1.resetValue);

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

    // check the write data
    // only some of what we're trying to write should
    // given the field access rules
    final wd2 = csr2.getWriteData(Const(0xab, width: 8));
    expect(wd2.value, LogicValue.ofInt(0xef, 8));

    // check grabbing individual fields
    final f1 = csr2.getField('field1');
    expect(f1.value, LogicValue.ofInt(0x3, 2));
    final f2 = csr2.getField('field2');
    expect(f2.value, LogicValue.ofInt(0x1, 1));
    final f3 = csr2.getField('field3');
    expect(f3.value, LogicValue.ofInt(0x5, 3));
  });

  test('simple CSR block', () async {
    const csrWidth = 32;

    final csrBlockCfg = MyRegisterBlock(
      baseAddr: 0x0,
      csrWidth: csrWidth,
      numNoFieldCsrs: 2,
    );

    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..inject(0);
    final wIntf = DataPortInterface(csrWidth, 8);
    final rIntf = DataPortInterface(csrWidth, 8);
    final csrBlock = CsrBlock(csrBlockCfg, clk, reset, wIntf, rIntf);

    wIntf.en.inject(0);
    wIntf.addr.inject(0);
    wIntf.data.inject(0);
    rIntf.en.inject(0);
    rIntf.addr.inject(0);

    // retrieve block address
    final blkAddr = csrBlock.getAddr(16);
    expect(blkAddr.value, LogicValue.ofInt(0x100, 16));

    // grab pointers to the CSRs
    final csr1 = csrBlock.getRegister('csr1');
    final csr2 = csrBlock.getRegisterByAddr(0x1);

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

    // perform a write of csr1 and then a read
    // ensure that the write takes no effect b/c readonly
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
    expect(csrBlock.rdData().value, csr1.getResetValue().value);
    await clk.waitCycles(10);

    // perform a write of csr2
    // ensure that the write data is modified appropriately
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
    expect(csrBlock.rdData().value, LogicValue.ofInt(0xef, rIntf.dataWidth));
    await clk.waitCycles(10);

    // perform a read of nothing
    await clk.nextNegedge;
    rIntf.en.inject(1);
    rIntf.addr.inject(0xff);
    await clk.nextNegedge;
    rIntf.en.inject(0);
    expect(csrBlock.rdData().value, LogicValue.ofInt(0, rIntf.dataWidth));
    await clk.waitCycles(10);

    // TODO: end simulation
  });

  // test('simple shift register', () async {
  //   final dataIn = Logic(width: 8);
  //   final clk = SimpleClockGenerator(10).clk;
  //   const latency = 5;
  //   final sr = ShiftRegister(dataIn, clk: clk, depth: latency);
  //   final dataOut = sr.dataOut;
  //   final data3 = sr.stages[2];

  //   final data = [for (var i = 0; i < 20; i++) i * 3];

  //   unawaited(Simulator.run());

  //   for (final dataI in data) {
  //     dataIn.put(dataI);
  //     unawaited(clk
  //         .waitCycles(latency)
  //         .then((value) => expect(dataOut.value.toInt(), dataI)));

  //     unawaited(clk
  //         .waitCycles(3)
  //         .then((value) => expect(data3.value.toInt(), dataI)));

  //     await clk.nextPosedge;
  //   }

  //   await clk.waitCycles(latency);

  //   expect(dataOut.value.toInt(), data.last);

  //   await Simulator.endSimulation();
  // });

  // test('shift register naming', () {
  //   final sr =
  //       ShiftRegister(Logic(), clk: Logic(), depth: 3, dataName: 'fancy');
  //   expect(sr.name, contains('fancy'));
  //   expect(sr.dataOut.name, contains('fancy'));
  //   expect(
  //       // ignore: invalid_use_of_protected_member
  //       sr.inputs.keys.where((element) => element.contains('fancy')).length,
  //       1);
  // });

  // test('depth 0 shift register is pass-through', () {
  //   final dataIn = Logic(width: 8);
  //   final clk = Logic();
  //   const latency = 0;
  //   final dataOut = ShiftRegister(dataIn, clk: clk, depth: latency).dataOut;

  //   dataIn.put(0x23);
  //   expect(dataOut.value.toInt(), 0x23);
  // });

  // test('width 0 constructs properly', () {
  //   expect(ShiftRegister(Logic(width: 0), clk: Logic(), depth: 9).dataOut.width,
  //       0);
  // });

  // test('enabled shift register', () async {
  //   final dataIn = Logic(width: 8);
  //   final clk = SimpleClockGenerator(10).clk;
  //   const latency = 5;
  //   final enable = Logic();
  //   final dataOut =
  //       ShiftRegister(dataIn, clk: clk, depth: latency, enable: enable).dataOut;

  //   unawaited(Simulator.run());

  //   enable.put(true);
  //   dataIn.put(0x45);

  //   await clk.nextPosedge;
  //   dataIn.put(0);

  //   await clk.waitCycles(2);

  //   enable.put(false);

  //   await clk.waitCycles(20);

  //   enable.put(true);

  //   expect(dataOut.value.isValid, isFalse);

  //   await clk.waitCycles(2);

  //   expect(dataOut.value.toInt(), 0x45);

  //   await clk.nextPosedge;

  //   expect(dataOut.value.toInt(), 0);

  //   await Simulator.endSimulation();
  // });

  // group('reset shift register', () {
  //   Future<void> resetTest(
  //       dynamic resetVal, void Function(Logic dataOut) check) async {
  //     final dataIn = Logic(width: 8);
  //     final clk = SimpleClockGenerator(10).clk;
  //     const latency = 5;
  //     final reset = Logic();
  //     final dataOut = ShiftRegister(dataIn,
  //             clk: clk, depth: latency, reset: reset, resetValue: resetVal)
  //         .dataOut;

  //     unawaited(Simulator.run());

  //     dataIn.put(0x45);
  //     reset.put(true);

  //     await clk.nextPosedge;

  //     check(dataOut);

  //     reset.put(false);

  //     await clk.waitCycles(2);

  //     check(dataOut);

  //     await clk.waitCycles(3);

  //     expect(dataOut.value.toInt(), 0x45);

  //     await Simulator.endSimulation();
  //   }

  //   test('null reset value', () async {
  //     await resetTest(null, (dataOut) {
  //       expect(dataOut.value.toInt(), 0);
  //     });
  //   });

  //   test('constant reset value', () async {
  //     await resetTest(0x56, (dataOut) {
  //       expect(dataOut.value.toInt(), 0x56);
  //     });
  //   });

  //   test('logic reset value', () async {
  //     await resetTest(Const(0x78, width: 8), (dataOut) {
  //       expect(dataOut.value.toInt(), 0x78);
  //     });
  //   });
  // });

  // test('enabled and reset shift register', () async {
  //   final dataIn = Logic(width: 8);
  //   final clk = SimpleClockGenerator(10).clk;
  //   const latency = 5;
  //   final enable = Logic();
  //   final reset = Logic();
  //   final dataOut = ShiftRegister(dataIn,
  //           clk: clk, depth: latency, enable: enable, reset: reset)
  //       .dataOut;

  //   unawaited(Simulator.run());

  //   enable.put(true);
  //   dataIn.put(0x45);
  //   reset.put(true);

  //   await clk.nextPosedge;
  //   reset.put(false);

  //   await clk.nextPosedge;

  //   dataIn.put(0);

  //   await clk.waitCycles(2);

  //   enable.put(false);

  //   await clk.waitCycles(20);

  //   enable.put(true);

  //   expect(dataOut.value.toInt(), 0);

  //   await clk.waitCycles(2);

  //   expect(dataOut.value.toInt(), 0x45);

  //   await clk.nextPosedge;

  //   expect(dataOut.value.toInt(), 0);

  //   await Simulator.endSimulation();
  // });

  // group('list reset value shift register', () {
  //   Future<void> listResetTest(
  //       dynamic resetVal, void Function(Logic dataOut) check) async {
  //     final dataIn = Logic(width: 8);
  //     final clk = SimpleClockGenerator(10).clk;
  //     const depth = 5;
  //     final reset = Logic();
  //     final dataOut = ShiftRegister(dataIn,
  //             clk: clk, depth: depth, reset: reset, resetValue: resetVal)
  //         .dataOut;

  //     unawaited(Simulator.run());

  //     dataIn.put(0x45);
  //     reset.put(true);

  //     await clk.nextPosedge;

  //     reset.put(false);

  //     await clk.waitCycles(3);

  //     check(dataOut);

  //     await Simulator.endSimulation();
  //   }

  //   test('list of logics reset value', () async {
  //     await listResetTest([
  //       Logic(width: 8)..put(0x2),
  //       Logic(width: 8)..put(0x10),
  //       Logic(width: 8)..put(0x22),
  //       Logic(width: 8)..put(0x33),
  //       Logic(width: 8)..put(0x42),
  //     ], (dataOut) {
  //       expect(dataOut.value.toInt(), 0x10);
  //     });
  //   });

  //   test('list of mixed reset value', () async {
  //     await listResetTest([
  //       Logic(width: 8)..put(0x2),
  //       26,
  //       Logic(width: 8)..put(0x22),
  //       true,
  //       Logic(width: 8)..put(0x42),
  //     ], (dataOut) {
  //       expect(dataOut.value.toInt(), 0x1A);
  //     });
  //   });
  // });

  // group('async reset shift register', () {
  //   Future<void> asyncResetTest(
  //       dynamic resetVal, void Function(Logic dataOut) check) async {
  //     final dataIn = Logic(width: 8);
  //     final clk = SimpleClockGenerator(10).clk;
  //     const depth = 5;
  //     final reset = Logic();
  //     final dataOut = ShiftRegister(dataIn,
  //             clk: Const(0),
  //             depth: depth,
  //             reset: reset,
  //             resetValue: resetVal,
  //             asyncReset: true)
  //         .dataOut;

  //     unawaited(Simulator.run());

  //     dataIn.put(0x42);

  //     reset.inject(false);

  //     await clk.waitCycles(1);

  //     reset.inject(true);

  //     await clk.waitCycles(1);

  //     check(dataOut);

  //     await Simulator.endSimulation();
  //   }

  //   test('async reset value', () async {
  //     await asyncResetTest(Const(0x78, width: 8), (dataOut) {
  //       expect(dataOut.value.toInt(), 0x78);
  //     });
  //   });

  //   test('async null reset value', () async {
  //     await asyncResetTest(null, (dataOut) {
  //       expect(dataOut.value.toInt(), 0);
  //     });
  //   });

  //   test('async reset with list mixed type', () async {
  //     await asyncResetTest([
  //       Logic(width: 8)..put(0x2),
  //       59,
  //       Const(0x78, width: 8),
  //       Logic(width: 8)..put(0x33),
  //       true,
  //     ], (dataOut) {
  //       expect(dataOut.value.toInt(), 0x1);
  //     });
  //   });
  // });
}
