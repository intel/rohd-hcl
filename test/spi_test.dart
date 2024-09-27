// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_test.dart
// Tests for SPI interface
//
// 2024 September 23
// Author: Roberto Torres <roberto.torres@intel.com>

import 'package:rohd/rohd.dart';
//import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class SpiMain extends Module {
  SpiMain(SpiInterface intf) {
    intf = SpiInterface.clone(intf)
      ..pairConnectIO(this, intf, PairRole.provider);
  }
}

class SpiSub extends Module {
  SpiSub(SpiInterface intf) {
    intf = SpiInterface.clone(intf)
      ..pairConnectIO(this, intf, PairRole.consumer);
  }
}

class SpiTop extends Module {
  SpiTop() {
    final intf = SpiInterface();
    SpiMain(intf);
    SpiSub(intf);
    addOutput('dummy') <= intf.sclk;
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('spi_test', () async {
    final mod = SpiTop();
    await mod.build();
    print(mod.generateSynth());
  });
}
