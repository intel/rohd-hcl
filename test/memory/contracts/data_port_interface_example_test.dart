// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// data_port_interface_example_test.dart
// Exercises the DataPortInterface documentation examples.
//
// 2026 November
// Author: ROHD-HCL contributors

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(Simulator.reset);

  test('structural memory ports connect to hardware signals', () async {
    final clk = Logic()..put(0);
    final reset = Logic()..put(0);
    final writeEnable = Logic()..put(0);
    final writeAddress = Logic(width: 5)..put(0);
    final writeData = Logic(width: 32)..put(0);
    final readEnable = Logic()..put(1);
    final readAddress = Logic(width: 5)..put(3);

    final write = DataPortInterface<Logic>(32, 5);
    final read = DataPortInterface<Logic>(32, 5);
    final memory =
        RegisterFile<Logic>(clk, reset, [write], [read], numEntries: 20);
    write.en <= writeEnable;
    write.addr <= writeAddress;
    write.data <= writeData;
    read.en <= readEnable;
    read.addr <= readAddress;
    final readData = read.data;
    await memory.build();

    writeEnable.put(1);
    writeAddress.put(3);
    writeData.put(0xdeadbeef);
    await Simulator.tick();
    clk.inject(1);
    await Simulator.tick();
    clk.inject(0);
    await Simulator.tick();
    expect(readData.value, LogicValue.ofInt(0xdeadbeef, 32));
  });

  test('testbench drives memory ports with values', () async {
    final clk = Logic()..put(0);
    final reset = Logic()..put(0);
    final write = DataPortInterface<Logic>(32, 5);
    final read = DataPortInterface<Logic>(32, 5);
    final memory =
        RegisterFile<Logic>(clk, reset, [write], [read], numEntries: 20);
    await memory.build();

    write.en.put(1);
    write.addr.put(3);
    write.data.put(0xdeadbeef);
    read.en.put(1);
    read.addr.put(3);
    await Simulator.tick();
    clk.inject(1);
    await Simulator.tick();
    clk.inject(0);
    await Simulator.tick();
    expect(read.data.value, LogicValue.ofInt(0xdeadbeef, 32));
  });
}
